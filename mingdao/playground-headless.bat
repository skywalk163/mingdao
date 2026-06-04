@echo off
REM 明道语言 Playground - Windows无头环境启动脚本

echo ==========================================
echo 明道语言 Playground 正在启动...
echo ==========================================

REM 设置环境变量，避免GUI相关问题
set PLT_DISPLAY_BACKEND=none
set DISPLAY=

echo 环境变量已设置
echo 访问地址: http://localhost:8080
echo.
echo 按 Ctrl+C 停止服务
echo ==========================================
echo.

cd /d "%~dp0"

racket playground.rkt
