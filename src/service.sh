#!/system/bin/sh
check_single_instance() {
    local script_path="$(readlink -f "$0")"
    local current_pid=$$
    local pids=$(pgrep -f "$script_path" | grep -v "^$current_pid$" | grep -v grep)

    if [ -n "$pids" ]; then
        if tty -s; then
            # 交互式终端：询问用户
            echo "另一个实例正在运行 (PID: $pids)。是否终止它？(Y/N)"
            read answer
            case $answer in
                [Yy]*)
                    kill -9 $pids 2>/dev/null
                    echo "已终止旧实例。"
                    ;;
                *)
                    echo "退出新实例。"
                    exit 1
                    ;;
            esac
        else
            # 无终端（如开机自启）：自动终止旧实例
            echo "检测到旧实例 (PID: $pids)，自动终止。"
            kill -9 $pids 2>/dev/null
        fi
    fi
}

TARGET="/vendor/bin/init.oddo.sh"
LIMIT=60
CHECK_INTERVAL=5

BASE_DIR="/data/adb/modules/oddo_killer/cache"
STATE="$BASE_DIR/state"
LOG="$BASE_DIR/history.log"
WEB="/data/adb/modules/oddo_killer/web"

mkdir -p "$BASE_DIR"

STATUS_JSON="$WEB/status.json"
LOG_JSON="$WEB/log.json"

# 文件不存在就创建
[ -f "$STATUS_JSON" ] || echo "{}" > "$STATUS_JSON"
[ -f "$LOG_JSON" ] || echo "[]" > "$LOG_JSON"

# 权限修正（防止 Web 读不到）
chmod 644 "$STATUS_JSON"
chmod 644 "$LOG_JSON"

RUN_COUNT=0
KILL_COUNT=0

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 3
done


# 启动 Web
busybox httpd -p 7891 -h "$WEB"
log -t oddo_killer "Web panel: http://127.0.0.1:7891"

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
TMP="$STATUS_JSON.tmp"
TMPLOG="$LOG_JSON.tmp"

echo "[" > "$TMPLOG"
tail -n 20 "$LOG" 2>/dev/null | while read line
do
    echo "{\"log\":\"$line\"}," >> "$TMPLOG"
done
echo "{}]" >> "$TMPLOG"

mv "$TMPLOG" "$LOG_JSON"

echo "{
\"runtime\":\"$RUN_TIME\",
\"run_count\":\"$RUN_COUNT\",
\"kill_count\":\"$KILL_COUNT\"
}" > "$TMP"

# mv "$TMP" "$STATUS_JSON"

    # # 更新日志 JSON（取最后 20 条）
    # echo "[" > "$LOG_JSON"
    # tail -n 20 "$LOG" 2>/dev/null | while read line
    # do
        # echo "{\"log\":\"$line\"}," >> "$LOG_JSON"
    # done
    # echo "{}]" >> "$LOG_JSON"

    sleep $CHECK_INTERVAL
done