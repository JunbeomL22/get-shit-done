#!/usr/bin/env bash
set -e

# Colors
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
DIM='\033[2m'
RESET='\033[0m'

echo ""
echo -e "${CYAN}   ██████╗ ███████╗██████╗${RESET}"
echo -e "${CYAN}  ██╔════╝ ██╔════╝██╔══██╗${RESET}"
echo -e "${CYAN}  ██║  ███╗███████╗██║  ██║${RESET}"
echo -e "${CYAN}  ██║   ██║╚════██║██║  ██║${RESET}"
echo -e "${CYAN}  ╚██████╔╝███████║██████╔╝${RESET}"
echo -e "${CYAN}   ╚═════╝ ╚══════╝╚═════╝${RESET}"
echo ""
echo -e "  YOLO Installer"
echo ""

# ── Step 1: Ensure jq is installed ──────────────────────

install_jq() {
  if command -v jq &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} jq is available ($(jq --version))"
    return 0
  fi

  echo -e "  ${YELLOW}i${RESET} jq not found — installing..."

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get &>/dev/null; then
      sudo apt-get update -qq && sudo apt-get install -y -qq jq
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y -q jq
    elif command -v yum &>/dev/null; then
      sudo yum install -y -q jq
    elif command -v pacman &>/dev/null; then
      sudo pacman -S --noconfirm jq
    elif command -v apk &>/dev/null; then
      sudo apk add --quiet jq
    else
      echo -e "  ${YELLOW}⚠${RESET} Could not detect package manager. Installing static binary..."
      install_jq_binary
      return $?
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew &>/dev/null; then
      brew install jq
    else
      echo -e "  ${YELLOW}⚠${RESET} Homebrew not found. Installing static binary..."
      install_jq_binary
      return $?
    fi
  else
    echo -e "  ${YELLOW}⚠${RESET} Unsupported OS. Installing static binary..."
    install_jq_binary
    return $?
  fi

  if command -v jq &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} jq installed ($(jq --version))"
  else
    echo -e "  ${YELLOW}⚠${RESET} jq installation may have failed"
    return 1
  fi
}

# Fallback: download static jq binary
install_jq_binary() {
  local JQ_VERSION="jq-1.7.1"
  local BASE_URL="https://github.com/jqlang/jq/releases/download/${JQ_VERSION}"
  local DEST_DIR="$HOME/.local/bin"
  local PLATFORM ARCH FILENAME

  case "$(uname -s)" in
    Linux)  PLATFORM="linux" ;;
    Darwin) PLATFORM="macos" ;;
    *)      echo -e "  ${YELLOW}⚠${RESET} Unsupported platform: $(uname -s)"; return 1 ;;
  esac

  case "$(uname -m)" in
    x86_64)  ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)       echo -e "  ${YELLOW}⚠${RESET} Unsupported architecture: $(uname -m)"; return 1 ;;
  esac

  FILENAME="jq-${PLATFORM}-${ARCH}"

  mkdir -p "$DEST_DIR"
  echo -e "  ${DIM}Downloading ${FILENAME}...${RESET}"
  curl -fsSL "${BASE_URL}/${FILENAME}" -o "${DEST_DIR}/jq"
  chmod +x "${DEST_DIR}/jq"

  # Verify
  if "${DEST_DIR}/jq" --version &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} jq installed to ${DEST_DIR}/jq"
  else
    rm -f "${DEST_DIR}/jq"
    echo -e "  ${YELLOW}⚠${RESET} Downloaded binary failed verification"
    return 1
  fi

  # Check PATH
  if ! echo "$PATH" | tr ':' '\n' | grep -q "^${DEST_DIR}$"; then
    echo -e "  ${YELLOW}⚠${RESET} Add to your shell profile: ${DIM}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}"
  fi
}

# ── Step 2: Ensure Node.js is available ─────────────────

if ! command -v node &>/dev/null; then
  echo -e "  ${YELLOW}✗${RESET} Node.js is required but not found."
  echo -e "    Install from: ${CYAN}https://nodejs.org${RESET}"
  exit 1
fi

echo -e "  ${GREEN}✓${RESET} Node.js $(node --version)"

# ── Step 3: Install jq ─────────────────────────────────

install_jq

# ── Step 4: Run GSD installer ──────────────────────────

echo ""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
node "${SCRIPT_DIR}/bin/install.js" --skip-jq "$@"
