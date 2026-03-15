#!/system/bin/sh

# ==================== 配置区域 ====================
TARGET="/vendor/bin/init.oddo.sh"
LIMIT=60                     # 进程最长运行时间（秒）
CHECK_INTERVAL=5             # 检查间隔（秒）
BASE_DIR="/data/adb/modules/oddo_killer/cache"
WEB_DIR="/data/adb/modules/oddo_killer/web"
STATE_FILE="$BASE_DIR/state"          # 记录目标进程 PID 和启动时间
LOG_FILE="$BASE_DIR/history.log"       # 被杀记录
STATUS_JSON="$WEB_DIR/status.json"     # Web 状态接口
LOG_JSON="$WEB_DIR/log.json"           # Web 日志接口
HTTP_PORT=7891

# ==================== 初始化目录和文件 ====================
init_environment() {
    mkdir -p "$BASE_DIR" "$WEB_DIR"
    # 初始化 JSON 文件（空对象或空数组）
    [ -f "$STATUS_JSON" ] || echo '{}' > "$STATUS_JSON"
    [ -f "$LOG_JSON" ]    || echo '[]' > "$LOG_JSON"
    chmod 644 "$STATUS_JSON" "$LOG_JSON"
}

# ==================== 单实例检查====================
check_single_instance() {
    local script_path="$(readlink -f "$0")"
    local current_pid=$$
    # 查找运行相同脚本的其他进程（排除自身和 grep）
    local pids=$(pgrep -f "$script_path" | grep -v "^$current_pid$" | grep -v grep)

    if [ -n "$pids" ]; then
        if tty -s; then
            # 终端交互模式：询问用户
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

# ==================== 更新状态 JSON ====================
update_status_json() {
    local tmp="$STATUS_JSON.tmp"
    # 注意：数值字段不加引号，确保 JSON 格式正确
    cat > "$tmp" <<EOF
{
"runtime": $RUN_TIME,
"run_count": $RUN_COUNT,
"kill_count": $KILL_COUNT
}
EOF
    mv "$tmp" "$STATUS_JSON"
}

# ==================== 更新日志 JSON（取最后20条）====================
update_log_json() {
    local tmp="$LOG_JSON.tmp"
    echo "[" > "$tmp"
    if [ -f "$LOG_FILE" ]; then
        tail -n 20 "$LOG_FILE" | while read line; do
            # 转义双引号，防止破坏 JSON
            line_escaped=$(echo "$line" | sed 's/"/\\"/g')
            echo "{\"log\":\"$line_escaped\"}," >> "$tmp"
        done
    fi
    # 去掉最后一个逗号并闭合数组
    sed -i '$ s/,$//' "$tmp" 2>/dev/null
    echo "]" >> "$tmp"
    mv "$tmp" "$LOG_JSON"
}

# ==================== 主循环 ====================
main_loop() {
    # 初始化计数器（每次脚本启动重置）
    RUN_COUNT=0
    KILL_COUNT=0
    # 循环前先更新一次 JSON，确保 Web 有初始数据
    RUN_TIME=0
    update_status_json
    update_log_json

    # 启动 Web 服务器（放在第一次更新之后）
    busybox httpd -p $HTTP_PORT -h "$WEB_DIR"
    log -t oddo_killer "Web panel: http://127.0.0.1:$HTTP_PORT"

    while true; do
        local pid=$(pgrep -f "$TARGET")
        local now=$(date +%s)
        local time_str=$(date "+%Y-%m-%d %H:%M:%S")

        if [ -n "$pid" ]; then
            # 获取进程完整命令行（用于日志）
            local cmd=$(ps -A -o PID,ARGS | grep "$pid" | grep "$TARGET" | head -n 1 | sed 's/^[ ]*//')

            if [ ! -f "$STATE_FILE" ]; then
                # 首次记录该进程
                echo "$pid $now" > "$STATE_FILE"
                RUN_COUNT=$((RUN_COUNT + 1))
            else
                local old_pid=$(awk '{print $1}' "$STATE_FILE")
                local start_time=$(awk '{print $2}' "$STATE_FILE")

                if [ "$old_pid" != "$pid" ]; then
                    # 进程 PID 变了（重启或被替换），重新记录
                    echo "$pid $now" > "$STATE_FILE"
                else
                    local run_time=$((now - start_time))
                    if [ "$run_time" -ge "$LIMIT" ]; then
                        # 超过限制，杀掉并记录
                        echo "$time_str | $cmd | pid=$pid" >> "$LOG_FILE"
                        KILL_COUNT=$((KILL_COUNT + 1))
                        kill -9 "$pid"
                        rm -f "$STATE_FILE"
                    fi
                fi
            fi
        else
            # 目标进程不存在
            run_time=0
            [ -f "$STATE_FILE" ] && rm -f "$STATE_FILE"
        fi

        # 更新 JSON 文件（即使 run_time 是局部变量，我们通过 RUN_TIME 传递）
        RUN_TIME=${run_time:-0}
        update_status_json
        update_log_json

        sleep $CHECK_INTERVAL
    done
}

# ==================== 执行入口 ====================
init_environment
check_single_instance

# 等待系统启动完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 3
done

# 进入主循环
main_loop