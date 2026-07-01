#!/usr/bin/env bash
# setup-browsermcp-wsl-chrome.sh
#
# BrowserMCP for: Cursor CLI in WSL + Chrome on Windows host
#
# Why Windows MCP server?
#   Chrome extension connects to ws://localhost:9009 on WINDOWS.
#   Cursor CLI (WSL) spawns the MCP server via cmd.exe so the socket
#   listens on Windows localhost, not WSL localhost.
#
# Usage:
#   ./scripts/setup-browsermcp-wsl-chrome.sh          # full setup
#   ./scripts/setup-browsermcp-wsl-chrome.sh --check  # verify only
#   ./scripts/setup-browsermcp-wsl-chrome.sh --help
#
# After setup (every machine / every new Windows session):
#   1. Open Chrome on Windows
#   2. Install extension (once): https://chromewebstore.google.com/detail/browser-mcp/fpeabamapgecnidibfkhjjkmbjbffjof
#   3. Click extension icon -> Connect
#   4. Run Cursor CLI agent in WSL (MCP auto-starts when session begins)
#
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly MCP_CONFIG="${HOME}/.cursor/mcp.json"
readonly EXTENSION_URL="https://chromewebstore.google.com/detail/browser-mcp/fpeabamapgecnidibfkhjjkmbjbffjof"
readonly WS_PORT=9009

log()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
$SCRIPT_NAME — setup BrowserMCP for Cursor CLI (WSL) + Chrome (Windows)

Commands:
  (no args)    Install Windows package + write ~/.cursor/mcp.json
  --check      Verify prerequisites and config
  --help       Show this help

Config written:
  $MCP_CONFIG

Daily workflow:
  1. Chrome (Windows) -> Browser MCP extension -> Connect
  2. cursor agent (WSL) -> browsermcp tools available

EOF
}

detect_windows_user() {
  cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n'
}

detect_npm_prefix_windows() {
  powershell.exe -NoProfile -Command "(npm config get prefix).Trim()" 2>/dev/null | tr -d '\r\n'
}

detect_mcp_cmd_windows() {
  local prefix user cmd_path
  prefix="$(detect_npm_prefix_windows)"
  user="$(detect_windows_user)"

  if [[ -n "$prefix" && -f "${prefix//\\//}/mcp-server-browsermcp.cmd" ]]; then
    echo "${prefix}\\mcp-server-browsermcp.cmd"
    return 0
  fi

  if [[ -n "$user" && -f "/mnt/c/Users/${user}/AppData/Roaming/npm/mcp-server-browsermcp.cmd" ]]; then
    echo "C:\\Users\\${user}\\AppData\\Roaming\\npm\\mcp-server-browsermcp.cmd"
    return 0
  fi

  if cmd.exe /c "where mcp-server-browsermcp" >/dev/null 2>&1; then
    cmd.exe /c "where mcp-server-browsermcp" 2>/dev/null | head -1 | tr -d '\r\n'
    return 0
  fi

  return 1
}

to_windows_path() {
  local wsl_path="$1"
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$wsl_path"
  else
    echo "$wsl_path" | sed 's|^/mnt/\([a-z]\)/|\U\1:/|' | sed 's|/|\\|g'
  fi
}

install_windows_package() {
  log "Installing @browsermcp/mcp on Windows (npm global)..."
  if ! powershell.exe -NoProfile -Command "node -v" >/dev/null 2>&1; then
    fail "Node.js not found on Windows. Install from https://nodejs.org/ first."
  fi
  powershell.exe -NoProfile -Command "npm install -g @browsermcp/mcp@latest"
  ok "Windows package installed"
}

write_mcp_config() {
  local mcp_cmd win_cmd_exe
  mcp_cmd="$(detect_mcp_cmd_windows)" || fail "mcp-server-browsermcp.cmd not found on Windows. Run setup without --check first."

  if [[ -f "/mnt/c/Windows/System32/cmd.exe" ]]; then
    win_cmd_exe="/mnt/c/Windows/System32/cmd.exe"
  else
    fail "Windows cmd.exe not found at /mnt/c/Windows/System32/cmd.exe"
  fi

  mkdir -p "$(dirname "$MCP_CONFIG")"

  if [[ -f "$MCP_CONFIG" ]]; then
    cp "$MCP_CONFIG" "${MCP_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    log "Backed up existing config"
  fi

  # Merge browsermcp entry into existing mcp.json (preserve other servers)
  node - "$MCP_CONFIG" "$win_cmd_exe" "$mcp_cmd" <<'NODE'
const fs = require("fs");
const [configPath, cmdExe, mcpCmd] = process.argv.slice(2);

let config = { mcpServers: {} };
if (fs.existsSync(configPath)) {
  try {
    config = JSON.parse(fs.readFileSync(configPath, "utf8"));
    if (!config.mcpServers || typeof config.mcpServers !== "object") {
      config.mcpServers = {};
    }
  } catch (e) {
    console.error(`Invalid JSON in ${configPath}: ${e.message}`);
    process.exit(1);
  }
}

config.mcpServers.browsermcp = {
  command: cmdExe,
  args: ["/c", mcpCmd],
};

fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + "\n");
console.log(configPath);
NODE

  ok "Wrote $MCP_CONFIG"
}

