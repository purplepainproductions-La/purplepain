#!/usr/bin/env bash
# Manual AI Toolkit install on a plain RunPod PyTorch pod.
# Skip this if you use the official AI Toolkit template (README, step 1).
#
# Everything goes under /workspace (the volume) so it survives pod restarts.
# Usage:  AI_TOOLKIT_AUTH=yourpassword HF_TOKEN=hf_xxx bash runpod_setup.sh
set -euo pipefail

: "${AI_TOOLKIT_AUTH:?set AI_TOOLKIT_AUTH to a UI password}"
export HF_HOME=/workspace/hf_cache
mkdir -p /workspace/{datasets,output,hf_cache}

apt-get update && apt-get install -y git ffmpeg tmux curl
if ! command -v node >/dev/null || (( $(node -p 'process.versions.node.split(".")[0]') < 20 )); then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

cd /workspace
[[ -d ai-toolkit ]] || git clone https://github.com/ostris/ai-toolkit.git
cd ai-toolkit
git pull --ff-only
git submodule update --init --recursive

[[ -d venv ]] || python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
# pinned to what the AI Toolkit README specifies (CUDA 13.0 wheels).
# The pod's driver must support CUDA 13: filter for it when you deploy.
pip install --no-cache-dir torch==2.13.0 torchvision==0.28.0 torchaudio==2.11.0 \
  --index-url https://download.pytorch.org/whl/cu130
pip install -r requirements.txt

if [[ -n ${HF_TOKEN:-} ]]; then
  echo "HF_TOKEN=$HF_TOKEN" > .env
fi

# UI on port 8675, kept alive in tmux so a dropped connection doesn't kill it
tmux kill-session -t aitk 2>/dev/null || true
tmux new -d -s aitk "cd /workspace/ai-toolkit/ui && \
  HF_HOME=$HF_HOME AI_TOOLKIT_AUTH='$AI_TOOLKIT_AUTH' npm run build_and_start"

echo "UI starting in tmux session 'aitk' (tmux attach -t aitk)."
echo "Open it from RunPod: Connect -> HTTP port 8675 (expose 8675 in the pod settings)."
