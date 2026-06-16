# M6 包管理器完善设计文档

## 1. 概述

M6 包管理器是明道语言的官方包管理工具，参考 Cargo 设计，提供完整的包管理生命周期支持。核心功能包括版本约束、依赖解析、包发布与安装。

### 设计目标

| 目标 | 描述 |
|------|------|
| **Cargo 风格工作流** | init, build, run, test, bench, doc, publish, install, update, add, remove, tree |
| **语义化版本** | SemVer 支持 ^, ~, >= 等版本约束 |
| **Git-based 仓库** | 分散式 Git 仓库作为包源 |
| **贪婪解析算法** | 优先最新兼容版本，类似 Cargo |
| **完整缓存** | 首次下载后完整缓存，支持完全离线开发 |

---

## 2. 项目结构

### 2.1 项目目录结构

```
my-project/
├── Mingdao.toml          # 项目清单
├── Mingdao.lock          # 依赖锁定文件
├── src/                  # 项目源码
│   └── main.mingdao      # 入口文件
├── tests/                # 测试
│   └── test_main.rkt    # 测试文件
└── target/               # 编译输出
    └── debug/            # 调试构建
```

### 2.2 清单文件 (Mingdao.toml)

```toml
[package]
名称 = "my-package"
版本 = "0.1.0"
作者 = "张三 <zhang@example.com>"
描述 = "一个示例包"
许可证 = "MIT"

[dependencies]
utils = { git = "https://gitee.com/mingdao/utils.git", tag = "v1.0.0" }
json = "2.0"
regex = "^1.5"

[dev-dependencies]
test = "1.0"

[features]
default = ["default-feats"]
default-feats = []
advanced = []
```

### 2.3 锁定文件 (Mingdao.lock)

```toml
# 自动生成，不要手动编辑
[metadata]
lock-version = "1"

[[package]]
name = "utils"
version = "2.1.0"
source = { git = "https://gitee.com/mingdao/utils.git", tag = "v2.1.0" }
checksum = "sha256:abc123..."

[[package]]
name = "json"
version = "2.0.5"
source = "registry"
dependencies = []
```

---

## 3. 命令体系

### 3.1 命令列表

| 命令 | 描述 |
|------|------|
| `mingdao-pkg init` | 在当前目录初始化新项目 |
| `mingdao-pkg new <name>` | 创建新包项目 |
| `mingdao-pkg build` | 构建项目 |
| `mingdao-pkg run` | 构建并运行项目 |
| `mingdao-pkg test` | 运行测试 |
| `mingdao-pkg bench` | 运行基准测试 |
| `mingdao-pkg doc` | 生成文档 |
| `mingdao-pkg publish` | 发布包到仓库 |
| `mingdao-pkg install` | 安装包到本地 |
| `mingdao-pkg update` | 更新依赖到最新兼容版本 |
| `mingdao-pkg add <pkg>` | 添加新依赖 |
| `mingdao-pkg remove <pkg>` | 移除依赖 |
| `mingdao-pkg tree` | 显示依赖树 |
| `mingdao-pkg search <keyword>` | 搜索仓库 |
| `mingdao-pkg list` | 列出已安装包 |

### 3.2 命令输出格式

```
# 成功输出
$ mingdao-pkg build
   Compiling my-package v0.1.0
   Finished dev [unoptimized + debuginfo] target(s)

# 错误输出
$ mingdao-pkg build
error: could not compile `my-package`

Caused by:
  process didn't exit successfully: ...

# 依赖树输出
$ mingdao-pkg tree
my-package v0.1.0
├── utils v2.1.0
│   └── logging v1.0.0
└── json v2.0.5
```

---

## 4. 版本约束

### 4.1 语义化版本 (SemVer)

版本格式：`主版本.次版本.补丁版本`

```
1.0.0      # 精确版本
1.0        # 精确版本（补丁为0）
1          # 精确版本（次版本和补丁为0）
```

### 4.2 版本约束运算符

