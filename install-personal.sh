#!/usr/bin/env bash
# Personal profile: core environment with no work tooling.
set -euo pipefail

DOTFILES="$HOME/.config"
# shellcheck source=install-common.sh
source "$DOTFILES/install-common.sh"

echo "── Installing PERSONAL profile ───────────────────"

# Homebrew's docker-buildx lands outside Docker's plugin search path. A
# symlink in ~/.docker/cli-plugins, a directory Docker always searches,
# avoids tracking ~/.docker/config.json, which `docker login` writes
# credentials into.
link_docker_buildx() {
  mkdir -p ~/.docker/cli-plugins
  ln -sfn /opt/homebrew/opt/docker-buildx/bin/docker-buildx ~/.docker/cli-plugins/docker-buildx
}

# myos scripts/check.sh needs vmalert-tool, which no Homebrew formula ships
# (victoriametrics has only the server). The version matches the pin in
# myos scripts/ci/lib.sh; change both together. lib.sh puts
# ~/.cache/myos-ci-tools/bin on PATH, so only myos's checks see it.
install_myos_vmalert_tool() {
  local version=v1.148.0
  local sum=bf8d960339c305bcc617ab0cc19dbc07cc0be45cf11ddd7d477561ad12132591
  local bin="$HOME/.cache/myos-ci-tools/bin/vmalert-tool"
  [[ -x "$bin" ]] && "$bin" --version 2>&1 | grep -q "$version" && return 0
  local tmp
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/vmutils.tgz" \
    "https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/$version/vmutils-darwin-arm64-$version.tar.gz"
  echo "$sum  $tmp/vmutils.tgz" | shasum -a 256 --check --quiet
  tar -xzf "$tmp/vmutils.tgz" -C "$tmp" vmalert-tool-prod
  mkdir -p "$(dirname "$bin")"
  install -m 0755 "$tmp/vmalert-tool-prod" "$bin"
  rm -rf "$tmp"
}

# myos scripts/check.sh and its pre-push hook pick CI jobs with
# scripts/ci/select-jobs.py, which imports yaml under whichever python3 is
# first on PATH. Homebrew's Python (pulled in by awscli) usually wins, and it
# refuses pip installs (PEP 668) unless told otherwise. --user keeps the
# package in the user site, out of Homebrew's own site-packages; Apple's
# older pip does not know --break-system-packages, hence the fallback.
install_myos_pyyaml() {
  python3 -c 'import yaml' 2>/dev/null && return 0
  python3 -m pip install --user --quiet --break-system-packages pyyaml 2>/dev/null ||
    python3 -m pip install --user --quiet pyyaml
}

# These skills are uploaded to the personal claude.ai account, which loads them
# into every Claude session on this Mac and in the cloud. A ~/.claude/skills
# link with the same name loads a second copy beside the account one. Codex and
# Cursor cannot read account skills, so ~/.agents/skills keeps every link.
# Change this list when a skill is added to or removed from the account.
ACCOUNT_SKILLS=(
  code-review codebase-design diagnosing-bugs domain-modeling grilling handoff
  implement implement-spec improve-codebase-architecture pr prototype research
  retro setup-matt-pocock-skills tdd to-spec to-tickets triage wayfinder wizard
  write-commit writing-for-agents
)

unlink_account_skills() {
  local name link
  for name in "${ACCOUNT_SKILLS[@]}"; do
    link="$HOME/.claude/skills/$name"
    if [[ -L "$link" && "$(readlink "$link")" == "$DOTFILES/"* ]]; then
      rm "$link"
    fi
  done
}

run_core
unlink_account_skills
brew_bundle "$DOTFILES/Brewfile.personal"
link_docker_buildx
install_myos_vmalert_tool
install_myos_pyyaml
setup_macos_defaults

verify

cat <<'EOF'

Personal setup complete. Manual follow-up:

  1. Set up Karabiner-Elements, Brave, and Chai
  2. Restore ~/.ssh keys (github)
  3. Create ~/.config/zsh/.zsh_secrets
  4. Sign in to GitHub: gh auth login
  5. Reload shell: exec zsh -l
EOF
