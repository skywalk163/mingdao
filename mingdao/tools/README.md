# 明道语言生态工具

完整的开发工具集，为明道语言提供现代IDE支持。

## 📦 工具列表

### 核心工具
1. **LSP服务器** - Language Server Protocol实现
2. **代码格式化工具** - 自动代码格式化
3. **调试器** - 断点调试和变量查看
4. **包管理器** - 第三方包管理
5. **Playground** - 交互式学习环境

### 辅助工具
6. **VS Code扩展** - IDE集成支持
7. **命令行工具** - CLI接口
8. **配置管理** - 自定义配置支持

## 🚀 快速开始

查看 [快速入门指南](QUICK-START.md) 了解详细使用方法。

### 基本使用

```bash
# 测试所有工具
racket mingdao/tools/test-tools.rkt

# 使用命令行工具
racket mingdao/tools/cli.rkt --format file.mingdao
```

## 📁 文件结构

```
mingdao/tools/
├── README.md              # 本文档
├── QUICK-START.md         # 快速入门指南
├── test-tools.rkt         # 工具测试脚本
├── cli.rkt                # 命令行工具入口
├── config.rkt             # 配置管理
├── formatter.rkt          # 代码格式化工具
├── debugger.rkt           # 调试器
├── package-manager.rkt    # 包管理器
├── lsp/                   # LSP服务器
│   ├── server.rkt         # 服务器主文件
│   ├── transport.rkt      # 通信传输层
│   ├── text-sync.rkt      # 文本同步
│   ├── diagnostics.rkt    # 语法诊断
│   └── completion.rkt     # 代码补全
└── vscode-extension/      # VS Code扩展
    ├── package.json       # 扩展配置
    ├── src/extension.ts   # 扩展代码
    ├── language-configuration.json  # 语言配置
    └── syntaxes/mingdao.tmLanguage.json # 语法高亮
```

## 🔧 工具详情

### 1. LSP服务器

**功能特性:**
- 标准LSP协议实现
- 实时语法诊断
- 代码补全
- 文档同步管理

**使用方法:**
```racket
(require "mingdao/tools/lsp/server.rkt")
(start-lsp-server)
```

### 2. 代码格式化工具

**功能特性:**
- 自动缩进计算
- 统一代码风格
- 文件/目录批量格式化

**API:**
- `format-code` - 格式化代码字符串
- `format-file` - 格式化单个文件
- `format-directory` - 格式化整个目录

### 3. 调试器

**功能特性:**
- 断点设置与管理
- 变量查看与修改
- 执行状态跟踪
- 堆栈访问

**API:**
- `make-debugger` - 创建调试器实例
- `debugger-break` - 设置断点
- `debugger-get-variables` - 查看变量

### 4. 包管理器

**功能特性:**
- 包安装/卸载
- 包搜索
- 已安装包列表
- 包发布

**API:**
- `pm-install` - 安装包
- `pm-uninstall` - 卸载包
- `pm-list` - 列出已安装包
- `pm-search` - 搜索包

### 5. Playground

**功能特性:**
- 交互式代码编辑
- 即时运行和查看结果
- 可中断的求值（支持停止运行）
- 丰富的示例代码库
- 暗色主题UI设计
- 快捷键支持

**使用方法:**
```bash
cd mingdao
racket playground.rkt
# 访问地址: http://localhost:8080
```

**快捷键:**
- `Ctrl+Enter` - 运行代码

**示例代码:**
- Hello World - 入门示例
- 斐波那契 - 递归算法
- 汉诺塔 - 经典递归问题
- 循环 - 控制流程
- 冒泡排序 - 排序算法
- 图灵机 - 计算模型
- 杨辉三角 - 数学规律
- 素数筛 - 质数查找（原始版和优化版）

