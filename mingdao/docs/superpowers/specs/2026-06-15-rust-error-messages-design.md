# 明道语言 Rust 级错误消息系统设计文档

> **面向 AI 代理的工作者：** 此文档描述了如何将明道语言的错误消息系统升级到 Rust 级别——包含多行上下文代码、ANSI 颜色终端输出、JSON 结构化输出、错误链（children）、以及 `--explain` 解释模式。

**状态**: 已批准
**日期**: 2026-06-15
**目标**: M5 里程碑 — Rust 级错误消息

---

## 一、目标

将当前 `error.rkt` 中的错误消息系统升级为 Rust 级别质量：

| 能力 | 现状 | 目标 |
|------|------|------|
| 代码上下文 | 单行 + 单个 `^─` 箭头 | **多行上下文** + **多字符标记** (`^^^`) |
| 颜色 | 纯文本 | **ANSI 颜色**（自动检测，fallback 纯文本） |
| 结构化输出 | 仅人类可读文本 | **JSON 输出**（供 IDE/工具使用） |
| 错误链 | 无 | **`Caused by:` 链式错误** |
| 提示精度 | 位置到列 | **字符范围标记**，可同时显示多个相关位置 |
| 文档 | 无 | **`--explain` 模式**提供中文深度解释 |

---

## 二、架构决策

### 方案 B: Rust 风格全量（已选定）

1. **多行上下文代码显示** — 错误行 + 上下各 1 行，精确字符位置标记
2. **ANSI 颜色终端输出** — 红色错误、蓝色行号、青色提示，自动检测终端能力
3. **JSON 结构化输出** — 完整的 `error-report` 结构体，支持 LSP/工具链
4. **错误链（children）** — 一个错误可以有多个子错误说明根因
5. **`--explain` 模式** — 对每种错误类型提供中文详细解释和示例

---

## 三、核心设计

### 3.1 数据结构

```racket
;; 扩展现有 mingdao-error 结构
(struct mingdao-error (type        ;; 错误类型（'语法错误 '类型错误 等）
                       message     ;; 错误描述
                       line col    ;; 位置
                       suggestion  ;; 修复建议
                       source      ;; 源代码字符串
                       children)   ;; 子错误列表（新增）
  #:transparent)

;; 新：源位置信息（用于子错误标记）
(struct source-span (line-start    ;; 起始行
                     line-end      ;; 结束行
                     col-start     ;; 起始列
                     col-end       ;; 结束列
                     label)        ;; 标记标签
  #:transparent)

;; 新：JSON 错误报告结构
(struct error-report (code        ;; 错误代码（E0001）
                      type        ;; 错误类型
                      message     ;; 主描述
                      suggestion  ;; 修复建议
                      spans       ;; (listof source-span)
                      children)   ;; (listof error-report)
  #:transparent)
```

### 3.2 输出模式（三个独立函数，共享数据结构）

```racket
;; 1. 纯文本详细报告（默认）
(define (format-error-message err source-code) ...)

;; 2. ANSI 彩色详细报告（终端优先）
(define (format-error-message-colored err source-code) ...)

;; 3. JSON 结构化输出（工具链使用）
(define (error->json err) ...)
```

---

## 四、功能 1 — 多行上下文 + 精确标记

### 目标效果

**之前：**
```
╔══════════════════════════════════════╗
║          明道语言错误提示              ║
╚══════════════════════════════════════╝

错误类型：类型错误
错误位置：第 3 行，第 11 列
错误信息：变量 'x' 的类型不匹配：期望 整数，但得到 字符串
修复建议：可以使用 '转整数(x)' 将字符串转换为整数
相关代码：
  定义 x 就是 "hello"
            ^── 这里
```

**之后：**
```
error [E0002] 类型不匹配
 --> main.mingdao:3:11
  │
2 │ 定义 y：整数 就是 0
3 │ 定义 x 就是 "hello"
  │              ^^^^^^^^ 期望: 整数, 但得到: 字符串
4 │ 打印, x
5 │ 
  = 提示：可以使用 '转整数(x)' 将字符串转换为整数
```

### 实现代码

