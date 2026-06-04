#!/bin/bash
# 明道语言 - 环境配置工具 (Racket 一键安装)
# 支持 Linux (x86_64) 和 macOS (Intel/Apple Silicon)

set -e

print_banner() {
    echo "========================================"
    echo "  明道语言 - 环境配置工具"
    echo "  将自动下载并安装 Racket 9.2"
    echo "========================================"
    echo
}

check_racket() {
    if command -v racket &> /dev/null; then
        local ver=$(racket --version 2>&1)
        echo "[✔] Racket 已安装：$ver"
        echo
        return 0
    fi
    return 1
}

detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        *)          echo "unknown";;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "x86_64";;
        aarch64|arm64) echo "aarch64";;
        *)             echo "unknown";;
    esac
}

download_with_progress() {
    local url="$1"
    local output="$2"
    local desc="$3"
    
    echo "     下载中，请稍候..."
    if command -v curl &> /dev/null; then
        curl -fL --progress-bar -o "$output" "$url" 2>&1 | while IFS= read -r line; do
            case "$line" in
                *[0-9]*) echo -ne "     \r下载进度: $line" ;;
            esac
        done
        echo -ne "\r    下载完成！         \n"
    elif command -v wget &> /dev/null; then
        wget -O "$output" "$url" 2>&1 | tail -1
    else
        echo "    错误：需要 curl 或 wget"
        return 1
    fi
    
    if [ -f "$output" ] && [ -s "$output" ]; then
        local size=$(du -h "$output" | cut -f1)
        echo "     文件大小：$size"
        return 0
    fi
    return 1
}

install_linux() {
    local arch=$(detect_arch)
    local installer=""
    
    case "$arch" in
        x86_64)  installer="racket-9.2-x86_64-linux-buster-cs.sh" ;;
        aarch64) installer="racket-9.2-aarch64-linux-buster-cs.sh" ;;
        *)
            echo "[✘] 不支持的架构：$arch"
            echo "    请访问 https://racket-lang.org 手动下载"
            exit 1
            ;;
    esac
    
    local tuna_url="https://mirrors.tuna.tsinghua.edu.cn/racket-installers/stable/$installer"
    local nju_url="https://mirror.nju.edu.cn/racket-installers/stable/$installer"
    local official_url="https://download.racket-lang.org/releases/9.2/installers/$installer"
    local tmp_dir="/tmp/racket-setup"
    
    mkdir -p "$tmp_dir"
    
    echo "[1/3] 下载 Racket 安装程序..."
    echo

    if download_with_progress "$tuna_url" "$tmp_dir/$installer" "清华镜像源"; then
        echo "     清华镜像源下载成功"
    elif download_with_progress "$nju_url" "$tmp_dir/$installer" "南大镜像源"; then
        echo "     南大镜像源下载成功"
    elif download_with_progress "$official_url" "$tmp_dir/$installer" "官方源"; then
        echo "     官方源下载成功"
    else
        echo "[✘] 所有下载源均失败"
        echo "    请手动下载：$official_url"
        exit 1
    fi
    
    echo
    echo "[2/3] 安装 Racket..."
    chmod +x "$tmp_dir/$installer"
    
    # 安装到 /usr/local/racket (需要 sudo)
    if [ "$(id -u)" -eq 0 ]; then
        sh "$tmp_dir/$installer" --unix-style --dest /usr/local/racket
        local racket_dir="/usr/local/racket"
    else
        echo "     提示：安装到系统目录需要 sudo 权限"
        echo "     将安装到 ~/racket"
        sh "$tmp_dir/$installer" --unix-style --dest "$HOME/racket"
        local racket_dir="$HOME/racket"
    fi
    
    echo
    echo "[3/3] 配置环境变量..."
    
    # 添加到 ~/.bashrc 或 ~/.zshrc
    local rc_file=""
    if [ -f "$HOME/.zshrc" ]; then
        rc_file="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        rc_file="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        rc_file="$HOME/.bash_profile"
    else
        rc_file="$HOME/.profile"
    fi
    
    if ! grep -q "$racket_dir/bin" "$rc_file" 2>/dev/null; then
        echo "" >> "$rc_file"
        echo "# Racket (由明道语言安装脚本添加)" >> "$rc_file"
        echo "export PATH=\"$racket_dir/bin:\$PATH\"" >> "$rc_file"
        echo "[✔] 已将 Racket 添加到 $rc_file"
    fi
    
    # 当前会话也生效
    export PATH="$racket_dir/bin:$PATH"
    
    echo
    echo "========================================"
    echo "  安装完成！"
    echo "========================================"
    echo
    echo "请运行以下命令使环境变量生效："
    echo "  source $rc_file"
    echo
    echo "然后验证安装："
    echo "  racket --version"
    echo
}

