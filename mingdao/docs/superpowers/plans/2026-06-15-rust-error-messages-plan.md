# 明道语言 Rust 级错误消息实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标**: 将 error.rkt 升级为 Rust 级错误消息系统 — 多行上下文、ANSI 颜色终端输出、JSON 结构化输出、错误链（children）、`--explain` 模式。

**架构**: 在现有 error.rkt 结构上扩展字段和输出函数；新建 error-messages.rkt 用于 `--explain` 解释表。两个模块共享同一个 `mingdao-error` 结构。

**技术栈**: Racket (racket/base, racket/match, racket/string, json)

---

## 任务清单

| 任务 | 描述 | 主要文件 |
|------|------|---------|
| 1 | 颜色系统 + 终端检测 | `error.rkt` |
| 2 | 多行上下文 + 精确标记 | `error.rkt` |
| 3 | 彩色格式化输出 | `error.rkt` |
| 4 | JSON 结构化输出 | `error.rkt` |
| 5 | 错误链 API | `error.rkt` |
| 6 | `--explain` 解释表 | `error-messages.rkt` |
| 7 | 验证与测试 | 全部文件 |

---

## 任务 1：颜色系统 + 终端检测

**文件**: `mingdao/lang/error.rkt`（修改，约在文件末尾新增，在 `show-code-line` 函数之后）

**实现步骤**:

- [ ] **步骤 1.1**: 在 require 块添加 `racket/port`
  - 原：`(require racket/format racket/string racket/match)`
  - 新：`(require racket/format racket/string racket/match racket/port racket/system)`
  - 验证：`racket -e "(require \"mingdao/lang/error.rkt\")"`

- [ ] **步骤 1.2**: 在 `type->chinese` 函数之前，添加颜色参数和系统函数
  ```racket
  ;; ============================================================
  ;; ANSI 颜色系统
  ;; ============================================================

  ;; 全局颜色开关（由外部代码设置：命令行参数、LSP 调用等）
  (define color-output-enabled? (make-parameter #t))

  ;; 检测是否支持颜色
  (define (terminal-supports-colors?)
    (and (color-output-enabled?)
         (not (getenv "NO_COLOR"))
         (let ([out (current-output-port)])
           (or (terminal-port? out)
               ;; 回退：检查标准错误是否为终端
               (terminal-port? (current-error-port))))))

  ;; 核心颜色函数
  (define (color code str)
    (if (terminal-supports-colors?)
        (format "\x1b[~am~a\x1b[0m" code str)
        str))

  ;; 便捷颜色函数
  (define (red str)    (color 31 str))
  (define (blue str)   (color 34 str))
  (define (cyan str)   (color 36 str))
  (define (gray str)   (color 90 str))
  (define (yellow str) (color 33 str))
  (define (red-bg str) (color 41 str))

  ;; 默认颜色标签
  (define (error-label str) (red str))
  (define (gutter str)      (gray str))
  (define (hint-label str)  (cyan str))
  ```

- [ ] **步骤 1.3**: 在 provide 列表新增导出
  - 原：`(provide mingdao-error raise-syntax-error expected-error ... error-with-source error-summary)`
  - 新：在列表末尾添加 `color-output-enabled? color red blue cyan gray yellow error-label gutter hint-label`
  - 验证：`racket -e '(require "mingdao/lang/error.rkt") (displayln (red "测试"))'`

**验证清单**:

- [ ] `racket -e '(require "mingdao/lang/error.rkt") (color-output-enabled? #f) (displayln ((if (color-output-enabled?) (λ (x) x) (λ (x) x)) "passed"))'` → 无崩溃
- [ ] `racket -e '(require "mingdao/lang/error.rkt") (displayln (red "test"))'` → 输出正常

---

## 任务 2：多行上下文 + 精确字符标记

**文件**: `mingdao/lang/error.rkt`（修改，替换现有的 `show-code-line` 函数）

**实现步骤**:

- [ ] **步骤 2.1**: 添加新的数据结构（在 `struct mingdao-error` 之后）
  ```racket
  ;; 源位置信息（用于子错误标记）
  (struct source-span (line-start line-end col-start col-end label) #:transparent)
  ```

- [ ] **步骤 2.2**: 在 provide 中新增 `source-span source-span? source-span-line-start source-span-line-end source-span-col-start source-span-col-end source-span-label`

