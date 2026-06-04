#!/bin/bash
# 明道语言 Playground - 无头环境启动脚本
# 使用轻量级版本，无GUI依赖

echo "=========================================="
echo "明道语言 Playground (轻量级版本) 正在启动..."
echo "=========================================="

echo "访问地址: http://localhost:8080"
echo ""
echo "如需从其他机器访问，请修改脚本中的端口绑定地址"
echo "按 Ctrl+C 停止服务"
echo "=========================================="
echo ""

cd "$(dirname "$0")" || exit 1

# 使用轻量级版本，避免GUI依赖
racket playground-light.rkt