install_macos() {
    local arch=$(detect_arch)
    local dmg_file=""
    local app_name="Racket"
    
    case "$arch" in
        x86_64)  dmg_file="racket-9.2-x86_64-macosx-cs.dmg" ;;
        aarch64) dmg_file="racket-9.2-aarch64-macosx-cs.dmg" ;;
        *)
            echo "[✘] 不支持的架构：$arch"
            echo "    请访问 https://racket-lang.org 手动下载"
            exit 1
            ;;
    esac
    
    local tuna_url="https://mirrors.tuna.tsinghua.edu.cn/racket-installers/stable/$dmg_file"
    local nju_url="https://mirror.nju.edu.cn/racket-installers/stable/$dmg_file"
    local official_url="https://download.racket-lang.org/releases/9.2/installers/$dmg_file"
    local tmp_dir="/tmp/racket-setup"
    
    mkdir -p "$tmp_dir"
    
    echo "[1/3] 下载 Racket..."
    echo

    if download_with_progress "$tuna_url" "$tmp_dir/$dmg_file" "清华镜像源"; then
        echo "     清华镜像源下载成功"
    elif download_with_progress "$nju_url" "$tmp_dir/$dmg_file" "南大镜像源"; then
        echo "     南大镜像源下载成功"
    elif download_with_progress "$official_url" "$tmp_dir/$dmg_file" "官方源"; then
        echo "     官方源下载成功"
    else
        echo "[✘] 所有下载源均失败"
        echo "    请手动下载：$official_url"
        exit 1
    fi
    
    echo
    echo "[2/3] 安装 Racket..."
    
    # 挂载 DMG
    local mount_point=$(hdiutil attach "$tmp_dir/$dmg_file" -nobrowse | tail -1 | cut -f3)
    if [ -z "$mount_point" ]; then
        echo "[✘] 挂载 DMG 失败"
        exit 1
    fi
    
    # 复制到 /Applications
    if [ -d "$mount_point/Racket.app" ]; then
        cp -R "$mount_point/Racket.app" /Applications/
        echo "     Racket 已安装到 /Applications/"
    elif [ -d "$mount_point/*.app" ]; then
        cp -R "$mount_point"/*.app /Applications/
        echo "     Racket 已安装到 /Applications/"
    fi
    
    # 卸载 DMG
    hdiutil detach "$mount_point" -quiet
    
    local racket_bin="/Applications/Racket.app/Contents/Resources/racket/bin"
    
    echo
    echo "[3/3] 配置环境变量..."
    
    # 添加到 shell 配置
    local rc_file=""
    if [ -f "$HOME/.zshrc" ]; then
        rc_file="$HOME/.zshrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        rc_file="$HOME/.bash_profile"
    elif [ -f "$HOME/.bashrc" ]; then
        rc_file="$HOME/.bashrc"
    else
        rc_file="$HOME/.profile"
    fi
    
    if ! grep -q "$racket_bin" "$rc_file" 2>/dev/null; then
        echo "" >> "$rc_file"
        echo "# Racket (由明道语言安装脚本添加)" >> "$rc_file"
        echo "export PATH=\"$racket_bin:\$PATH\"" >> "$rc_file"
        echo "[✔] 已将 Racket 添加到 $rc_file"
    fi
    
    export PATH="$racket_bin:$PATH"
    
    echo
    echo "========================================"
    echo "  安装完成！"
    echo "========================================"
    echo
    echo "请运行以下命令使环境变量生效："
    echo "  source $rc_file"
    echo
    echo "然后验证安装："
    echo "  racket --version"
    echo
}

echo
print_banner

if check_racket; then
    echo "启动明道语言："
    echo "  racket mingdao/playground.rkt    (Web Playground)"
    echo "  racket mingdao/repl.rkt          (命令行 REPL)"
    echo
    exit 0
fi

echo "[*] 未检测到 Racket，开始安装..."
echo

os=$(detect_os)
case "$os" in
    linux)
        install_linux
        ;;
    macos)
        install_macos
        ;;
    *)
        echo "[✘] 不支持的操作系统：$(uname -s)"
        echo "    请访问 https://racket-lang.org 手动安装 Racket"
        exit 1
        ;;
esac

# 最终验证
echo
echo "验证安装..."
if command -v racket &> /dev/null; then
    echo "[✔] $(racket --version)"
    echo
    echo "启动明道语言："
    echo "  racket mingdao/playground.rkt    (Web Playground)"
    echo "  racket mingdao/repl.rkt          (命令行 REPL)"
else
    echo "[!] 请重新打开终端后再次运行此脚本验证"
fi
echo