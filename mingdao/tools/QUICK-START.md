# 明道语言生态工具快速入门指南

## 🚀 快速开始

### 1. 安装和设置

#### 系统要求
- Racket 7.0 或更高版本
- VS Code（可选，用于IDE支持）

#### 安装步骤
```bash
# 1. 克隆项目
git clone https://github.com/mingdao-lang/langbyracket.git
cd langbyracket

# 2. 安装Racket依赖
raco pkg install

# 3. 测试工具
racket mingdao/tools/test-tools.rkt
```

### 2. 使用工具

#### 命令行工具
```bash
# 格式化单个文件
racket mingdao/tools/cli.rkt --format examples/hello.mingdao

# 启动调试器
racket mingdao/tools/cli.rkt --debug

# 包管理器
racket mingdao/tools/cli.rkt --package
```

#### 在代码中使用
```racket
#lang racket/base

(require "mingdao/tools/formatter.rkt")

;; 格式化代码字符串
(define my-code "定义 x 就是 1
如果 x > 0 那么
打印 \"正数\"")
(define formatted (format-code my-code))
(displayln formatted)
```

### 3. VS Code 集成

#### 安装VS Code扩展
```bash
cd mingdao/tools/vscode-extension
npm install
npm run compile
# 在VS Code中按F5启动扩展开发主机
```

#### VS Code功能
- **语法高亮**: 自动识别.mingdao文件
- **代码补全**: 输入时自动提示关键字和函数名
- **错误诊断**: 实时显示语法错误
- **代码格式化**: 右键选择"格式化文档"

### 4. LSP服务器

#### 启动LSP服务器
```bash
racket mingdao/tools/lsp/server.rkt
```

#### LSP功能
- 文档同步（打开、变更、关闭）
- 实时诊断
- 代码补全
- 跳转到定义（计划中）

### 5. 调试器使用

#### 基本调试流程
```racket
(require "mingdao/tools/debugger.rkt")

;; 创建调试器实例
(define dbg (make-debugger))

;; 设置断点
(debugger-break dbg 10)  ;; 在第10行设置断点

;; 查看变量
(debugger-set-variable! dbg 'x 42)
(debugger-get-variables dbg)  ;; => '((x . 42))

;; 控制执行
(debugger-continue dbg)  ;; 继续执行
(debugger-step dbg)      ;; 单步执行
```

### 6. 包管理器使用

#### 包管理操作
```racket
(require "mingdao/tools/package-manager.rkt")

;; 安装包
(pm-install "utils" "1.0.0")

;; 列出已安装的包
(pm-list)

;; 搜索包
(pm-search "math")

;; 卸载包
(pm-uninstall "utils")
```

## 📚 进阶使用

### 自定义配置

创建 `.mingdao-config` 文件：
```
formatter:
  indent-size: 2
  use-tabs: false

lsp:
  enabled: true
  log-level: debug
```

### 批量格式化
```racket
(require "mingdao/tools/formatter.rkt")

;; 格式化整个目录
(format-directory "examples/")
```

### 集成到构建流程
```bash
# 在CI/CD中使用
racket mingdao/tools/cli.rkt --format src/
racket mingdao/tools/test-tools.rkt
```

## 🔧 故障排除

### 常见问题

**Q: LSP服务器无法启动**
- 确保Racket已正确安装
- 检查文件路径是否正确
- 查看日志输出

**Q: 格式化工具不工作**
- 确保文件扩展名是.mingdao
- 检查文件权限
- 验证代码语法

**Q: VS Code扩展无法加载**
- 运行 `npm install` 安装依赖
- 检查TypeScript编译是否成功
- 查看VS Code开发者工具中的错误

**Q: 版本不匹配错误**
```
loading code: version mismatch
  expected: "8.18"
  found: "9.2"
```

**解决方法：**

| 方法 | 命令 | 适用场景 |
|------|------|----------|
| **方法1（推荐）** | 删除 `compiled` 目录后重新编译 | 快速解决单个文件问题 |
| **方法2** | `raco make <文件名>` | 重新编译特定文件 |
| **方法3** | `raco setup` | 重新编译所有Racket包 |
| **方法4** | `racket -y` | 自动重新编译已加载的文件 |

**具体操作（推荐）：**

```powershell
# Windows PowerShell
Remove-Item -Recurse -Force mingdao\compiled
cd mingdao
raco make playground.rkt
racket playground.rkt
```

```bash
# Linux/macOS
rm -rf mingdao/compiled
cd mingdao
raco make playground.rkt
racket playground.rkt
```

**Q: 在无头服务器上运行报错**
```
Gtk initialization failed for display ":0"
```

**解决方法：**

使用 `racket -y` 参数自动重新编译：

```bash
cd mingdao
racket -y playground.rkt
```

如果仍然报错，尝试清理编译缓存后重新运行：

```bash
rm -rf mingdao/compiled mingdao/lang/compiled mingdao/core/compiled
cd mingdao
raco make playground.rkt
racket playground.rkt
```

## 📖 更多资源

- **完整文档**: `mingdao/tools/README.md`
- **API参考**: 各工具模块的源代码注释
- **示例代码**: `mingdao/examples/` 目录
- **测试用例**: `mingdao/tests/` 目录

## 💡 提示

1. **性能优化**: 对于大型项目，建议使用增量格式化
2. **团队协作**: 使用统一的配置文件确保代码风格一致
3. **持续集成**: 将工具集成到CI流程中自动化检查

## 🎯 下一步

- 探索更多高级功能
- 参与工具开发
- 提交问题和建议
- 贡献代码和文档

---

**Happy Coding! 🎉**