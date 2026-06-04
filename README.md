# 明道语言 (Míng Dào)

**明明白白写代码，探索编程之道。**

[![状态](https://img.shields.io/badge/状态-v1.2已发布-brightgreen)](https://github.com)
[![Racket](https://img.shields.io/badge/Racket-8.0+-blue)](https://racket-lang.org/)
[![许可证](https://img.shields.io/badge/许可证-MIT-green)](LICENSE)

## 🎉 最新版本 v1.2 (2026-06-04)

本版本包含以下增强和改进：

- **Socket 模块增强**：新增 UDP 支持、字节/行读写、地址查询、保持连接等功能
- **Threading 模块增强**：新增线程池、并行映射、原子操作、线程本地存储等功能
- **JSON 模块函数别名**：新增更自然的中文函数名（解析json/生成json等）
- **main.rkt 结构优化**：分离运行时代码到独立 runtime.rkt 模块
- **示例和文档完善**：新增 Socket 和 Threading 模块示例，更新 API 文档

详见 [CHANGELOG.md](mingdao/CHANGELOG.md) 了解完整变更记录。

## 名称含义

**明道**：明白编程之道，清晰明了地写代码。

- **明**：明白、清晰、明确
- **道**：编程之道、方法、规律

> "明道若昧，进道若退。" ——《道德经》

明道语言让代码像道一样自然流动，主谓宾语序让程序更符合中文思维。

## 特性

- **双字关键字**：42个核心关键字，全部为双字词，分词无歧义
- **主谓宾语序**：函数调用采用 `参数, 参数, 函数名` 形式，符合中文"把A交给B处理"的表达习惯
- **缩进分块**：Python 风格缩进，无需大括号
- **原生宏系统**：基于 Racket 的卫生宏，代码即数据
- **模块系统**：支持文件的导入与导出，代码复用
- ** DrRacket 插件**：语法高亮支持，提升编码体验
- **Web Playground**：浏览器交互式编程环境，内置示例代码
- **REPL**：命令行交互式编程环境，支持多行输入

## 快速开始

### 🚀 一键安装（新手推荐）

无需手动下载配置，运行脚本自动安装 Racket 环境和明道语言：

**Windows：**
```bat
# 双击 setup.bat，或打开终端运行：
setup.bat
```

**Linux / macOS：**
```bash
# 给予执行权限后运行
chmod +x setup.sh
./setup.sh
```

脚本会自动完成以下操作：
1. 从[清华镜像源](https://mirrors.tuna.tsinghua.edu.cn/racket-installers/stable/)下载 Racket 9.2（国内高速，失败自动切官方源）
2. 静默安装 Racket
3. 配置环境变量（Windows 需以管理员身份运行）

### 手动安装依赖

如果不想使用自动脚本，确保已安装 [Racket](https://racket-lang.org/)（8.0+）。

安装后，建议将 Racket 加入系统 PATH，方便直接使用 `racket` 命令：

**Windows（管理员终端）：**
```bat
setx PATH "E:\Program Files\Racket;%PATH%"
```
> 重启终端后生效。如果 Racket 安装在其他路径，请替换为实际路径。

**Linux / macOS：**
```bash
export PATH="/usr/local/racket/bin:$PATH"
```
> 建议将上面这行添加到 `~/.bashrc` 或 `~/.zshrc` 中永久生效。

### 安装 Web Playground 依赖

Web Playground 需要额外安装 `web-server` 包：

```bash
raco pkg install web-server
```

> 如果 `raco` 不在 PATH 中，Windows 下用 `"E:\Program Files\Racket\raco.exe" pkg install web-server`，Linux/macOS 下用 `/usr/local/racket/bin/raco pkg install web-server`。

**国内加速小贴士：**

`web-server` 包托管在 GitHub 上，国内下载可能较慢。请根据你的网络情况尝试：

1. **耐心等待**：只需安装一次，后续启动 Playground 无需再下载
2. **使用代理**：终端中设置环境变量后再安装：
   ```bash
   # Windows PowerShell
   $env:HTTPS_PROXY="http://127.0.0.1:7890"; raco pkg install web-server
   # Linux / macOS
   HTTPS_PROXY=http://127.0.0.1:7890 raco pkg install web-server
   ```
   （将 `127.0.0.1:7890` 替换为你的代理地址）
3. **使用 GitHub 镜像**：
   ```bash
   raco pkg install --type git https://hub.fastgit.org/racket/web-server.git?path=web-server
   ```
4. **手动安装**：从 [GitHub](https://github.com/racket/web-server) 下载源码，进入目录后执行 `raco pkg install`

### Web Playground（推荐）

一键启动浏览器交互式编程环境：

```bash
racket mingdao/playground.rkt
```

访问 http://localhost:8080 即可在线编写和运行明道代码，内置汉诺塔、斐波那契、冒泡排序、图灵机等示例。

> **💡 关于斐波那契性能优化**：Playground 内置的斐波那契示例默认使用**迭代算法**（而非递归），这是**编码层面的优化**——由程序员选择高效的算法实现，而非语言层面的自动优化。明道语言本身没有改变编译器或解释器行为，它和其他语言一样，将算法选择权交给开发者。你也可以在 Playground 中编写递归版斐波那契来对比性能差异。

### REPL（命令行）

交互式命令行环境，支持多行缩进输入：

```bash
racket mingdao/repl.rkt
```

## 亲身体验

`#lang mingdao` 现已可用！下面三个经典算法全部用明道语言编写，复制到文件，一行命令即可运行。

> **注意**：运行 `#lang mingdao` 文件时，需要添加 `-S` 参数指明语言集合路径

### 🏗️ 汉诺塔（递归经典）

新建文件 `hanoi.rkt`：

```racket
#lang mingdao

定义 汉诺塔 就是函 n, 源, 目标, 辅助：
    如果 n 等于 0 那么：
        返回
    否则：
        汉诺塔, n 减 1, 源, 辅助, 目标
        "从 ", 源, " 移动到 ", 目标, 消息拼接, 打印
        汉诺塔, n 减 1, 辅助, 目标, 源

汉诺塔, 3, "A", "C", "B"
```

```bash
racket -S 项目根目录 hanoi.rkt
```

例如：
```bash
racket -S G:\dumategithub\langbyracket hanoi.rkt
```

**预期输出：**
```
从 A 移动到 C
从 A 移动到 B
从 C 移动到 B
从 A 移动到 C
从 B 移动到 A
从 B 移动到 C
从 A 移动到 C
```

### 🈳 无空格编程（紧凑语法）

明道语言的一个独特设计是**关键字与标识符之间无需空格分隔**。分词器能智能识别双字、三字、四字关键字的边界，无论在关键字和标识符之间加不加空格，都能正确分词。

下面是无空格版本的汉诺塔——关键字、函数名、变量之间完全没有任何空格（实际文件需以 `#lang reader "../lang/reader.rkt"` 开头）：

```明道
#lang reader "../lang/reader.rkt"

定义汉诺塔就是函n,源,目标,辅助：
 如果n等于0那么：
  返回
 否则：
  汉诺塔,(n,减,1),源,辅助,目标
  定义消息就是消息拼接,"从",源,"移动到",目标
  打印,消息
  汉诺塔,(n,减,1),辅助,目标,源

汉诺塔,3,"A","C","B"
```

如上所示：
- `定义汉诺塔就是函` → 正确拆分为 `定义`（关键字）`汉诺塔`（标识符）`就是函`（关键字）
- `如果n等于0那么` → 正确拆分为 `如果`（关键字）`n`（标识符）`等于`（关键字）`0`（数字）`那么`（关键字）
- `(n,减,1)` → 正确解析为 `减` 函数调用 `(减 n 1)`

**运行方式与前面不同**：`.mingdao` 文件使用 `#lang reader`（而非 `#lang mingdao`），**不需要** `-S` 参数。在项目根目录下直接执行：

```bash
racket mingdao\examples\hanoi-nospace.mingdao
```

或在 `mingdao/examples/` 目录下：

```bash
cd mingdao/examples
racket hanoi-nospace.mingdao
```

### 🔵 冒泡排序

新建文件 `bubble.rkt`：

```racket
#lang mingdao

定义 冒泡排序 就是函 arr：
    定义 n 就是 arr, 长度
    对于 i 从 0 到 n 减 1：
        对于 j 从 0 到 n 减 1 减 i：
            如果 arr, j, 索引 大于 arr, j 加 1, 索引 那么：
                定义 当前 就是 索引, arr, j
                定义 下一个 就是 索引, arr, j 加 1
                赋值 arr 为 列表修改, arr, j, 下一个
                赋值 arr 为 列表修改, arr, j 加 1, 当前
    返回 arr

定义 数据 就是 列表 5, 3, 8, 1, 9, 2
数据, 冒泡排序, 打印
```

```bash
racket -S 项目根目录 bubble.rkt
```

**预期输出：**
```
(1 2 3 5 8 9)
```

### ⚙️ 图灵机（二进制加法）

新建文件 `turing.rkt`：

```racket
#lang mingdao

定义 运行 就是函 状态, 纸带, 位置, 规则表：
    定义 当前符号 就是 索引, 纸带, 位置
    如果 当前符号 等于 空值 那么：
        返回 纸带
    定义 索引位置 就是 2 乘 状态 加 当前符号
    定义 规则 就是 索引, 规则表, 索引位置
    如果 规则 等于 空值 那么：
        返回 纸带
    否则：
        定义 写入 就是 索引, 规则, 0
        定义 移动 就是 索引, 规则, 1
        定义 新状态 就是 索引, 规则, 2
        赋值 纸带 为 列表修改, 纸带, 位置, 写入
        如果 移动 等于 1 那么：
            赋值 位置 为 位置 加 1
        否则：
            赋值 位置 为 位置 减 1
        运行, 新状态, 纸带, 位置, 规则表

定义 纸带 就是 列表 1, 0, 1, 0, 0, 1, 1, 0
定义 规则表 就是 列表
    列表 1, 1, 0,
    列表 0, 1, 1,
    列表 1, 1, 1,
    列表 0, 0, 2
"输入纸带：", 打印
纸带, 打印
"结果纸带：", 打印
运行, 0, 纸带, 0, 规则表, 打印
```

```bash
racket -S 项目根目录 turing.rkt
```

**预期输出：**
```
输入纸带： (1 0 1 0 0 1 1 0)
结果纸带： (0 1 0 0 0 1 1 0)
```

解释：输入二进制数 `01001101` 的低 8 位，加 1 后得到 `01001110`。

### 🎯 一键运行全部测试

```bash
racket mingdao\tests\test-algorithms.rkt
```

项目 `mingdao/examples/` 目录下也提供了现成的示例文件：
- `mingdao/examples/bubble-mingdao.rkt`  — 冒泡排序
- `mingdao/examples/hanoi-mingdao.rkt`   — 汉诺塔
- `mingdao/examples/turing-mingdao.rkt`  — 图灵机
- `mingdao/examples/hello.mingdao`          — Hello World
- `mingdao/examples/hanoi-nospace.mingdao`  — 汉诺塔（无空格版）

运行示例：

`.rkt` 文件（使用 `#lang mingdao`），需加 `-S` 参数：
```bash
racket -S 项目根目录 mingdao/examples/hanoi-mingdao.rkt
```

`.mingdao` 文件（使用 `#lang reader`），直接执行：
```bash
racket mingdao/examples/hanoi-nospace.mingdao
```

### 示例程序

```明道
# 变量定义
定义 x 就是 5
x, 打印

# 函数定义
定义 求和 就是函 a, b：
    返回 a 加 b

# 主谓宾语序调用
2, 3, 求和, 打印  # 输出：5

# 条件判断
如果 x 大于 0 那么：
    "正数", 打印
否则：
    "非正数", 打印

# 循环
对于 i 从 0 到 10：
    i, 打印

# 循环控制（跳出/继续）
定义 s 就是 0
当满足 真值 那么：
    赋值 s 为 s 加 1
    如果 s 等于 3 那么：
        继续        # 跳过打印3
    打印, s
    如果 s 等于 5 那么：
        跳出        # 循环结束
# 输出：1 2 4 5
```

## 模块系统（导入/导出）

明道语言支持模块化编程，可以将代码分散到多个文件，通过 `导入` 复用。

### 模块文件示例

`utils.md`：
```明道
定义 say-hello 就是函 名字
  返回 消息拼接 "你好，" 名字 "！"

定义 deck 就是 "世界"
```

### 导入模块

```明道
导入 "utils.md"
打印 say-hello deck    # 输出：你好，世界！
```

`导入` 会自动读取、解析并执行目标文件中所有定义。导入的文件中也可以使用 `导入` 来递归导入其他模块，循环导入会自动跳过已加载的文件。

### 导出语句

```明道
导出 say-hello deck
```

`导出` 用于声明模块的公共接口（当前版本中为文档性标记，所有定义默认对外公开）。

## DrRacket 语法高亮插件

### 安装

方式一：用 `raco` 命令安装
```bash
raco pkg install mingdao/drracket/
```

方式二：手工复制
将 `mingdao/drracket/` 目录复制到 Racket 的 collects 目录下：
- Windows: `%APPDATA%\Racket\9.2\collects\`
- Linux: `~/.local/share/racket/9.2/collects/`
- macOS: `~/Library/Racket/9.2/collects/`

### 颜色方案

| 语法元素 | 颜色 |
|---------|------|
| 控制结构（定义、如果、对于等） | 蓝色 (MediumBlue) |
| 运算符（加、减、乘等） | 紫色 (DarkOrchid) |
| 内置函数（打印、长度等） | 青色 (Teal) |
| 数字 | 深绿 (DarkGreen) |
| 字符串 | 深红 (FireBrick) |
| 注释 | 灰色 (Gray) |

安装后重启 DrRacket，编辑 `.md` 文件即可看到明道语法高亮。

## 自举（Bootstrapping）

明道语言的 Tokenizer 和 Parser 已用明道语言自身实现，能正确解析自身源码，构成完整的自举链条。

### 自举架构

```
┌─────────────────────────────────────────────────────┐
│                    明道源码                           │
│  定义汉诺塔就是函n,源,目标,辅助：                     │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│         Tokenizer（明道自写，std/tokenizer.mingdao）   │
│  字符流 → Token 流                                    │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│          Parser（明道自写，std/parser.mingdao）        │
│  Token 流 → AST（Racket S-表达式）                     │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│            Racket 运行时（eval AST）                   │
└─────────────────────────────────────────────────────┘
```

### 自举验证结果

```bash
racket mingdao/tests/test-bootstrap-self.rkt
```

所有 15 个测试用例（数字字面量、字符串、真值/假值/空值、标识符、变量定义、SVO 函数调用、列表字面量、多行条件语句、无空格定义/调用等）都通过验证——明道版输出与 Racket 版的 **Token 流** 和 **AST 结构** 完全一致。

### 自举版文件

```bash
std/tokenizer.mingdao  # 明道版分词器（约200行）
std/parser.mingdao     # 明道版解析器（约400行）
tests/test-bootstrap-self.rkt  # 自举一致性验证
```

### 运行方式

```bash
# Phase 2: Parser 一致性验证
racket mingdao/tests/test-bootstrap-parser.rkt

# Phase 3: 自举一致性验证（Token+AST）
racket mingdao/tests/test-bootstrap-self.rkt

# 基础库验证
racket mingdao/tests/test-bootstrap-primitives.rkt
```

## 项目结构

```
mingdao/
├── main.rkt           # 语言入口
├── core.rkt           # 核心宏定义（包含自举辅助函数）
├── playground.rkt     # Web Playground 交互式编程环境
├── repl.rkt           # REPL 命令行交互式编程环境
├── std/                          # 明道自举标准库
│   ├── tokenizer.mingdao         # 明道版分词器
│   └── parser.mingdao            # 明道版解析器
├── lang/
│   ├── reader.rkt     # Reader 扩展
│   ├── tokenizer.rkt  # 分词器（Racket版）
│   └── parser.rkt     # 解析器（Racket版）
├── tests/
│   ├── test-simple.rkt                 # 分词器测试
│   ├── test-parser.rkt                 # 解析器测试
│   ├── test-features.rkt               # 功能测试
│   ├── test-macro.rkt                  # 宏系统测试
│   ├── test-macro-run.rkt              # 宏运行测试
│   ├── test-algorithms.rkt             # 算法综合测试
│   ├── test-control.rkt                # 流程控制测试
│   ├── test-break-continue.rkt         # 循环控制测试
│   ├── test-turing.rkt                 # 图灵机测试
│   ├── test-module.rkt                 # 模块系统测试
│   ├── test-module-utils.md            # 模块测试依赖文件
│   ├── test-bootstrap-primitives.rkt   # 自举基础库测试
│   ├── test-bootstrap-tokenizer.rkt    # 明道版分词器测试
│   ├── test-bootstrap-parser.rkt       # 明道版解析器测试
│   └── test-bootstrap-self.rkt         # 自举一致性验证
├── examples/
│   ├── hello.mingdao           # Hello World
│   ├── bubble-mingdao.rkt      # 冒泡排序
│   ├── hanoi-mingdao.rkt       # 汉诺塔
│   └── turing-mingdao.rkt      # 图灵机
└── docs/              # 设计文档
└── drracket/
    ├── info.rkt        # 插件包信息
    └── plugin.rkt     # DrRacket 语法高亮插件
```

## 设计文档

详见 [中文编程语言设计规范.md](docs/中文编程语言设计规范.md)

## 关键字列表

### 定义类（5个）
- `定义` - 变量定义
- `定义宏` - 宏定义
- `就是` - 赋值/等于
- `就是函` - 函数定义
- `就是宏` - 宏定义标记

### 流程控制（12个）
- `如果`、`那么`、`否则`、`否则若` - 条件分支
- `对于`、`从`、`到`、`对于每个` - 循环
- `当满足` - 条件循环（while）
- `跳出`、`继续`、`返回` - 控制跳转

### 数据结构（5个）
- `列表`、`元组`、`字典` - 数据结构
- `索引`、`长度` - 操作

### 比较运算（6个）
- `等于`、`不等`、`大于`、`小于`、`大于等于`、`小于等于`

### 逻辑运算（10个单字）
- `加`、`减`、`乘`、`除`、`模`、`幂` - 算术
- `非`、`与`、`或` - 逻辑
- `拼接` - 字符串

## 实现状态

### 基础功能
- [x] 分词器（双字关键字识别、缩进处理、全角括号支持）
- [x] 解析器（AST 生成、括号表达式支持）
- [x] Reader 扩展（`#lang mingdao` 直接可用）
- [x] 核心宏（运算符映射）
- [x] 主谓宾语序解析
- [x] 算法验证（汉诺塔、冒泡排序、图灵机）
- [x] 否则若（elif）多分支条件
- [x] 当满足（while）条件循环
- [x] 跳出（break）/ 继续（continue）循环控制
- [x] Web Playground（浏览器交互式编程环境）
- [x] REPL（命令行交互式编程环境）
- [x] 宏系统（定义宏、生成、捕获、任意参数、多模式）
- [x] 模块系统（导入、导出）
- [x] DrRacket 插件（语法高亮）

### 自举（Bootstrapping）
- [x] Phase 1：基础库扩充（core.rkt 字符/字符串操作）
- [x] Phase 2：明道版 Parser（std/parser.mingdao）
- [x] Phase 3：自举一致性验证（Token + AST 全一致）

## 许可证

MIT
