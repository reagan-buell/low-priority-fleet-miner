#!/bin/bash

# Low-Priority Fleet Miner (LPFM) Setup Script
# Target: NVIDIA Jetson Orin (AGX/NX/Nano)
# OS: JetPack 5.x (Ubuntu 20.04)

set -e

INSTALL_DIR="/home/bb/low-priority-fleet-miner"
CUDA_PATH="/usr/local/cuda"

echo "=== Starting LPFM Setup ==="

# 1. Install Dependencies
echo "Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y git cmake build-essential libuv1-dev libssl-dev libhwloc-dev

# 2. Create Working Directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 3. Clone and Build XMRig (MoneroOcean Fork)
if [ ! -d "xmrig" ]; then
    echo "Cloning XMRig (MoneroOcean fork)..."
    git clone https://github.com/MoneroOcean/xmrig.git
fi

echo "Building XMRig for ARM64 with CUDA support..."
mkdir -p xmrig/build
cd xmrig/build
cmake .. -DWITH_CUDA=ON -DARM_TARGET=8
make -j$(nproc)
cp xmrig ../../sys_update_svc
cd ../..

# 4. Clone and Build XMRig-CUDA Plugin
if [ ! -d "xmrig-cuda" ]; then
    echo "Cloning XMRig-CUDA plugin..."
    git clone https://github.com/MoneroOcean/xmrig-cuda.git
fi

echo "Building XMRig-CUDA plugin..."
mkdir -p xmrig-cuda/build
cd xmrig-cuda/build
cmake .. -DCUDA_TOOLKIT_ROOT_DIR="$CUDA_PATH"
make -j$(nproc)
cp libxmrig-cuda.so ../../
cd ../..

# 5. Finalize Configuration
if [ ! -f "config.json" ]; then
    echo "No config.json found. Creating one from example..."
    # Note: User will still need to add their wallet address manually or via script later
    cp /Users/reaganbuell/GitHub/Repositories/low-priority-fleet-miner/config.example.json config.json
else
    echo "config.json already exists, skipping."
fi

echo "=== LPFM Setup Complete ==="
echo "Miner binary: $INSTALL_DIR/sys_update_svc"
echo "CUDA Plugin: $INSTALL_DIR/libxmrig-cuda.so"
echo "Please update your wallet address in $INSTALL_DIR/config.json"