```racket
;; 显示多行上下文（错误行 + 上下各 1 行）
(define (show-context source-code line col [context-size 1])
  (define lines (string-split source-code "\n"))
  (define line-count (length lines))
  (define start (max 0 (- line context-size 1)))
  (define end (min line-count (+ line context-size)))
  (define gutter-width (string-length (number->string end)))
  
  (define output
    (for/list ([i (in-range start end)])
      (define line-num (+ i 1))
      (define line-str (list-ref lines i))
      (define is-error-line (= line-num line))
      (define gutter (format "~a │" (~r line-num #:min-width gutter-width)))
      (if is-error-line
          (list gutter line-str
                (format-error-mark col (string-length line-str) line))
          (list gutter line-str))))
  
  (string-join (flatten output) "\n"))

;; 格式化错误标记 — 显示 `^^^^^^^^ 标签`
(define (format-error-mark col line-len error-line)
  (define spaces (make-string (sub1 col) #\space))
  (define marks "^^^^^^^^")
  (format "~a │ ~a~a ~a" "" spaces marks label))
```

---

## 五、功能 2 — ANSI 颜色输出

### 颜色方案

| 元素 | 颜色 | ANSI 代码 | 函数 |
|------|------|----------|------|
| 错误类型（error） | 红色 | `\x1b[31m` | `(red str)` |
| 文件名/行号 | 蓝色 | `\x1b[34m` | `(blue str)` |
| 代码行 | 默认 | 无 | — |
| 错误标记（^^^） | 红色背景 | `\x1b[41m` | `(red-bg str)` |
| 提示文字 | 青色 | `\x1b[36m` | `(cyan str)` |
| 边框线（│ ─ ╔ ╗） | 灰色 | `\x1b[90m` | `(gray str)` |
| 重置 | — | `\x1b[0m` | — |

### 颜色系统 API

```racket
;; 全局颜色开关（由外部代码设置：命令行参数、LSP 调用等）
(define color-output-enabled? (make-parameter #t))

;; 检测是否支持颜色
(define (terminal-supports-colors?)
  (and (color-output-enabled?)
       (not (getenv "NO_COLOR"))
       (terminal-port? (current-output-port))))

;; 核心颜色函数
(define (color code str)
  (if (terminal-supports-colors?)
      (format "\x1b[~am~a\x1b[0m" code str)
      str))

(define (red str)    (color 31 str))
(define (blue str)   (color 34 str))
(define (cyan str)   (color 36 str))
(define (gray str)   (color 90 str))
(define (red-bg str) (color 41 str))

;; 彩色格式化入口
(define (format-error-message-colored err source-code)
  (define err-line (mingdao-error-line err))
  (define err-col (mingdao-error-col err))
  (define err-type (mingdao-error-type err))
  (define err-msg (mingdao-error-message err))
  (define err-suggestion (mingdao-error-suggestion err))
  
  (string-append
   (format "~a [~a] ~a" (red "error") (get-error-code err-type) err-type) "\n"
   (format " --> ~a:~a:~a" (blue (if source-code (or (mingdao-error-source err) "main.mingdao") "main.mingdao")) err-line err-col) "\n"
   (format "~a │" (gray "")) "\n"
   (show-context-colored source-code err-line err-col) "\n"
   (if err-suggestion
       (format "~a = ~a" (gray "") (cyan (format "提示：~a" err-suggestion))) "\n"
       "")
   "\n"))
```

### 彩色上下文显示

```racket
(define (show-context-colored source-code line col [context-size 1])
  (define lines (string-split source-code "\n"))
  (define line-count (length lines))
  (define start (max 0 (- line context-size 1)))
  (define end (min line-count (+ line context-size)))
  (define gutter-width (string-length (number->string end)))
  
  (string-join
   (for/list ([i (in-range start end)])
     (define line-num (+ i 1))
     (define line-str (list-ref lines i))
     (define is-error-line (= line-num line))
     (define gutter (blue (format "~a │" (~r line-num #:min-width gutter-width))))
     (if is-error-line
         (string-join
          (list (format "~a ~a" gutter line-str)
                (format "~a ~a~a ~a" 
                        (blue (format "~a │" (make-string gutter-width #\space)))
                        (make-string (sub1 col) #\space)
                        (red "^^^^^^^^")
                        (cyan " 期望: ...")))
          "\n")
         (format "~a ~a" gutter line-str)))
   "\n"))
```

---

## 六、功能 3 — JSON 结构化输出

### 输出格式

