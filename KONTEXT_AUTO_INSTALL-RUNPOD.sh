#!/usr/bin/env bash
# Kontext models + nodes installer for RunPod ComfyUI images
# Author : Aitrepreneur • 2025-07-07

set -euo pipefail

# ──────────────── CONSTANTS AND HELPERS ─────────────────────────
MODEL_VERSION="Q8_0"
HF_BASE="https://huggingface.co/Aitrepreneur/FLX/resolve/main"
PYTHON="/workspace/ComfyUI/venv/bin/python3"

FP8_MODEL="flux1-kontext-dev-fp8-e4m3fn.safetensors"
NUNCHAKU_MODELS=(
  "svdq-int4_r32-flux.1-kontext-dev.safetensors"
)

grab () {
  [[ -f "$1" ]] && { echo " • $(basename "$1") exists – skip"; return; }
  echo " • downloading $(basename "$1")"
  mkdir -p "$(dirname "$1")"
  curl -L --progress-bar --show-error -o "$1" "$2"
}

get_node () {
  local dir=$1 url=$2 flag=${3:-}
  if [[ -d "custom_nodes/$dir" ]]; then
    echo " [SKIP] $dir already present."
  else
    echo " • cloning $dir"
    git clone $flag "$url" "custom_nodes/$dir"
  fi
}

# ──────────────── SETUP AND VERIFICATION ────────────────────
cd /workspace/ComfyUI
[[ -d models && -d custom_nodes ]] || {
  echo "[ERROR] Run this script inside your ComfyUI folder at /workspace/ComfyUI"
  exit 1
}

# ──────────────── CUSTOM NODES ───────────────────────────────
echo
echo "──────── Cloning All Custom Nodes ────────"
get_node "ComfyUI-Manager"    "https://github.com/ltdrdata/ComfyUI-Manager.git"
get_node "ComfyUI-nunchaku"   "https://github.com/mit-han-lab/ComfyUI-nunchaku.git"
get_node "ComfyUI-GGUF"       "https://github.com/city96/ComfyUI-GGUF.git"
get_node "rgthree-comfy"      "https://github.com/rgthree/rgthree-comfy.git"
get_node "ComfyUI-KJNodes"    "https://github.com/kijai/ComfyUI-KJNodes.git"
get_node "ComfyUI-Crystools"  "https://github.com/crystian/ComfyUI-Crystools.git"
get_node "ComfyUI_essentials" "https://github.com/cubiq/ComfyUI_essentials.git"
get_node "wlsh_nodes"         "https://github.com/wallish77/wlsh_nodes.git"
get_node "ComfyUI-NAG"        "https://github.com/ChenDarYen/ComfyUI-NAG.git"

# ──────────────── ENVIRONMENT INSTALLATION───────────────
echo " Installing all custom node requirements..."
find custom_nodes -maxdepth 2 -name requirements.txt | grep -v "ComfyUI-nunchaku" | while read -r req; do
  echo "   • Installing from $req"
  "$PYTHON" -m pip install -r "$req"
done
"$PYTHON" -m pip install -q pydantic~=2.0 matplotlib opencv-python-headless piexif gguf

"$PYTHON" -m pip install "https://github.com/mit-han-lab/nunchaku/releases/download/v0.3.1/nunchaku-0.3.1+torch2.5-cp311-cp311-linux_x86_64.whl" 
"$PYTHON" -m pip install insightface 
"$PYTHON" -m pip install facexlib 
"$PYTHON" -m pip install onnxruntime-gpu
# ──────────────── MODELS ────────────────────────────────────
echo
echo "──────── Downloading All Model Files ────────"
grab "models/loras/FLUX.1-Turbo-Alpha.safetensors" "$HF_BASE/FLUX.1-Turbo-Alpha.safetensors?download=true"
grab "models/clip/clip_l.safetensors" "$HF_BASE/clip_l.safetensors?download=true"
grab "models/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors" "$HF_BASE/t5xxl_fp8_e4m3fn_scaled.safetensors?download=true"
grab "models/unet/flux1-kontext-dev-${MODEL_VERSION}.gguf" "$HF_BASE/flux1-kontext-dev-${MODEL_VERSION}.gguf?download=true"
grab "models/diffusion_models/${FP8_MODEL}" "$HF_BASE/${FP8_MODEL}?download=true"
for nfile in "${NUNCHAKU_MODELS[@]}"; do grab "models/diffusion_models/${nfile}" "$HF_BASE/${nfile}?download=true"; done
for f in 4x-ClearRealityV1.pth RealESRGAN_x4plus_anime_6B.pth; do grab "models/upscale_models/$f" "$HF_BASE/$f"; done
grab "models/vae/ae.safetensors" "$HF_BASE/ae.safetensors?download=true"

# ──────────────── FINISH ───────────────────────────────────
echo
echo "✅  Kontext models, FP8 diffusion & Nunchaku backend ready."