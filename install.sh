#!/bin/bash

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 安装目录
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="log-cleaner"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"

# 脚本 URL（需要替换为实际的 URL）
SCRIPT_URL="https://raw.githubusercontent.com/georgestore/log-cleaner/v0.0.2-alpha/log-cleaner.sh"

# 输出信息函数
print_msg() {
    local msg=$1
    local level=${2:-"INFO"}
    case $level in
        "ERROR")
            echo -e "${RED}$msg${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}$msg${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}$msg${NC}"
            ;;
        *)
            echo -e "$msg"
            ;;
    esac
}

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    print_msg "请使用 root 权限运行此安装脚本" "ERROR"
    exit 1
fi

# 检查必要的命令
for cmd in curl crontab; do
    if ! command -v $cmd &> /dev/null; then
        print_msg "错误: 找不到命令 '$cmd'" "ERROR"
        exit 1
    fi
done

# 创建临时目录
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

print_msg "开始安装日志清理工具..." "WARNING"

# 下载脚本
print_msg "正在下载脚本..."
if ! curl -sS "$SCRIPT_URL" -o "$TMP_DIR/log-cleaner.sh"; then
    print_msg "下载脚本失败" "ERROR"
    exit 1
fi

# 验证下载的文件
if [ ! -s "$TMP_DIR/log-cleaner.sh" ]; then
    print_msg "下载的文件为空" "ERROR"
    exit 1
fi

# 安装脚本
print_msg "正在安装脚本..."
mv "$TMP_DIR/log-cleaner.sh" "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

# 添加到 crontab
if ! crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
    print_msg "正在设置定时任务..."
    (crontab -l 2>/dev/null; echo "0 7 * * * $SCRIPT_PATH --quiet") | crontab -
    print_msg "已添加到 crontab，将在每天早上 7 点执行" "SUCCESS"
else
    print_msg "定时任务已存在，跳过添加" "WARNING"
fi

print_msg "\n安装完成！" "SUCCESS"
print_msg "使用方法:"
print_msg "  1. 直接运行：$SCRIPT_NAME"
print_msg "  2. 调试模式：$SCRIPT_NAME --debug"
print_msg "  3. 静默模式：$SCRIPT_NAME --quiet"
print_msg "  4. 查看帮助：$SCRIPT_NAME --help"
print_msg "\n日志文件位置：/var/log/log-cleaner.log"
print_msg "定时任务将在每天早上 7 点自动运行（使用静默模式）"
