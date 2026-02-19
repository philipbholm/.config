#!/bin/bash
set -euo pipefail

mode="apply"
project_root=""
claude_settings_file="${CLAUDE_SETTINGS_FILE:-$HOME/.config/claude/settings.json}"
claude_state_file="${CLAUDE_STATE_FILE:-$HOME/.claude/.claude.json}"
opencode_config_file="${OPENCODE_CONFIG_FILE:-$HOME/.config/opencode/opencode.json}"

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--project-root=/path]

Translate Claude settings to OpenCode config.

Options:
  --dry-run                Print generated OpenCode JSON to stdout
  --project-root=PATH      Include Claude per-project MCP config from this repo root
                           (default: current git repo root, else empty)
  --help                   Show this help text
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) mode="dry-run" ;;
    --project-root=*) project_root="${arg#*=}" ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; usage; exit 1 ;;
  esac
done

if [ -z "$project_root" ]; then
  if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    project_root="$git_root"
  fi
fi

if [ ! -f "$claude_settings_file" ]; then
  echo "Error: Claude settings not found: $claude_settings_file" >&2
  exit 1
fi

MODE="$mode" PROJECT_ROOT="$project_root" CLAUDE_SETTINGS_FILE="$claude_settings_file" CLAUDE_STATE_FILE="$claude_state_file" OPENCODE_CONFIG_FILE="$opencode_config_file" node <<'NODE'
const { mkdirSync, readFileSync, writeFileSync, existsSync } = require("node:fs");
const { dirname } = require("node:path");

const mode = process.env.MODE || "apply";
const projectRoot = process.env.PROJECT_ROOT || "";
const settingsFile = process.env.CLAUDE_SETTINGS_FILE;
const stateFile = process.env.CLAUDE_STATE_FILE;
const opencodeConfigFile = process.env.OPENCODE_CONFIG_FILE;

function readJson(path, fallback = {}) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return fallback;
  }
}

function mapModel(claudeModel) {
  const map = {
    opus: "anthropic/claude-opus-4-1",
    sonnet: "anthropic/claude-sonnet-4-5",
    haiku: "anthropic/claude-haiku-4-5",
  };
  if (!claudeModel || typeof claudeModel !== "string") return undefined;
  return map[claudeModel] || claudeModel;
}

function normalizeReadPattern(pattern) {
  if (!pattern) return "";
  return pattern.replace(/^\.\//, "");
}

function normalizeBashPattern(pattern) {
  if (!pattern) return "";
  if (pattern.endsWith(":*")) return `${pattern.slice(0, -2)}*`;
  return pattern;
}

function buildPermissions(denyList) {
  const read = { "*": "allow" };
  const bash = { "*": "allow" };

  for (const rule of denyList) {
    if (typeof rule !== "string") continue;

    const readMatch = rule.match(/^Read\((.*)\)$/);
    if (readMatch) {
      const pattern = normalizeReadPattern(readMatch[1]);
      if (pattern) read[pattern] = "deny";
      continue;
    }

    const bashMatch = rule.match(/^Bash\((.*)\)$/);
    if (bashMatch) {
      const pattern = normalizeBashPattern(bashMatch[1]);
      if (pattern) bash[pattern] = "deny";
      continue;
    }
  }

  const permission = {};
  if (Object.keys(read).length > 1) permission.read = read;
  if (Object.keys(bash).length > 1) permission.bash = bash;
  return permission;
}

function toArray(value) {
  return Array.isArray(value) ? value : [];
}

function buildMcp(claudeState, projectRootValue) {
  const merged = new Map();

  if (claudeState.mcpServers && typeof claudeState.mcpServers === "object") {
    for (const [name, def] of Object.entries(claudeState.mcpServers)) merged.set(name, def);
  }

  const projectMcp = claudeState.projects?.[projectRootValue]?.mcpServers;
  if (projectRootValue && projectMcp && typeof projectMcp === "object") {
    for (const [name, def] of Object.entries(projectMcp)) merged.set(name, def);
  }

  const mcp = {};
  for (const [name, def] of merged.entries()) {
    if (!def || typeof def !== "object") continue;

    if (def.type === "stdio" && typeof def.command === "string" && def.command) {
      const command = [def.command, ...toArray(def.args).filter((item) => typeof item === "string")];
      mcp[name] = {
        type: "local",
        command,
        enabled: def.enabled !== false,
      };
      if (def.env && typeof def.env === "object" && Object.keys(def.env).length > 0) {
        mcp[name].environment = def.env;
      }
      continue;
    }

    if (def.type === "http" && typeof def.url === "string" && def.url) {
      mcp[name] = {
        type: "remote",
        url: def.url,
        enabled: def.enabled !== false,
      };
      if (def.headers && typeof def.headers === "object" && Object.keys(def.headers).length > 0) {
        mcp[name].headers = def.headers;
      }
    }
  }

  return mcp;
}

const claudeSettings = readJson(settingsFile, {});
const claudeState = existsSync(stateFile) ? readJson(stateFile, {}) : {};
const currentOpencode = existsSync(opencodeConfigFile) ? readJson(opencodeConfigFile, {}) : {};

const model = mapModel(claudeSettings.model);
const denyList = toArray(claudeSettings.permissions?.deny);
const permission = buildPermissions(denyList);
const mcp = buildMcp(claudeState, projectRoot);

const next = {
  ...currentOpencode,
  $schema: "https://opencode.ai/config.json",
  model: model || currentOpencode.model,
};

if (Object.keys(permission).length > 0) {
  next.permission = {
    ...(currentOpencode.permission && typeof currentOpencode.permission === "object" ? currentOpencode.permission : {}),
    ...permission,
  };
}

if (Object.keys(mcp).length > 0) {
  next.mcp = mcp;
}

const json = `${JSON.stringify(next, null, 2)}\n`;

if (mode === "dry-run") {
  process.stdout.write(json);
} else {
  mkdirSync(dirname(opencodeConfigFile), { recursive: true });
  writeFileSync(opencodeConfigFile, json, "utf8");
  const scope = projectRoot ? ` + project MCP (${projectRoot})` : "";
  console.log(`Wrote OpenCode config: ${opencodeConfigFile}${scope}`);
}
NODE