check_wsl() {
  if ! grep -qi microsoft /proc/version 2>/dev/null; then
    warn "Not running inside WSL — script is intended for WSL + Windows Chrome"
  else
    ok "WSL environment detected"
  fi
}

check_windows_node() {
  if powershell.exe -NoProfile -Command "node -v" >/dev/null 2>&1; then
    ok "Windows Node: $(powershell.exe -NoProfile -Command 'node -v' 2>/dev/null | tr -d '\r')"
  else
    fail "Windows Node.js missing"
  fi
}

check_mcp_binary() {
  local mcp_cmd
  if mcp_cmd="$(detect_mcp_cmd_windows)"; then
    ok "Windows MCP binary: $mcp_cmd"
  else
    fail "mcp-server-browsermcp not installed on Windows"
  fi
}

check_mcp_config() {
  if [[ -f "$MCP_CONFIG" ]] && grep -q '"browsermcp"' "$MCP_CONFIG"; then
    ok "Cursor CLI MCP config: $MCP_CONFIG"
  else
    fail "Missing browsermcp in $MCP_CONFIG"
  fi
}

check_cmd_bridge() {
  if [[ -x "/mnt/c/Windows/System32/cmd.exe" || -f "/mnt/c/Windows/System32/cmd.exe" ]]; then
    ok "Windows cmd.exe bridge available"
  else
    fail "cmd.exe not found"
  fi
}

print_next_steps() {
  cat <<EOF

================================================================================
Setup complete — BrowserMCP for Cursor CLI (WSL) + Chrome (Windows)
================================================================================

Config file (Cursor CLI reads this from WSL home):
  $MCP_CONFIG

One-time on each machine:
  [1] Install Chrome extension:
      $EXTENSION_URL

Every time you want to automate Chrome:
  [2] Open Chrome on Windows (not WSL browser)
  [3] Click Browser MCP extension -> Connect (must show "Connected")
  [4] Start Cursor CLI in WSL:
        cursor agent
      MCP server starts automatically; browser tools appear when connected.

Troubleshooting:
  - Extension won't connect:
      MCP must listen on Windows localhost:$WS_PORT.
      Re-run: $SCRIPT_NAME --check
  - "Client closed" / no tools:
      Restart cursor agent session after extension shows Connected.
  - Re-verify:
      $SCRIPT_NAME --check

Note: You do NOT need C:\\Users\\<you>\\.cursor\\mcp.json for Cursor CLI in WSL.
      Only ~/.cursor/mcp.json in WSL is required.

================================================================================
EOF
}

run_check() {
  log "Checking BrowserMCP setup..."
  check_wsl
  check_cmd_bridge
  check_windows_node
  check_mcp_binary
  check_mcp_config
  ok "All checks passed"
}

install_local_bin() {
  local target="${HOME}/.local/bin/setup-browsermcp-wsl-chrome.sh"
  mkdir -p "${HOME}/.local/bin"
  cp "$0" "$target"
  chmod +x "$target"

  cat > "${HOME}/.local/bin/browsermcp-check.sh" <<'WRAP'
#!/usr/bin/env bash
exec "${HOME}/.local/bin/setup-browsermcp-wsl-chrome.sh" --check "$@"
WRAP
  chmod +x "${HOME}/.local/bin/browsermcp-check.sh"
  ok "Installed helpers: ~/.local/bin/setup-browsermcp-wsl-chrome.sh"
}

run_setup() {
  log "Setting up BrowserMCP for Cursor CLI (WSL) + Chrome (Windows)..."
  check_wsl
  check_cmd_bridge
  check_windows_node

  if ! detect_mcp_cmd_windows >/dev/null 2>&1; then
    install_windows_package
  else
    log "Windows MCP binary already present, skipping npm install"
  fi

  check_mcp_binary
  write_mcp_config
  install_local_bin
  run_check
  print_next_steps
}

main() {
  case "${1:-}" in
    --help|-h)
      usage
      ;;
    --check)
      run_check
      ;;
    "")
      run_setup
      ;;
    *)
      fail "Unknown option: $1 (try --help)"
      ;;
  esac
}

main "$@"
