#!/bin/bash

# 版本信息
VERSION="1.0.1"

# 设置日志目录
LOG_DIR="/root/logs/cool-admin"

# 获取当前日期和昨天的日期
CURRENT_DATE=$(date +%Y-%m-%d)
YESTERDAY_DATE=$(date -d "yesterday" +%Y-%m-%d)

# 模式标志
DEBUG=false
QUIET=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 存储空间统计变量
TOTAL_FREED=0
TOTAL_FREED_HUMAN=""

# 设置日志输出
LOG_FILE="/var/log/log-cleaner.log"

# 创建日志目录（如果不存在）
mkdir -p "$(dirname "$LOG_FILE")"

# 帮助信息
usage() {
    echo -e "${BLUE}日志清理工具 v${VERSION}${NC}

使用方法: 
    $(basename "$0") [选项]

选项:
    -d, --debug        调试模式，只显示要删除的文件，不实际删除
    -q, --quiet        静默模式，不输出详细信息，只记录到日志文件
    -v, --version      显示版本信息
    -h, --help         显示此帮助信息

示例:
    $(basename "$0")              # 正常运行
    $(basename "$0") --debug      # 调试模式运行
    $(basename "$0") --quiet      # 静默模式运行

日志文件位置: ${LOG_FILE}"
    exit 0
}

# 显示版本信息
show_version() {
    echo "v${VERSION}"
    exit 0
}

# 日志记录函数
log_msg() {
    local msg=$1
    local level=${2:-"INFO"}
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # 始终写入日志文件
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
    
    # 非静默模式下同时输出到控制台
    if [ "$QUIET" = false ]; then
        case $level in
            "ERROR")
                echo -e "${RED}$msg${NC}" ;;
            "WARNING")
                echo -e "${YELLOW}$msg${NC}" ;;
            "SUCCESS")
                echo -e "${GREEN}$msg${NC}" ;;
            *)
                echo -e "$msg" ;;
        esac
    fi
}

# 转换字节到人类可读格式（不使用 bc 命令）
human_readable() {
    local bytes=$1
    local divider=1024
    if [ $bytes -lt $divider ]; then
        echo "${bytes}B"
    elif [ $bytes -lt $((divider * divider)) ]; then
        echo "$((bytes / divider))K"
    elif [ $bytes -lt $((divider * divider * divider)) ]; then
        echo "$((bytes / divider / divider))M"
    else
        echo "$((bytes / divider / divider / divider))G"
    fi
}

# 获取服务器存储信息
get_disk_info() {
    local disk_info
    disk_info=$(df -B1 / | tail -n 1)
    local total_space=$(echo "$disk_info" | awk '{print $2}')
    local used_space=$(echo "$disk_info" | awk '{print $3}')
    local free_space=$(echo "$disk_info" | awk '{print $4}')
    local use_percent=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')

    log_msg "服务器存储信息:" "INFO"
    log_msg "├── 总空间: $(human_readable $total_space)" "INFO"
    log_msg "├── 已使用: $(human_readable $used_space) (${use_percent}%)" "INFO"
    log_msg "└── 可用空间: $(human_readable $free_space)" "INFO"
}

# 处理命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug)
            DEBUG=true
            shift ;;
        -q|--quiet)
            QUIET=true
            shift ;;
        -v|--version)
            show_version ;;
        -h|--help)
            usage ;;
        *)
            log_msg "未知参数: $1" "ERROR"
            usage ;;
    esac
done

# 检查日志目录是否存在
if [ ! -d "$LOG_DIR" ]; then
    log_msg "错误: 日志目录 $LOG_DIR 不存在" "ERROR"
    exit 1
fi

# 切换到日志目录
cd "$LOG_DIR" || exit 1

# 获取文件大小的函数
get_file_size() {
    local file="$1"
    local size
    
    # 尝试使用 ls 命令获取文件大小（更可靠的方法）
    size=$(ls -l "$file" 2>/dev/null | awk '{print $5}')
    
    if [ -n "$size" ] && [ "$size" -eq "$size" ] 2>/dev/null; then
        echo "$size"
    else
        echo "0"
    fi
}

# 清理日志文件的函数
clean_logs() {
    local file_count=0
    local start_time=$(date +%s)
    
    log_msg "开始扫描日志文件..." "INFO"
    
    # 查找所有日志文件
    find . -type f -name "*.log.*" | while read -r file; do
        # 提取文件名中的日期部分
        DATE_PART=$(echo "$file" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
        
        # 如果文件名中没有日期部分，跳过
        if [ -z "$DATE_PART" ]; then
            continue
        fi
        
        # 如果日期不是今天也不是昨天，则处理
        if [ "$DATE_PART" != "$CURRENT_DATE" ] && [ "$DATE_PART" != "$YESTERDAY_DATE" ]; then
            # 获取文件大小
            local file_size=$(get_file_size "$file")
            
            if [ "$DEBUG" = true ]; then
                log_msg "将删除: $file ($(human_readable $file_size))" "WARNING"
                TOTAL_FREED=$((TOTAL_FREED + file_size))
                file_count=$((file_count + 1))
            else
                log_msg "正在删除: $file ($(human_readable $file_size))" "SUCCESS"
                rm -f "$file"
                TOTAL_FREED=$((TOTAL_FREED + file_size))
                file_count=$((file_count + 1))
            fi
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    TOTAL_FREED_HUMAN=$(human_readable $TOTAL_FREED)
    
    log_msg "\n清理统计:" "SUCCESS"
    log_msg "├── 处理文件数: ${file_count} 个" "SUCCESS"
    log_msg "├── 释放空间: ${TOTAL_FREED_HUMAN}" "SUCCESS"
    log_msg "└── 耗时: ${duration} 秒" "SUCCESS"
}

# 主程序开始
log_msg "=== 日志清理工具 v${VERSION} 开始运行 ===" "INFO"
log_msg "运行模式: $([ "$DEBUG" = true ] && echo "调试模式" || echo "正常模式")" "INFO"
log_msg "当前日期: $CURRENT_DATE" "INFO"
log_msg "保留日期: $CURRENT_DATE 和 $YESTERDAY_DATE" "INFO"

# 获取清理前的存储状态
log_msg "\n清理前的存储状态:" "INFO"
get_disk_info

# 执行清理
clean_logs

# 获取清理后的存储状态
log_msg "\n清理后的存储状态:" "INFO"
get_disk_info

log_msg "\n=== 日志清理完成 ===" "SUCCESS"