- [ ] **步骤 2.3**: 替换现有的 `show-code-line` 函数（约 297-308 行）为新版本
  ```racket
  ;; 显示多行上下文（错误行 + 上下各 1 行）
  ;; 返回: "line-num │ code\n... │\n... │ ^^^^^^^^ 提示" 格式的字符串
  (define (show-context source-code line col #:context-size [context-size 1] #:label [label #f])
    (define lines (string-split source-code "\n"))
    (define line-count (length lines))
    (when (or (< line 1) (> line line-count))
      (set! line 1))
    (when (or (< col 1) (> col 80))
      (set! col 1))
    (define start (max 0 (- line context-size 1)))
    (define end (min line-count (+ line context-size)))
    (define gutter-width (string-length (number->string end)))

    (define output-parts
      (for/list ([i (in-range start end)])
        (define line-num (+ i 1))
        (define line-str (list-ref lines i))
        (define is-error-line (= line-num line))
        (define gutter (format "~a │" (~r line-num #:min-width gutter-width)))
        (if is-error-line
            (let* ([trimmed-line (if (non-empty-string? line-str) line-str line-str)]
                   [mark-col (min col (max 1 (string-length trimmed-line)))]
                   [spaces (make-string mark-col #\space)]
                   [marks "^^^^^^^^"]
                   [label-part (if label (format " ~a" label) "")])
              (list (format "~a ~a" gutter line-str)
                    (format "~a │ ~a~a~a" (make-string gutter-width #\space) spaces marks label-part)))
            (list (format "~a ~a" gutter line-str)))))
    
    (string-join (flatten output-parts) "\n"))
  ```

- [ ] **步骤 2.4**: 保留简单版 `show-code-line`（向后兼容）
  ```racket
  ;; 单行简易版（向后兼容）
  (define (show-code-line source-code line col)
    (define lines (string-split source-code "\n"))
    (if (and (> (length lines) (sub1 line)) (> line 0))
        (let* ([code-line (list-ref lines (sub1 line))]
               [arrow (make-string (max 0 (sub1 col)) #\space)])
          (string-append code-line "\n" arrow "^── 这里"))
        ""))
  ```

**验证清单**:

- [ ] `racket -e '(require "mingdao/lang/error.rkt") (displayln (show-context "定义 x 就是 1\n定义 y 就是 2\n打印, x 加 y" 2 10 #:label "错误在这里"))'` → 显示多行
- [ ] `racket -e '(require "mingdao/lang/error.rkt") (displayln (show-code-line "定义 x 就是 1" 1 10))'` → 向后兼容，正常工作

---

## 任务 3：彩色格式化输出

**文件**: `mingdao/lang/error.rkt`（修改，在 `format-error-message` 之后新增，保留原函数）

**实现步骤**:

- [ ] **步骤 3.1**: 添加错误代码映射（在 `type->chinese` 之后）
  ```racket
  ;; 错误代码映射（E0001-E9999）
  (define (get-error-code err-type)
    (case err-type
      [(语法错误 期望错误) "E0001"]
      [(类型错误) "E0002"]
      [(未定义错误) "E0003"]
      [(参数错误) "E0004"]
      [(运行时错误) "E0005"]
      [(重复定义错误) "E0006"]
      [(断言错误) "E0007"]
      [(访问错误) "E0008"]
      [else "E9999"]))
  ```

- [ ] **步骤 3.2**: 在 provide 中新增 `get-error-code`

- [ ] **步骤 3.3**: 新增 `format-rust-style` 函数（Rust 风格彩色错误）
  ```racket
  ;; ============================================================
  ;; Rust 风格彩色错误输出
  ;; ============================================================

  ;; 主入口：Rust 风格输出（彩色 + 多行上下文）
  (define (format-rust-style err #:source [source-code #f])
    (define err-type (mingdao-error-type err))
    (define err-msg (mingdao-error-message err))
    (define err-line (or (mingdao-error-line err) 1))
    (define err-col (or (mingdao-error-col err) 1))
    (define err-suggestion (mingdao-error-suggestion err))
    (define err-source (or source-code (mingdao-error-source err)))
    (define err-children (or (mingdao-error-children err) '()))
    (define code (get-error-code err-type))
    (define source-label (or (mingdao-error-source err) (if source-code "<source>" "<unknown>")))

    (string-join
     (append
      (list
       (format "~a [~a] ~a" (error-label "error") code (type->chinese err-type))
       (format " --> ~a:~a:~a" (blue source-label) err-line err-col)
       (format "~a │" (gutter "")))
      (if err-source
          (list (show-context err-source err-line err-col
                               #:label (and err-msg err-msg)))
          '())
      (if err-suggestion
          (list (format " = ~a" (hint-label (format "提示：~a" err-suggestion))))
          '())
      (if (not (empty? err-children))
          (cons " Caused by:"
                (for/list ([child err-children])
                  (format "    [~a] ~a（第 ~a 行）"
                          (get-error-code (mingdao-error-type child))
                          (mingdao-error-message child)
                          (or (mingdao-error-line child) 0))))
          '())
      (list ""))
     "\n"))
  ```