**文件位置:** [mingdao/playground.rkt](file:///g:/dumategithub/langbyracket/mingdao/playground.rkt)

### 6. VS Code扩展

**功能特性:**
- 语法高亮
- 代码补全
- 错误诊断
- 代码格式化

**安装方法:**
```bash
cd mingdao/tools/vscode-extension
npm install
npm run compile
```

### 6. 命令行工具

**使用方法:**
```bash
racket mingdao/tools/cli.rkt --format file.mingdao
racket mingdao/tools/cli.rkt --debug
racket mingdao/tools/cli.rkt --package
```

### 7. 配置管理

**配置文件:** `.mingdao-config`

**示例配置:**
```
formatter:
  indent-size: 4
  use-tabs: false

lsp:
  enabled: true
  log-level: info
```

## 🎯 使用场景

### 开发环境设置
1. 安装Racket和VS Code
2. 配置VS Code扩展
3. 创建配置文件
4. 开始开发

### 团队协作
1. 使用统一的配置文件
2. 集成到CI/CD流程
3. 自动化代码格式化
4. 统一包管理

### 持续集成
```bash
# CI流程示例
racket mingdao/tools/cli.rkt --format src/
racket mingdao/tools/test-tools.rkt
```

## 📚 文档资源

- [快速入门指南](QUICK-START.md) - 详细使用教程
- [完成总结](../docs/生态工具完成总结.md) - 开发总结
- [API文档](./) - 各工具源代码注释

## ❓ 常见问题解答

### 版本不匹配错误

**问题描述：**
```
loading code: version mismatch
  expected: "8.18"
  found: "9.2"
  in: G:\...\mingdao\compiled\playground_rkt.zo
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

### 无头服务器运行错误

**问题描述：**
```
Gtk initialization failed for display ":0"
```

**解决方法：**

**方法1：使用轻量级版本（推荐）**

```bash
# Linux/macOS
cd mingdao
chmod +x playground-headless.sh
./playground-headless.sh
```

```cmd
REM Windows
cd mingdao
playground-headless.bat
```

**方法2：直接运行轻量级版本**

```bash
cd mingdao
racket playground-light.rkt
```

**方法3：手动设置环境变量（不推荐，可能无效）**

```bash
# Linux/macOS
export PLT_DISPLAY_BACKEND=none
export DISPLAY=
cd mingdao
racket playground.rkt
```

```powershell
# Windows PowerShell
$env:PLT_DISPLAY_BACKEND = "none"
$env:DISPLAY = ""
cd mingdao
racket playground.rkt
```

**说明：**

| 文件 | 说明 |
|------|------|
| `playground.rkt` | 完整版本，使用web-server库，可能有GUI依赖 |
| `playground-light.rkt` | 轻量级版本，纯socket实现，无GUI依赖，适合无头服务器 |
| `playground-headless.sh` | Linux/macOS无头环境启动脚本（使用轻量级版本） |
| `playground-headless.bat` | Windows无头环境启动脚本（使用轻量级版本） |

## 🤝 贡献指南

欢迎贡献代码、报告问题或提出建议！

### 开发指南
1. Fork项目
2. 创建功能分支
3. 编写测试
4. 提交Pull Request

### 代码规范
- 使用Racket代码风格
- 添加详细注释
- 编写测试用例
- 更新文档

## 📝 更新日志

### v0.2.0 (2026-06-04)
- ✅ Playground交互式学习环境
  - 即时代码运行
  - 示例代码库
  - 代码格式化
  - 快捷键支持

### v0.1.0 (2026-06-04)
- ✅ LSP服务器基础架构
- ✅ 代码格式化工具
- ✅ 调试器基础功能
- ✅ 包管理器
- ✅ VS Code扩展
- ✅ 命令行工具
- ✅ 配置管理

## 🔮 未来计划

- 类型感知的代码补全
- 真正的执行控制调试
- 远程包仓库支持
- 更多IDE集成
- 性能优化

## 📄 许可证

MIT License

---

**让明道语言开发更简单！** 🎉