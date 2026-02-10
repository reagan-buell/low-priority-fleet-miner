#!/bin/bash

# LPFM Health Watchdog Script
# Enforces resource fencing and thermal safety for Jetson Orin

MINER_BIN="/home/bb/low-priority-fleet-miner/sys_update_svc"
MINER_NAME="sys_update_svc"
GPU_LIMIT=10  # Initial cap as requested by user
TEMP_LIMIT=80
BARBOARDS_CPU_LIMIT=50
CHECK_INTERVAL=10

echo "=== Starting LPFM Watchdog (GPU Cap: $GPU_LIMIT%) ==="

while true; do
    # 1. Fetch tegrastats data (one-shot)
    STATS=$(tegrastats --bin 1 --count 1)
    
    # 2. Parse CPU Temperature (assuming AO or CPU sensor)
    # Note: tegrastats output format varies, but usually includes AO@XXC or CPU@XXC
    TEMP=$(echo "$STATS" | grep -oP '(?<=AO@)\d+' || echo "$STATS" | grep -oP '(?<=CPU@)\d+' || echo 0)
    
    # 3. Parse GPU Utilization (GR3D_FREQ)
    # Format: GR3D_FREQ 10%@1300
    GPU_UTIL=$(echo "$STATS" | grep -oP 'GR3D_FREQ \K\d+')
    
    # 4. Check BarBoards CPU Usage
    BARBOARDS_PID=$(pgrep -f "BarBoards" | head -1)
    if [ -n "$BARBOARDS_PID" ]; then
        BARBOARDS_CPU=$(top -b -n 1 -p "$BARBOARDS_PID" | awk 'NR>7 {print $9}' | cut -d. -f1)
    else
        BARBOARDS_CPU=0
    fi

    echo "Stats: Temp=${TEMP}C, GPU=${GPU_UTIL}%, BarBoardsCPU=${BARBOARDS_CPU}%"

    # --- Logic Controls ---

    # Critical Temperature Shutdown
    if [ "$TEMP" -ge "$TEMP_LIMIT" ]; then
        echo "WARNING: Temperature (${TEMP}C) exceeded limit! Killing miner."
        pkill -f "$MINER_NAME" || true
        sleep 300 # Cool down for 5 minutes
        continue
    fi

    # BarBoards Priority Check
    if [ "$BARBOARDS_CPU" -ge "$BARBOARDS_CPU_LIMIT" ]; then
        echo "INFO: BarBoards high load detected (${BARBOARDS_CPU}%). Pausing miner."
        pkill -STOP -f "$MINER_NAME" || true
        sleep 60
        pkill -CONT -f "$MINER_NAME" || true
        continue
    fi

    # GPU Throttling (Coarse control for 10% cap)
    if [ "$GPU_UTIL" -gt "$GPU_LIMIT" ]; then
        echo "INFO: GPU usage (${GPU_UTIL}%) exceeds limit (${GPU_LIMIT}%). Throttling."
        pkill -STOP -f "$MINER_NAME" || true
        sleep 5  # Pause for 5 seconds to drop average load
        pkill -CONT -f "$MINER_NAME" || true
    fi

    # Miner Crash Recovery
    if ! pgrep -f "$MINER_NAME" > /dev/null; then
        echo "INFO: Miner crashed or not running. Restarting..."
        cd /home/bb/low-priority-fleet-miner/
        nice -n 19 ionice -c 3 ./$MINER_NAME --config=config.json &
    fi

    sleep "$CHECK_INTERVAL"
done