- [ ] **步骤 3.4**: 更新 `mingdao-error` 结构，添加 `children` 字段
  - 原：`(struct mingdao-error (type message line col suggestion source) #:transparent)`
  - 新：`(struct mingdao-error (type message line col suggestion source children) #:transparent)`
  - **⚠️ 重要**：这会导致所有调用 `mingdao-error` 的地方需要更新。所有现有构造函数（raise-syntax-error、expected-error 等）需要传递 `children` 参数（或使用默认值）。

- [ ] **步骤 3.5**: 更新所有现有构造函数以支持 children 字段
  - 更新 `raise-syntax-error`：在最末添加 `'()`
  - 更新 `expected-error`：在最末添加 `'()`
  - 更新 `undefined-error`：在最末添加 `'()`
  - 更新 `raise-argument-error`：在最末添加 `'()`
  - 更新 `raise-runtime-error`：在最末添加 `'()`
  - 更新 `raise-type-error`：在最末添加 `'()`
  - 更新 `type-mismatch-error`：在最末添加 `'()`
  - 更新 `duplicate-definition-error`：在最末添加 `'()`
  - 更新 `assertion-failed-error`：在最末添加 `'()`
  - 更新 `error-with-source`：在最末添加 `'()`

- [ ] **步骤 3.6**: 在 provide 中新增 `format-rust-style`

**验证清单**:

- [ ] `racket -e '(require "mingdao/lang/error.rkt") (displayln (format-rust-style (raise-syntax-error "未闭合的括号" 1 5)))'` → 正常
- [ ] `racket -e '(require "mingdao/lang/error.rkt") (displayln (format-rust-style (raise-type-error "整数" "hello" 3 11) #:source "定义 x 就是 \"hello\"\n打印, x"))'` → 显示多行上下文 + 提示
- [ ] 现有 `format-error-message` 仍可正常调用 → 向后兼容

---

## 任务 4：JSON 结构化输出

**文件**: `mingdao/lang/error.rkt`（新增）

**实现步骤**:

- [ ] **步骤 4.1**: 在 require 中添加 `json` 模块
  - 原：`(require racket/format racket/string racket/match ...)`
  - 新：`(require racket/format racket/string racket/match racket/port json ...)`

- [ ] **步骤 4.2**: 添加错误 → JSON 转换函数
  ```racket
  ;; ============================================================
  ;; JSON 结构化输出（供 IDE/LSP 使用）
  ;; ============================================================

  (define (error->json err #:source [source-code #f])
    (define err-type (mingdao-error-type err))
    (define err-line (or (mingdao-error-line err) 1))
    (define err-col (or (mingdao-error-col err) 1))
    (define err-source (or source-code (mingdao-error-source err)))

    (define main-span
      (hash 'line_start err-line
            'line_end err-line
            'column_start err-col
            'column_end (+ err-col 5)
            'text (if err-source
                      (let* ([lines (string-split err-source "\n")]
                             [idx (sub1 err-line)])
                        (if (and (>= idx 0) (< idx (length lines)))
                            (list-ref lines idx)
                            ""))
                      "")
            'label (mingdao-error-message err)
            'is_primary #t
            'file_name (or (mingdao-error-source err) "main.mingdao")))

    (define (child->json child)
      (hash 'message (mingdao-error-message child)
            'spans (list
                    (hash 'line_start (or (mingdao-error-line child) 1)
                          'line_end (or (mingdao-error-line child) 1)
                          'column_start (or (mingdao-error-col child) 1)
                          'column_end (+ (or (mingdao-error-col child) 1) 3)
                          'text ""
                          'label (mingdao-error-message child)
                          'is_primary #f
                          'file_name "main.mingdao"))))

    (jsexpr->string
     (hasheq 'version 1
             'message (hasheq
                       'type "error"
                       'code (hasheq
                              'code (get-error-code err-type)
                              'explanation (type->chinese err-type))
                       'message (mingdao-error-message err)
                       'spans (list main-span)
                       'children (map child->json (or (mingdao-error-children err) '())))
             'suggestion (or (mingdao-error-suggestion err) ""))))
  ```

- [ ] **步骤 4.3**: 在 provide 中新增 `error->json`

**验证清单**:

