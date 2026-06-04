#!/bin/bash
# 明道语言 Playground - 无头环境启动脚本

echo "=========================================="
echo "明道语言 Playground 正在启动..."
echo "=========================================="

# 设置环境变量，避免GUI相关问题
export PLT_DISPLAY_BACKEND=none
export DISPLAY=

# 如果系统有headless选项
# export LIBGL_ALWAYS_SOFTWARE=1

echo "环境变量已设置"
echo "访问地址: http://localhost:8080"
echo ""
echo "如需从其他机器访问，请修改脚本中的端口绑定地址"
echo "按 Ctrl+C 停止服务"
echo "=========================================="
echo ""

cd "$(dirname "$0")" || exit 1

racket playground.rkt
