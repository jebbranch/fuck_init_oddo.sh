#!/system/bin/sh

TARGET_NAME="init.oddo.sh"
LIMIT=180              # 超时时间（秒）
WARNING_TIME=20        # 提前警告时间
CHECK_INTERVAL=20      # 检测间隔（秒）
STATE_FILE="/data/local/tmp/oddo_watch"

log(){
    echo "[oddo-killer] $1"
}

while true
do
    PID=$(pidof $TARGET_NAME)

    if [ -n "$PID" ]; then
        NOW=$(date +%s)

        if [ ! -f "$STATE_FILE" ]; then
            echo "$PID $NOW" > "$STATE_FILE"
            log "Detected PID=$PID start timing"
        else
            OLD_PID=$(awk '{print $1}' $STATE_FILE)
            START_TIME=$(awk '{print $2}' $STATE_FILE)

            if [ "$OLD_PID" != "$PID" ]; then
                echo "$PID $NOW" > "$STATE_FILE"
                log "PID changed, reset timer"
            else
                RUN_TIME=$((NOW - START_TIME))

                if [ "$RUN_TIME" -ge "$LIMIT" ]; then

                    log "Timeout $RUN_TIME s, warning before kill"

                    cmd notification post -S bigtext -t "Fuck oddo" oddo_watch \
                    "init.oddo.sh 已运行超过3分钟，20秒后将强制结束以降低发热"

                    sleep $WARNING_TIME

                    NEW_PID=$(pidof $TARGET_NAME)

                    # 二次确认 PID 未变化且仍然存在
                    if [ "$NEW_PID" = "$PID" ] && [ -n "$NEW_PID" ]; then
                        log "Killing PID=$NEW_PID"
                        kill -9 "$NEW_PID"
                    else
                        log "Process changed or exited, skip kill"
                    fi

                    rm -f "$STATE_FILE"
                fi
            fi
        fi
    else
        [ -f "$STATE_FILE" ] && rm -f "$STATE_FILE"
    fi

    sleep $CHECK_INTERVAL
done