- [ ] `racket -e '(require "mingdao/lang/error.rkt") (displayln (error->json (raise-type-error "整数" "hello" 3 11) #:source "定义 x 就是 \"hello\"")))'` → 输出合法 JSON
- [ ] `racket -e '(require "mingdao/lang/error.rkt") (displayln (string-length (error->json (raise-runtime-error "除零" 5 10) #:source "1 除 0"))))'` → 输出正整数

---

## 任务 5：错误链 API

**文件**: `mingdao/lang/error.rkt`（新增，在 `format-rust-style` 之后）

**实现步骤**:

- [ ] **步骤 5.1**: 添加链式错误构造函数
  ```racket
  ;; ============================================================
  ;; 错误链 API（为一个主错误添加子错误）
  ;; ============================================================

  ;; 向错误添加子错误
  (define (add-child-error err child)
    (struct-copy mingdao-error err
                 [children (cons child (or (mingdao-error-children err) '()))]))

  ;; 创建一个含多个子错误的主错误
  (define (make-nested-error main-error sub-errors)
    (struct-copy mingdao-error main-error
                 [children sub-errors]))
  ```

- [ ] **步骤 5.2**: 在 provide 中新增 `add-child-error make-nested-error`

**验证清单**:

- [ ] `racket -e '(require "mingdao/lang/error.rkt") (define e (add-child-error (raise-type-error "整数" "字符串" 3 11) (raise-runtime-error "未初始化" 2 5))) (displayln (format-rust-style e #:source "定义 x 就是 \"hello\"\n定义 y：整数 就是 x\n打印, y")))'` → 显示主错误 + "Caused by"

---

## 任务 6：`--explain` 解释表

**文件**: `mingdao/lang/error-messages.rkt`（新建）

**实现步骤**:

- [ ] **步骤 6.1**: 创建新文件
  ```racket
  #lang racket/base

  ;; 明道语言 `--explain` 错误解释系统
  ;; 提供对每种错误类型的中文详细解释和示例

  (require racket/string
           racket/hash
           "error.rkt")

  (provide error-explanations
           explain-error-code
           all-error-codes)

  ;; ============================================================
  ;; 预定义错误解释表
  ;; ============================================================

  (define error-explanations
    (hash
     "E0001"
     (hasheq
      'title "语法错误"
      'description "这是语法错误，表示代码的结构不符合明道语言的语法规则。请检查括号、引号、缩进是否正确闭合。"
      'bad-example "定义 x 就是 (加 1 2"
      'good-example "定义 x 就是 (加 1 2)"
      'hint "确保所有括号匹配，且使用正确的缩进。")

     "E0002"
     (hasheq
      'title "类型不匹配"
      'description "这是类型不匹配错误，表示变量的类型与期望的类型不一致。明道是静态类型语言，变量的类型在定义时确定，之后不能改变。"
      'bad-example "定义 x 就是 \"hello\"\n定义 y：整数 就是 x"
      'good-example "定义 x 就是 42\n定义 y：整数 就是 x"
      'hint "使用类型转换函数可以转换类型，如 '转整数(x)' 或 '转字符串(x)'。")

     "E0003"
     (hasheq
      'title "未定义错误"
      'description "这是未定义错误，表示引用了一个未声明的变量或函数。请先定义再使用。"
      'bad-example "打印, x   ; x 没有定义过"
      'good-example "定义 x 就是 42\n打印, x"
      'hint "检查变量名是否拼写正确，以及变量是否在正确的作用域内。如果是函数，确保已导入对应的模块。")

     "E0004"
     (hasheq
      'title "参数错误"
      'description "这是参数错误，表示函数调用时传入的参数数量与函数定义不匹配。每个函数接受固定数量的参数。"
      'bad-example "打印, 1, 2, 3   ; 打印只接受 1 个参数"
      'good-example "打印, 1\n打印, 2\n打印, 3"
      'hint "查看函数定义，确认需要几个参数。可在函数名上悬停（在 IDE 中）查看签名。")

     "E0005"
     (hasheq
      'title "运行时错误"
      'description "这是运行时错误，表示程序执行过程中发生了不可预期的状态，如除零、索引越界等。"
      'bad-example "定义 result 就是 10 除 0"
      'good-example "定义 result 就是 10 除 2"
      'hint "检查除数是否可能为零，或列表索引是否超出范围。使用条件判断来规避错误情况。")

     "E0006"
     (hasheq
      'title "重复定义错误"
      'description "这是重复定义错误，表示定义了一个已存在的变量。在同一个作用域内，一个变量名只能定义一次。"
      'bad-example "定义 x 就是 1\n定义 x 就是 2"
      'good-example "定义 x 就是 1\n赋值 x 为 2"
      'hint "如果需要修改值，请使用 '赋值' 语句而不是 '定义' 语句。")

     "E0007"
     (hasheq
      'title "断言错误"
      'description "这是断言错误，表示程序中声明的条件不满足。断言用于调试，确保程序状态符合预期。"
      'bad-example "断言 (大于 0 -1)   ; -1 大于 0 为假"
      'good-example "断言 (大于 0 1)"
      'hint "断言失败表示代码中有 bug。请检查条件表达式是否合理。")

     "E0008"
     (hasheq
      'title "访问权限错误"
      'description "这是访问权限错误，表示尝试访问一个私有符号。使用 '公开' 定义的符号可以跨模块访问，使用 '私有' 定义的符号只能在同一模块内访问。"
      'bad-example "私有 定义 helper 就是 0\n; 其他模块不能访问 helper"
      'good-example "公开 定义 public-fn 就是 0\n; 其他模块可以访问 public-fn"
      'hint "如果需要跨模块访问，请将符号改为 '公开' 修饰。")))

  ;; ============================================================
  ;; explain 主函数
  ;; ============================================================

  (define (explain-error-code code)
    (define info (hash-ref error-explanations code #f))
    (if info
        (string-join
         (list
          (format "~a (~a)" (hash-ref info 'title) code)
          ""
          (hash-ref info 'description)
          ""
          "错误代码示例："
          "--------"
          (hash-ref info 'bad-example)
          "--------"
          ""
          "正确示例："
          "--------"
          (hash-ref info 'good-example)
          "--------"
          ""
          (format "提示：~a" (hash-ref info 'hint))
          "")
         "\n")
        (format "未知错误代码：~a。请检查代码是否正确。\n" code)))

  ;; 获取所有支持的错误代码
  (define (all-error-codes)
    (sort (hash-keys error-explanations) string<?))
  ```