```json
{
  "version": 1,
  "message": {
    "type": "error",
    "code": {
      "code": "E0002",
      "explanation": "类型不匹配"
    },
    "message": "变量 'x' 的类型不匹配：期望 整数，但得到 字符串",
    "spans": [
      {
        "byte_start": 42,
        "byte_end": 55,
        "line_start": 3,
        "line_end": 3,
        "column_start": 11,
        "column_end": 18,
        "text": "定义 x 就是 \"hello\"",
        "label": "期望: 整数, 但得到: 字符串",
        "is_primary": true,
        "file_name": "main.mingdao"
      }
    ],
    "children": [
      {
        "message": "变量 'x' 首次定义在第 3 行",
        "spans": [...]
      }
    ]
  },
  "suggestion": "可以使用 '转整数(x)' 将字符串转换为整数",
  "suggested_fix": {
    "old_text": "定义 x 就是 \"hello\"",
    "new_text": "定义 x 就是 转整数(\"hello\")"
  }
}
```

### 实现

```racket
;; 将错误转为 JSON 哈希
(define (error->json err [source-code #f])
  (define err-type (mingdao-error-type err))
  (hasheq
   'version 1
   'message (hasheq
             'type "error"
             'code (hasheq
                    'code (get-error-code err-type)
                    'explanation (error-type->chinese err-type))
             'message (mingdao-error-message err)
             'spans (list (error-to-span err source-code))
             'children (map error->json (mingdao-error-children err)))
   'suggestion (or (mingdao-error-suggestion err) null)))

;; 错误代码映射（E0001-E9999）
(define (get-error-code err-type)
  (case err-type
    [(语法错误) "E0001"]
    [(类型错误) "E0002"]
    [(未定义错误) "E0003"]
    [(参数错误) "E0004"]
    [(运行时错误) "E0005"]
    [(重复定义错误) "E0006"]
    [(断言错误) "E0007"]
    [(访问错误) "E0008"]
    [else "E9999"]))
```

---

## 七、功能 4 — 错误链（Children）

### 使用场景

一个错误可能由多个子问题共同导致，或一个错误导致了后续错误。

```racket
;; 创建带错误链的错误
(define (raise-nested-error main-msg sub-errors)
  (mingdao-error '复合错误 main-msg 0 0 null null
                  sub-errors))  ;; sub-errors = (listof mingdao-error)

;; 实际使用示例
(define main-error
  (raise-runtime-error "计算失败：除零错误" 5 10))

(define sub-error
  (raise-runtime-error "此错误导致后续表达式失败" 5 12))

;; 完整错误
(define full-error
  (struct-copy mingdao-error main-error
               [children (list sub-error)]))
```

### 输出效果（终端）

```
error [E0005] 运行时错误
 --> main.mingdao:5:10
  │
5 │ 定义 result 就是 10 除 0
  │                   ^^^^^^ 除零错误
  │
  = Caused by:
      [E0005] 此错误导致后续表达式失败（第 5 行）
```

---

## 八、功能 5 — `--explain` 解释模式

### 预定义错误解释表

