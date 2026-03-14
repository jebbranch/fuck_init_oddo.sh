#!/system/bin/sh

ui_print "************************************"
ui_print "        oddo Watchdog Monitor        "
ui_print "************************************"
ui_print ""
ui_print "本模块功能："
ui_print ""
ui_print "• 监控 /vendor/bin/init.oddo.sh 异常运行"
ui_print "• 当运行超过设定时间自动结束进程"
ui_print "• 记录每一次 Kill 的具体时间（精确到秒）"
ui_print "• 记录完整命令行参数（例如 vvv）"
ui_print "• 提供 Web 实时监控面板"
ui_print ""
ui_print "Web 面板地址："
ui_print "http://127.0.0.1:8080"
ui_print ""
ui_print "适用于："
ui_print "• 移植 ROM"
ui_print "• 异常 Vendor 脚本"
ui_print "• 发热 / 耗电排查"
ui_print ""
ui_print "模块不会修改系统文件"
ui_print "仅运行时监控，安全性较高"
ui_print ""
ui_print "------------------------------------"

sleep 1

ui_print "- 检测 BusyBox..."

if command -v busybox >/dev/null 2>&1; then
    ui_print "  BusyBox 已存在"
else
    ui_print "  未检测到 BusyBox（Magisk 内置版本将被使用）"
fi

sleep 1

ui_print "- 安装 Watchdog 脚本..."

set_perm $MODPATH/service.sh 0 0 0755

ui_print ""
ui_print "安装完成"
ui_print "重启后生效"
ui_print ""
ui_print "************************************"