- [ ] **步骤 6.2**: 在 reader.rkt（或任何主入口）中集成
  - 在 require 中添加 `"lang/error-messages.rkt"`
  - 添加 `--explain` 处理分支（可选，由使用者决定）

**验证清单**:

- [ ] `racket -e '(require "mingdao/lang/error-messages.rkt") (displayln (explain-error-code "E0002"))'` → 显示完整的中文解释
- [ ] `racket -e '(require "mingdao/lang/error-messages.rkt") (displayln (explain-error-code "E9999"))'` → 显示"未知错误代码"
- [ ] `racket -e '(require "mingdao/lang/error-messages.rkt") (displayln (all-error-codes))'` → 列出所有 E0001-E0008

---

## 任务 7：验证与测试

**文件**: `mingdao/tests/test-enhancements.rkt` 或新建 `mingdao/tests/test-errors.rkt`

**实现步骤**:

- [ ] **步骤 7.1**: 运行以下验证命令
  ```bash
  cd mingdao && racket -e '(require lang/error.rkt) (displayln "error.rkt OK")'
  cd mingdao && racket -e '(require lang/error-messages.rkt) (displayln "error-messages.rkt OK")'
  ```

- [ ] **步骤 7.2**: 确保 existing tests 无影响
  ```bash
  racket -t tests/test-semantic.rkt
  racket examples/hello.mingdao
  ```

- [ ] **步骤 7.3**: 手动检查输出格式（可选）
  ```racket
  (define test-err (raise-type-error "整数" "字符串" 3 11))
  (displayln (format-rust-style test-err #:source "定义 x 就是 \"hello\"\n打印, x"))
  (newline)
  (displayln (error->json test-err #:source "定义 x 就是 \"hello\""))
  ```

**验收清单**:

- [ ] `error.rkt` 可正常加载（无语法错误）
- [ ] `error-messages.rkt` 可正常加载
- [ ] `format-rust-style` 输出正确格式
- [ ] `error->json` 输出合法 JSON
- [ ] `explain-error-code` 对所有已定义代码返回解释
- [ ] 现有 test-semantic.rkt 全部通过
- [ ] 现有 `format-error-message` 仍可正常工作（向后兼容）

---

## 影响范围总结

| 文件 | 变更 | 验证方式 |
|------|------|---------|
| `mingdao/lang/error.rkt` | **修改**：添加颜色系统、多行上下文、Rust 风格输出、JSON 输出、错误链 API；扩展 `mingdao-error` 结构添加 `children` 字段 | 手动加载测试 + 错误示例 |
| `mingdao/lang/error-messages.rkt` | **新建**：`--explain` 解释表 + API | `racket -e '(require ...)'` |
| 其他文件 | 无修改（向后兼容） | `racket -t tests/test-semantic.rkt` |

**总新增代码量**：约 450 行

**总修改点**：约 12 处（更新所有错误构造函数的 struct 调用）