| 约束 | 含义 | 示例 | 展开 |
|------|------|------|------|
| `^` | 兼容版本 | `^1.2.3` | `>=1.2.3, <2.0.0` |
| `~` | 补丁兼容 | `~1.2.3` | `>=1.2.3, <1.3.0` |
| `>=` | 最小版本 | `>=1.0` | `>=1.0.0` |
| `<=` | 最大版本 | `<=2.0` | `<=2.0.0` |
| `>` | 大于 | `>1.0` | `>=1.0.1` |
| `<` | 小于 | `<2.0` | `<2.0.0` |
| `=` | 精确版本 | `=1.2.3` | `1.2.3` |
| `*` | 任意版本 | `*` | 任意 |

### 4.3 Git 源约束

```toml
[dependencies]
# 标签引用
utils = { git = "https://gitee.com/mingdao/utils.git", tag = "v1.0.0" }

# 分支引用
utils = { git = "https://gitee.com/mingdao/utils.git", branch = "main" }

# 提交引用
utils = { git = "https://gitee.com/mingdao/utils.git", rev = "abc123..." }
```

---

## 5. 依赖解析

### 5.1 解析流程

```
1. 解析 Mingdao.toml
   ↓
2. 收集直接依赖 (name + constraint)
   ↓
3. 递归获取传递依赖
   ├─ 从 Cargo.lock 恢复（如存在）
   └─ 从仓库获取
   ↓
4. 贪婪选择算法
   └─ 对每个依赖，选择最新满足约束的版本
   ↓
5. 冲突检测
   ├─ 无冲突 → 生成/更新 Mingdao.lock
   └─ 有冲突 → 回溯重试
   ↓
6. 下载包
   ├─ Git 包: git clone
   ├─ Registry 包: 下载 tarball
   └─ 验证 checksum
   ↓
7. 写入缓存 (~/.mingdao/registry/)
```

### 5.2 贪婪解析算法

```racket
(define (resolve-dependencies deps)
  (let ([resolved (make-hash)]
        [pending (list->queue deps)])
    (while (not (queue-empty? pending))
      (let ([dep (queue-dequeue! pending)])
        (let ([candidates (find-candidates dep)])
          (let ([best (select-best candidates)])
            (hash-set! resolved (dep-name dep) best)
            ;; 添加入队子依赖
            (for-each (lambda (d) (queue-enqueue! pending d))
                      (get-dependencies best)))))))
  resolved)
```

### 5.3 冲突检测

当同一包的不同版本约束无法同时满足时触发：

```
Package A requires: json >= 2.0
Package B requires: json < 2.0
→ 冲突：无法同时满足

解决方案：
1. 尝试降级 A 的 json 版本
2. 尝试升级 B 的 json 版本
3. 报告给用户无法解决
```

---

## 6. Git-based 仓库

### 6.1 仓库目录结构

```
~/.mingdao/
├── registry/              # Registry 包缓存
│   ├── v1/
│   │   ├── index.toml    # 包索引
│   │   └── cache/        # 下载的包
│   │       └── json-2.0.5.tar.gz
├── git/                   # Git 仓库克隆
│   └── gitee.com/
│       └── mingdao/
│           └── utils/
│               ├── HEAD
│               └── objects/
├── cache/                  # 临时下载缓存
└── config.toml            # 全局配置
```

### 6.2 包索引 (index.toml)

```toml
[version]
format = "1"
updated = "2026-06-16T00:00:00Z"

[packages]

[packages.utils]
name = "utils"
description = "常用工具函数库"
repository = "https://gitee.com/mingdao/utils.git"
homepage = "https://mingdao-lang.org/utils"
keywords = ["utility", "tools"]
version = "2.1.0"
download = "https://gitee.com/mingdao/utils/releases/v2.1.0.tar.gz"
checksum = "sha256:abc123..."

[packages.json]
name = "json"
description = "JSON 解析和生成"
version = "2.0.5"
# ... 其他包
```

### 6.3 Git 源处理

```racket
;; 克隆或更新 Git 仓库
(define (fetch-git-source url ref)
  (let ([cache-dir (git-cache-dir url)])
    (if (directory-exists? cache-dir)
        (git-pull cache-dir)
        (git-clone url cache-dir))
    (git-checkout cache-dir ref)))

;; 从 Git 仓库读取包的 Mingdao.toml
(define (get-package-from-git url tag)
  (let ([dir (fetch-git-source url tag)])
    (parse-manifest (build-path dir "Mingdao.toml"))))
```

---

## 7. 离线与缓存策略

