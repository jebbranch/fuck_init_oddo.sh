# oddo_killer - 进程监控与自动终止 Magisk 模块

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## 简介

**oddo_killer** 是一个 Magisk 模块，用于监控指定的进程（默认为 **/vendor/bin/init.oddo.sh**），当该进程连续运行超过设定的时间阈值（默认 60 秒）时，自动将其强制终止，并记录日志。（这个脚本其实是LazyBones为marble机型制作Coloros15的移植包的时候写的修bug脚本，但是有个致命轮询，一旦死循环就会吃cpu然后发热掉电加快）

模块内置一个轻量级 Web 面板，可通过浏览器实时查看进程运行状态、累计统计和终止日志。

该模块适用于需要限制某些后台进程长时间占用资源的场景，例如监控异常耗电进程、控制测试脚本运行时长等。

## 功能特性

- **进程监控**：定期检测目标进程是否存在，并计算其已运行时间。
- **自动终止**：当进程运行时间超过阈值（默认 60 秒）时，执行 `kill -9` 强制结束。
- **单实例保护**：脚本自身仅允许一个实例运行（手动运行时询问是否结束旧进程，开机自启时自动清理旧实例）。
- **Web 面板**：基于 `busybox httpd` 提供 HTTP 服务，展示：
  - 当前进程运行时间（`runtime`）
  - 累计启动次数（`run_count`）
  - 累计杀死次数（`kill_count`）
  - 当前进程完整命令行（`current_cmd`）
  - 最近 20 条终止日志
- **数据持久化**：运行计数和日志保存在 `/data/adb/modules/oddo_killer/cache/` 下，重启不丢失。
- **开机自启**：集成 Magisk 模块机制，在系统启动完成后自动运行。
- **低开销**：使用 `sleep` 间隔检查，对系统影响小。

## 文件结构

/data/adb/modules/oddo_killer/
├── service.sh          # 主脚本（包含监控逻辑和 Web 服务器）
├── web/                 # Web 面板根目录
│   ├── index.html       # 前端页面
│   ├── status.json      # 实时状态接口（自动生成）
│   └── log.json         # 日志接口（自动生成）
└── cache/               # 数据缓存目录（自动创建）
├── state            # 记录当前进程 PID 和启动时间
├── history.log      # 终止日志文本
└── debug.log        # 调试日志（可选）

## 安装
一.手动安装
1. 将本项目克隆或下载到本地，确保目录结构如上。
2. 将整个 `oddo_killer` 文件夹复制到 Magisk 模块目录：`/data/adb/modules/`
3. 赋予执行权限：
   
   chmod 755 /data/adb/modules/oddo_killer/service.sh

1. 重启设备，或手动执行 sh /data/adb/modules/oddo_killer/service.sh 测试。

二.刷入
1.下载最新的Release包
2.打开管理器
3.刷入
4.重启设备

配置说明

您可以通过编辑 service.sh 开头的配置区域来调整参数：

变量 默认值 说明
TARGET /vendor/bin/init.oddo.sh 要监控的目标进程（支持正则）
LIMIT 60 进程最长运行时间（秒）
CHECK_INTERVAL 5 监控检查间隔（秒）
HTTP_PORT 7891 Web 面板端口
BASE_DIR /data/adb/modules/oddo_killer/cache 数据存储目录
WEB_DIR /data/adb/modules/oddo_killer/web Web 文件目录

修改后保存并重启模块即可生效。

## 使用

Web 面板

设备启动后，在浏览器中访问 http://127.0.0.1:7891 即可打开监控面板。页面自动每秒刷新，显示：

· Runtime：当前目标进程已运行秒数（若无进程则显示 0）
· Run Count：脚本启动以来目标进程被记录启动的次数
· Kill Count：累计杀死次数
· Command：当前目标进程的完整命令行（含参数）
· Kill Logs：最近 20 条杀死记录，格式为 时间 | 命令行 | pid=xxx

日志文件

· history.log：所有杀死记录，文本格式，可直接查看。
· debug.log：如果需要在脚本中启用调试，可在 service.sh 中取消注释 DEBUG_LOG 相关行，记录每次循环的详细信息。

#⚠️注意事项⚠️

· 依赖：模块依赖 busybox 提供的 httpd 命令。Magisk 默认包含 busybox，若您的环境缺失，请安装 busybox 模块。
· 权限：确保 service.sh 可执行，Web 目录下的 JSON 文件需可读写（脚本已自动设置 644）。
· 多进程匹配：若目标进程可能出现多个实例，脚本默认只处理 pgrep -f 返回的第一个 PID。如需监控所有实例，可修改逻辑。
· 安全：Web 面板仅监听本地端口，外部无法访问，请放心使用。
· 停止模块：若要临时停止监控，可杀死对应进程：pkill -f service.sh，或直接移除模块重启。

## ？常见问题 ！

Q: Web 页面无法访问？
A: 检查端口是否被占用，或 busybox httpd 是否可用。可尝试手动运行 busybox httpd -p 7891 -h /data/adb/modules/oddo_killer/web 测试。

Q: 运行时计数不准确？
A: 请确保目标进程的 PID 未发生变化（如被系统重启）。脚本每次检测到 PID 改变会重新计时。

Q: 如何查看调试信息？
A: 在 service.sh 中取消注释 DEBUG_LOG 相关行，然后重启模块，查看 /data/adb/modules/oddo_killer/cache/debug.log。

##贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

##许可证

Copyright © 2017-2026 Clockworks Studio & DeepSeek

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see https://www.gnu.org/license 
