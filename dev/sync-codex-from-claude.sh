#!/bin/bash
set -euo pipefail

mode="apply"
project_root=""
claude_state_file="${CLAUDE_STATE_FILE:-$HOME/.claude/.claude.json}"

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--project-root=/path]

Sync Codex MCP servers from Claude MCP server config.

Options:
  --dry-run              Show actions without changing Codex config
  --project-root=PATH    Claude project to source per-project MCP config from
                         (default: current git repo root, else empty)
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

if [ ! -f "$claude_state_file" ]; then
  echo "Error: Claude state file not found: $claude_state_file" >&2
  exit 1
fi

MODE="$mode" PROJECT_ROOT="$project_root" CLAUDE_STATE_FILE="$claude_state_file" node <<'NODE'
const { execFileSync } = require("node:child_process");
const { readFileSync } = require("node:fs");

const mode = process.env.MODE || "apply";
const projectRoot = process.env.PROJECT_ROOT || "";
const claudeStateFile = process.env.CLAUDE_STATE_FILE;

function run(args) {
  const out = execFileSync("codex", args, { encoding: "utf8" });
  return out.replace(/^WARNING:.*\n/gm, "").trim();
}

function tryJson(args, fallback) {
  try {
    const out = run(args);
    return out ? JSON.parse(out) : fallback;
  } catch {
    return fallback;
  }
}

const claude = JSON.parse(readFileSync(claudeStateFile, "utf8"));
const desiredMap = new Map();

if (claude.mcpServers && typeof claude.mcpServers === "object") {
  for (const [name, def] of Object.entries(claude.mcpServers)) desiredMap.set(name, def);
}
if (projectRoot && claude.projects?.[projectRoot]?.mcpServers) {
  for (const [name, def] of Object.entries(claude.projects[projectRoot].mcpServers)) desiredMap.set(name, def);
}

const desired = [...desiredMap.entries()]
  .filter(([, def]) => def && (def.type === "stdio" || def.type === "http"))
  .map(([name, def]) => ({
    name,
    type: def.type,
    command: def.command || "",
    args: Array.isArray(def.args) ? def.args : [],
    url: def.url || "",
    env: def.env && typeof def.env === "object" ? def.env : {},
  }));

const currentList = tryJson(["mcp", "list", "--json"], []);
const currentNames = new Set(currentList.map((s) => s.name).filter(Boolean));

function normalizeCodexServer(raw) {
  if (!raw || typeof raw !== "object") return null;
  const transport = raw.transport || raw.config || raw.server || raw;
  const rawType = transport.type || raw.type || "";
  const type = rawType === "streamable_http" ? "http" : rawType;
  if (!type) return null;
  return {
    name: raw.name,
    type,
    command: transport.command || "",
    args: Array.isArray(transport.args) ? transport.args : [],
    url: transport.url || "",
    env: transport.env && typeof transport.env === "object" ? transport.env : {},
  };
}

function same(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

const summary = { add: [], update: [], unchanged: [] };

for (const target of desired) {
  if (!currentNames.has(target.name)) {
    summary.add.push(target);
    continue;
  }
  const existingRaw = tryJson(["mcp", "get", target.name, "--json"], null);
  const existing = normalizeCodexServer(existingRaw) || { name: target.name };
  const normTarget = { ...target };
  if (!same(existing, normTarget)) {
    summary.update.push(target);
  } else {
    summary.unchanged.push(target.name);
  }
}

const banner = projectRoot
  ? `Syncing Codex MCP from Claude for project: ${projectRoot}`
  : "Syncing Codex MCP from Claude (global only)";
console.log(banner);
console.log(`Desired: ${desired.length}, add: ${summary.add.length}, update: ${summary.update.length}, unchanged: ${summary.unchanged.length}`);

for (const server of [...summary.add, ...summary.update]) {
  const cmd = [];
  if (server.type === "http") {
    cmd.push("codex", "mcp", "add", server.name, "--url", server.url);
  } else {
    cmd.push("codex", "mcp", "add", server.name, "--", server.command, ...server.args);
  }
  if (server.type === "stdio") {
    for (const [k, v] of Object.entries(server.env)) cmd.splice(4, 0, "--env", `${k}=${v}`);
  }
  console.log(`${summary.add.includes(server) ? "ADD" : "UPDATE"} ${server.name}: ${cmd.join(" ")}`);
  if (mode === "apply") {
    if (summary.update.includes(server)) {
      run(["mcp", "remove", server.name]);
    }
    run(cmd.slice(1));
  }
}

if (mode === "dry-run") {
  console.log("Dry-run only: no changes applied.");
} else {
  console.log("Applied Codex MCP sync.");
}
NODE