### 7.1 完整缓存模式

首次下载后完整缓存，包括：
- 包源码
- Git 仓库克隆
- 解析后的依赖图

### 7.2 离线工作流程

```
在线时:
1. 下载所有依赖
2. 写入缓存
3. 生成 Mingdao.lock

离线时:
1. 检查 Mingdao.lock
2. 从缓存加载依赖
3. 如有缺失，报告错误

缓存更新:
$ mingdao-pkg update --offline  # 使用缓存更新
$ mingdao-pkg update            # 强制刷新缓存
```

### 7.3 缓存管理

```racket
;; 清理缓存
(define (pm-cache-clean)
  (printf "清理包缓存...\n")
  (delete-directory* (cache-dir))
  (printf "缓存已清理\n"))

;; 显示缓存大小
(define (pm-cache-size)
  (let ([size (directory-size (cache-dir))])
    (printf "缓存大小: ~a MB\n" (/ size 1024 1024))))
```

---

## 8. 发布流程

### 8.1 发布前检查

```bash
$ mingdao-pkg publish --dry-run
  Checking package...
  Verifying manifest...
  Building documentation...
  Running tests...
  Packaging...
  Dry run successful!
```

### 8.2 发布步骤

1. 验证 Mingdao.toml 完整性
2. 运行测试
3. 生成文档
4. 打包为 tarball
5. 计算 checksum
6. 更新包索引
7. 推送到 Git 仓库

### 8.3 版本标签

发布时自动创建 Git 标签：

```
v0.1.0     # SemVer 标签
```

---

## 9. 错误处理

### 9.1 错误类型

| 错误码 | 描述 |
|--------|------|
| `E001` | 解析 Mingdao.toml 失败 |
| `E002` | 依赖解析失败 |
| `E003` | 版本冲突无法解决 |
| `E004` | 包不存在 |
| `E005` | Checksum 验证失败 |
| `E006` | Git 操作失败 |
| `E007` | 网络请求失败 |
| `E008` | 权限不足 |

### 9.2 错误输出格式

```
error[E003]: 依赖版本冲突
  │
  ╰─> while checking dependencies
      Package A requires: json >= 3.0
      Package B requires: json < 3.0
      no solution found

help: 你可以尝试:
  1. 更新相关包到兼容版本
  2. 使用 `mingdao-pkg update` 更新依赖
  3. 查看依赖树: `mingdao-pkg tree`
```

---

## 10. 实现计划

### 10.1 文件结构

```
mingdao/tools/pkg/
├── main.rkt              # CLI 入口
├── manifest.rkt           # 清单解析
├── version.rkt           # 版本处理
├── resolver.rkt          # 依赖解析
├── registry.rkt          # 仓库操作
├── cache.rkt            # 缓存管理
├── git-source.rkt        # Git 源处理
├── publisher.rkt         # 发布功能
├── commands/
│   ├── init.rkt
│   ├── new.rkt
│   ├── build.rkt
│   ├── run.rkt
│   ├── test.rkt
│   ├── publish.rkt
│   ├── install.rkt
│   ├── update.rkt
│   ├── add.rkt
│   ├── remove.rkt
│   ├── tree.rkt
│   ├── search.rkt
│   └── list.rkt
└── tests/
    ├── test-manifest.rkt
    ├── test-version.rkt
    ├── test-resolver.rkt
    └── test-commands.rkt
```

### 10.2 核心模块职责

| 模块 | 职责 |
|------|------|
| `main.rkt` | CLI 参数解析，命令分发 |
| `manifest.rkt` | Mingdao.toml 解析和序列化 |
| `version.rkt` | 语义版本解析和比较 |
| `resolver.rkt` | 依赖图构建和版本选择 |
| `registry.rkt` | 包索引和仓库交互 |
| `cache.rkt` | 缓存读写和管理 |
| `git-source.rkt` | Git 仓库操作 |
| `publisher.rkt` | 包发布流程 |

---

## 11. 安全考虑

1. **Checksum 验证**: 所有下载的包验证 SHA256 checksum
2. **HTTPS 优先**: 强制使用 HTTPS 进行网络通信
3. **签名验证**: (未来) 支持 GPG 签名验证
4. **沙箱执行**: 构建过程在隔离环境执行
