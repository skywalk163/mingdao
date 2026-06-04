@echo off
REM 明道语言 Playground - Windows无头环境启动脚本
REM 使用轻量级版本，无GUI依赖，绑定到 0.0.0.0

echo ==========================================
echo 明道语言 Playground (轻量级版本) 正在启动...
echo ==========================================

REM 获取服务器IP地址
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
    set SERVER_IP=%%a
    goto :got_ip
)
set SERVER_IP=<服务器IP>
:got_ip

echo 本地访问: http://localhost:8080
echo 外部访问: http://%SERVER_IP%:8080
echo.
echo 已绑定到 0.0.0.0，可从其他机器访问
echo 按 Ctrl+C 停止服务
echo ==========================================
echo.

cd /d "%~dp0"

REM 使用轻量级版本，避免GUI依赖
racket playground-light.rkt
