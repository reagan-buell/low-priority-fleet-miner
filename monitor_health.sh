#!/bin/bash

# LPFM Health Watchdog Script
# Enforces resource fencing and thermal safety for Jetson Orin

MINER_BIN="/home/bb/low-priority-fleet-miner/sys_update_svc"
MINER_NAME="sys_update_svc"
GPU_LIMIT=50  # Increased from 10% to 50% as requested
TEMP_LIMIT=80
BARBOARDS_CPU_LIMIT=50
CHECK_INTERVAL=10

echo "=== Starting LPFM Watchdog (GPU Cap: $GPU_LIMIT%) ==="

while true; do
    # 1. Fetch tegrastats data (one-shot)
    STATS=$(tegrastats --count 1)
    
    # 2. Parse CPU Temperature
    # Look for anything ending in @XX.XC or @XXC
    TEMP=$(echo "$STATS" | grep -oE '[A-Z0-9]+@[0-9.]+' | head -1 | cut -d@ -f2 | cut -d. -f1)
    TEMP=${TEMP:-0}
    
    # 3. Parse GPU Utilization (GR3D_FREQ)
    # Flexible match for "GR3D_FREQ XX%"
    GPU_UTIL=$(echo "$STATS" | grep -o 'GR3D_FREQ [0-9]\+%' | grep -o '[0-9]\+' | head -1)
    GPU_UTIL=${GPU_UTIL:-0}
    
    # 4. Check BarBoards CPU Usage
    BARBOARDS_PID=$(pgrep -f "BarBoards" | head -1)
    if [ -n "$BARBOARDS_PID" ]; then
        # Try ps first, fallback to top
        BARBOARDS_CPU=$(ps -p "$BARBOARDS_PID" -o %cpu= | awk '{print int($1)}' 2>/dev/null || echo 0)
    else
        BARBOARDS_CPU=0
    fi

    # Debug: If values are 0, log the raw stats to help me diagnose
    if [ "$GPU_UTIL" -eq 0 ] && [ "$TEMP" -eq 0 ]; then
        echo "DEBUG: Raw Stats: $STATS" >> /home/bb/low-priority-fleet-miner/tegrastats_debug.log
    fi

    # Ensure we have integers for comparison
    TEMP=${TEMP:-0}
    GPU_UTIL=${GPU_UTIL:-0}
    BARBOARDS_CPU=${BARBOARDS_CPU:-0}

    echo "Stats: Temp=${TEMP}C, GPU=${GPU_UTIL}%, BarBoardsCPU=${BARBOARDS_CPU}%"

    # --- Logic Controls ---

    # Critical Temperature Shutdown
    if [ "$TEMP" -gt "$TEMP_LIMIT" ]; then
        echo "WARNING: Temperature (${TEMP}C) exceeded limit! Killing miner."
        pkill -f "$MINER_NAME" || true
        sleep 300 
        continue
    fi

    # BarBoards Priority Check
    if [ "$BARBOARDS_CPU" -gt "$BARBOARDS_CPU_LIMIT" ]; then
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
        sleep 5 
        pkill -CONT -f "$MINER_NAME" || true
    fi

    # Miner Crash Recovery
    if ! pgrep -f "$MINER_NAME" > /dev/null; then
        if [ -f "$MINER_BIN" ]; then
            echo "INFO: Miner crashed or not running. Restarting..."
            cd /home/bb/low-priority-fleet-miner/
            nice -n 19 ionice -c 3 ./"$MINER_NAME" --config=config.json &
        else
            echo "ERROR: Miner binary $MINER_BIN not found. Did the build fail?"
            sleep 60
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