```racket
(define error-explanations
  (hash
   "E0001"
   (hasheq
    'title "语法错误"
    'description "这是语法错误，表示代码的结构不符合明道语言的语法规则。请检查括号、引号、缩进是否正确闭合。"
    'bad-example "定义 x 就是 (加 1 2"
    'good-example "定义 x 就是 (加 1 2)"
    'hint "确保所有括号匹配，且使用正确的缩进")

   "E0002"
   (hasheq
    'title "类型不匹配"
    'description "这是类型不匹配错误，表示变量的类型与期望的类型不一致。明道是静态类型语言，变量的类型在定义时确定，之后不能改变。"
    'bad-example "定义 x 就是 \"hello\"\n定义 y：整数 就是 x"
    'good-example "定义 x 就是 42\n定义 y：整数 就是 x"
    'hint "使用类型转换函数可以转换类型，如 '转整数(x)'")

   "E0003"
   (hasheq
    'title "未定义错误"
    'description "这是未定义错误，表示引用了一个未声明的变量或函数。请先定义再使用。"
    'bad-example "打印, x   ' x 没有定义过"
    'good-example "定义 x 就是 42\n打印, x"
    'hint "检查变量名是否拼写正确，是否在正确的作用域内")

   "E0004"
   (hasheq
    'title "参数错误"
    'description "这是参数错误，表示函数调用时传入的参数数量与函数定义不匹配。"
    'bad-example "打印, 1, 2, 3   ' 打印只接受 1 个参数"
    'good-example "打印, 1"
    'hint "查看函数定义，确认需要几个参数")

   "E0005"
   (hasheq
    'title "运行时错误"
    'description "这是运行时错误，表示程序执行过程中发生了不可预期的状态，如除零、索引越界等。"
    'bad-example "定义 result 就是 10 除 0"
    'good-example "定义 result 就是 10 除 2"
    'hint "检查除数是否可能为零，或列表索引是否超出范围")

   "E0006"
   (hasheq
    'title "重复定义错误"
    'description "这是重复定义错误，表示定义了一个已存在的变量。"
    'bad-example "定义 x 就是 1\n定义 x 就是 2"
    'good-example "定义 x 就是 1\n赋值 x 为 2"
    'hint "如果需要修改值，请使用 '赋值' 而非 '定义'")

   "E0007"
   (hasheq
    'title "断言错误"
    'description "这是断言错误，表示程序中声明的条件不满足。断言用于调试，确保程序状态符合预期。"
    'bad-example "断言 (大于 0 -1)   ' -1 大于 0 为假"
    'good-example "断言 (大于 0 1)"
    'hint "断言失败表示代码中有 bug，请检查条件是否合理")

   "E0008"
   (hasheq
    'title "访问权限错误"
    'description "这是访问权限错误，表示尝试访问一个私有符号。使用 '公开' 定义的符号可以跨模块访问，使用 '私有' 定义的符号只能在同一模块内访问。"
    'bad-example "私有 定义 helper 就是 0\n' 其他模块不能访问 helper"
    'good-example "公开 定义 public-fn 就是 0\n' 其他模块可以访问 public-fn"
    'hint "如果需要跨模块访问，将符号改为 '公开' 修饰"))
```

### `--explain` API

```racket
(define (explain-error-code code)
  (define info (hash-ref error-explanations code #f))
  (if info
      (string-join
       (list
        (format "~a (~a)" (hash-ref info 'title) (red code))
        ""
        (hash-ref info 'description)
        ""
        (format "错误代码示例：")
        "--------"
        (hash-ref info 'bad-example)
        "--------"
        ""
        (format "正确示例：")
        "--------"
        (hash-ref info 'good-example)
        "--------"
        ""
        (format "~a: ~a" (cyan "提示") (hash-ref info 'hint))
        "")
       "\n")
      (format "未知错误代码：~a。请检查代码是否正确。" code)))
```

### 命令行调用示例

```
$ 明道 --explain E0002

类型不匹配 (E0002)

这是类型不匹配错误，表示变量的类型与期望的类型不一致。明道是静态类型语言，变量的类型在定义时确定，之后不能改变。

错误代码示例：
--------
定义 x 就是 "hello"
定义 y：整数 就是 x   ' 类型不匹配！
--------

正确示例：
--------
定义 x 就是 42
定义 y：整数 就是 x   ' 类型一致
--------

提示：使用类型转换函数可以转换类型，如 '转整数(x)'
```

---

## 九、影响范围

### 9.1 新建文件

| 文件 | 行数 | 职责 |
|------|------|------|
| `mingdao/lang/error-messages.rkt` | ~150 行 | `--explain` 错误解释表 + 输出函数 |

### 9.2 修改文件

| 文件 | 行数变化 | 改动 |
|------|---------|------|
| `mingdao/lang/error.rkt` | +200 行 | 新增多行上下文、ANSI 颜色、JSON 输出、错误链、`show-context`、`format-error-mark`、`color` 等函数；`format-error-message` 重写为彩色版本 |

### 9.3 无需修改

| 文件 | 原因 |
|------|------|
| `mingdao/lang/reader.rkt` | 已使用 error.rkt，无需改动 |
| `mingdao/lang/semantic.rkt` | 已使用 error.rkt 结构 |
| `mingdao/tools/lsp/...` | LSP 模块在后续里程碑接入 |

---

## 十、扩展方向（未来）

- **LSP 集成** — 将 `error->json` 直接用于 LSP `textDocument/publishDiagnostics`
- **代码动作** — 使用 `suggested_fix` 提供 IDE 级别的自动修复
- **多种错误格式** — JSON 输出的 `--error-format=json` 命令行选项
- **错误代码文档站** — 自动生成所有 E0001-E9999 的中文文档网站
