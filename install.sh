#!/bin/bash

# 设置安装目录
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="log-cleaner"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# 检查是否具有root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用root权限运行此安装脚本"
        exit 1
    fi
}

# 创建日志清理脚本
create_cleaner_script() {
    cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash

# 设置日志目录
LOG_DIR="/root/logs/cool-admin"

# 获取当前日期和昨天的日期
CURRENT_DATE=$(date +%Y-%m-%d)
YESTERDAY_DATE=$(date -d "yesterday" +%Y-%m-%d)

# Debug模式标志
DEBUG=false

# 帮助信息
usage() {
    echo "Usage: $0 [-d|--debug] [-h|--help]"
    echo "Options:"
    echo "  -d, --debug    Debug模式,只显示要删除的文件,不实际删除"
    echo "  -h, --help     显示帮助信息"
    exit 1
}

# 处理命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "未知参数: $1"
            usage
            ;;
    esac
done

# 检查日志目录是否存在
if [ ! -d "$LOG_DIR" ]; then
    echo "错误: 日志目录 $LOG_DIR 不存在"
    exit 1
fi

# 切换到日志目录
cd "$LOG_DIR" || exit 1

# 清理日志文件的函数
clean_logs() {
    # 查找所有日志文件
    find . -type f -name "*.log.*" | while read -r file; do
        # 提取文件名中的日期部分
        DATE_PART=$(echo "$file" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
        
        # 如果文件名中没有日期部分，跳过
        if [ -z "$DATE_PART" ]; then
            continue
        fi
        
        # 如果日期不是今天也不是昨天，则删除
        if [ "$DATE_PART" != "$CURRENT_DATE" ] && [ "$DATE_PART" != "$YESTERDAY_DATE" ]; then
            if [ "$DEBUG" = true ]; then
                echo "将删除: $file"
            else
                echo "正在删除: $file"
                rm -f "$file"
            fi
        fi
    done
}

# 执行清理
echo "开始清理日志..."
echo "当前日期: $CURRENT_DATE"
echo "保留日期: $CURRENT_DATE 和 $YESTERDAY_DATE"
if [ "$DEBUG" = true ]; then
    echo "Debug模式: 仅显示要删除的文件"
fi

clean_logs

echo "清理完成!"
EOF
}

# 配置crontab
setup_crontab() {
    # 检查是否已存在相同的crontab条目
    if ! crontab -l 2>/dev/null | grep -q "$SCRIPT_NAME"; then
        # 添加新的crontab条目
        (crontab -l 2>/dev/null; echo "0 7 * * * $SCRIPT_PATH") | crontab -
        print_success "已添加到crontab，将在每天早上7点执行"
    else
        print_success "crontab条目已存在，跳过添加"
    fi
}

# 主安装流程
main() {
    # 检查root权限
    check_root

    # 创建脚本
    create_cleaner_script

    # 设置执行权限
    chmod +x "$SCRIPT_PATH"

    # 设置crontab
    setup_crontab

    print_success "安装完成！"
    print_success "您可以通过以下方式使用："
    echo "1. 直接运行: $SCRIPT_NAME"
    echo "2. Debug模式: $SCRIPT_NAME --debug"
    echo "3. 查看帮助: $SCRIPT_NAME --help"
}

# 执行安装
main
