@echo off
echo ===== 明道语言（Mingdao）开发环境设置 =====
echo.
echo 步骤1: 安装 Racket（如已安装可跳过）
echo   https://download.racket-lang.org/
echo.
echo 步骤2: 安装明道语言包 ^（使 #lang mingdao 可用^）
echo   cd /d "%~dp0"
echo   raco pkg install --link mingdao/
echo.
echo 步骤3: 验证安装
echo   racket -e ^"(require mingdao/lang/reader)"^
echo.
echo 步骤4: 运行测试
echo   cd /d "%~dp0"
echo   racket mingdao/tests/test-simple.rkt
echo   racket mingdao/tests/test-bootstrap-self.rkt
echo.
echo 安装完成后，您就可以使用 #lang mingdao 编写代码！
pause