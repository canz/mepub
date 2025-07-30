#!/usr/bin/env bash
#
# AI-Toolkit 1-Click Install *or* Restart for RunPod
# -------------------------------------------------


set -euo pipefail
WORKDIR="/workspace"         # persistent volume
REPO_DIR="$WORKDIR/ai-toolkit"
NVM_DIR="$WORKDIR/.nvm"

##############################################################################
# Fast path: existing install → start the UI and exit
##############################################################################
if [[ -d "$REPO_DIR" && -f "$REPO_DIR/venv/bin/activate" ]]; then
  echo "Existing AI-Toolkit installation detected – launching UI..."
  (
    source "$REPO_DIR/venv/bin/activate"
    export NVM_DIR="$NVM_DIR"
    # shellcheck disable=SC1091
    source "$NVM_DIR/nvm.sh"
    nvm use 22 >/dev/null
    cd "$REPO_DIR/ui"
    npm run start          # quick start (no rebuild)
  )
  exit 0
fi

##############################################################################
# Full install path (first-time only)
##############################################################################
echo ""
echo "=== AI-Toolkit first-time installation ==="
echo ""

# 0. Ask which GPU so we pull the right Torch wheel
echo "Which GPU is this pod running?"
echo "  [1] RTX-5000-series (Blackwell, sm_120) or newer"
echo "  [2] Anything older (Ada, Hopper, Ampere, etc.)"
read -rp "Enter 1 or 2: " GPU_CHOICE

case "$GPU_CHOICE" in
  1) CUDA_STREAM=cu128
     TORCH_SPEC="torch==2.7.0+${CUDA_STREAM} torchvision==0.22.0+${CUDA_STREAM} torchaudio==2.7.0+${CUDA_STREAM}" ;;
  2) CUDA_STREAM=cu126
     TORCH_SPEC="torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0" ;;
  *) echo "Unrecognised choice '${GPU_CHOICE}'. Aborting."; exit 1 ;;
esac

# 1. System packages
if [[ $(id -u) -ne 0 ]]; then SUDO=sudo; else SUDO=''; fi
$SUDO apt-get update -y
$SUDO apt-get install -y --no-install-recommends \
        git python3 python3-venv python3-pip build-essential curl

# 2. Clone repo into /workspace
cd "$WORKDIR"
git clone https://github.com/ostris/ai-toolkit.git

# 3. Python venv + Torch
cd "$REPO_DIR"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install --no-cache-dir $TORCH_SPEC \
  --index-url "https://download.pytorch.org/whl/${CUDA_STREAM}"
pip install -r requirements.txt

# 4. nvm + Node 22   (also in /workspace)
export NVM_DIR="$NVM_DIR"

# FIX: Manually create the NVM directory to satisfy the installer's prerequisite check.
mkdir -p "$NVM_DIR"

# Check if nvm is already installed before re-running the installer
if [[ ! -f "$NVM_DIR/nvm.sh" ]]; then
  echo "Installing NVM..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

# shellcheck disable=SC1091
source "$NVM_DIR/nvm.sh"
nvm install 22
nvm use 22

# 5. Build UI and launch
cd ui
npm install
npm run build_and_start &      # run in background so script returns
UI_PID=$!

echo ""
echo "=== Installation complete – UI running (PID $UI_PID) ==="
echo "Next time, simply run ./installer.sh again and it will start the UI instantly."
echo ""