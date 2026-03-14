#!/system/bin/sh

TARGET="/vendor/bin/init.oddo.sh"
LIMIT=180
CHECK_INTERVAL=8

BASE="/data/local/tmp/oddo_watchdog"
STATE="$BASE/state"
LOG="$BASE/history.log"

WEB="/data/adb/modules/oddo-watchdog/web"
JSON_STATUS="$WEB/status.json"
JSON_LOG="$WEB/log.json"

mkdir -p "$BASE"

RUN_COUNT=0
KILL_COUNT=0

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 3
done

# 启动 Web
busybox httpd -p 8080 -h "$WEB"
log -t oddo_watchdog "Web panel: http://127.0.0.1:8080"

while true
do
    PID=$(pgrep -f "$TARGET")

    NOW=$(date +%s)
    TIME_STR=$(date "+%Y-%m-%d %H:%M:%S")

    if [ -n "$PID" ]; then

        CMD=$(ps -A -o PID,ARGS | grep "$PID" | grep "$TARGET" | head -n 1 | sed 's/^[ ]*//')

        if [ ! -f "$STATE" ]; then
            echo "$PID $NOW" > "$STATE"
            RUN_COUNT=$((RUN_COUNT+1))
        else
            OLD_PID=$(awk '{print $1}' $STATE)
            START=$(awk '{print $2}' $STATE)

            if [ "$OLD_PID" != "$PID" ]; then
                echo "$PID $NOW" > "$STATE"
            else
                RUN_TIME=$((NOW - START))

                if [ "$RUN_TIME" -ge "$LIMIT" ]; then

                    echo "$TIME_STR | $CMD | pid=$PID" >> "$LOG"

                    KILL_COUNT=$((KILL_COUNT+1))

                    kill -9 "$PID"

                    rm -f "$STATE"
                fi
            fi
        fi
    else
        RUN_TIME=0
        [ -f "$STATE" ] && rm -f "$STATE"
    fi

    # 更新状态 JSON
    echo "{
\"runtime\":\"$RUN_TIME\",
\"run_count\":\"$RUN_COUNT\",
\"kill_count\":\"$KILL_COUNT\"
}" > "$JSON_STATUS"

    # 更新日志 JSON（取最后 20 条）
    echo "[" > "$JSON_LOG"
    tail -n 20 "$LOG" 2>/dev/null | while read line
    do
        echo "{\"log\":\"$line\"}," >> "$JSON_LOG"
    done
    echo "{}]" >> "$JSON_LOG"

    sleep $CHECK_INTERVAL
done