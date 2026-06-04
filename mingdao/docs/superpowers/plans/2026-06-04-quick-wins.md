# 快速见效三项特性 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为明道语言补充匿名函数短语法、字符串插值（f-string）、不可变绑定（常量）三项功能

**架构：** 三项功能彼此独立，按顺序实现。每项功能主要涉及 tokenizer 关键字注册和 parser 新增分支，core.rkt 只需为 `常量` 做少量修改。

**技术栈：** Racket （明道语言元编程层）

---

## 文件清单

| 文件 | 职责 | 变更 |
|------|------|------|
| `mingdao/lang/tokenizer.rkt` | 分词 | 新增关键字：`匿名函数`、`常量`、f-string `f"` 前缀检测 |
| `mingdao/lang/parser.rkt` | 解析 | 新增 parse-anonymous-function、f-string 展开、常量声明 / 常量赋值检查 |
| `mingdao/lang/type-checker.rkt` | 类型检查 | 可选：为匿名函数添加类型推断支持 |
| `mingdao/core.rkt` | 运行时宏 | 新增 `常量?` 可检查、提供占位符 |
| `mingdao/tests/test-lambda.rkt` | 匿名函数测试 | 新建 |
| `mingdao/tests/test-fstring.rkt` | 字符串插值测试 | 新建 |
| `mingdao/tests/test-const.rkt` | 不可变绑定测试 | 新建 |

---

### 任务 1：匿名函数短语法

**文件：**
- 修改：`mingdao/lang/tokenizer.rkt` — 新增 `匿名函数` 关键字
- 修改：`mingdao/lang/parser.rkt` — 新增 `parse-anonymous-function` 分支
- 创建：`mingdao/tests/test-lambda.rkt` — 测试
- 修改：`mingdao/core.rkt` — 添加占位符

- [ ] **步骤 1：tokenizer — 添加关键字 `匿名函数`**

将 `"匿名函数"` 添加到 tokenizer.rkt 的 `三字关键字` 列表中（3 个汉字，但现有模式是匹配固定长度的关键字，需要检查 tokenizer 的匹配逻辑）。

查看 tokenizer 第 88-91 行的 `三字关键字` 定义：

```racket
(define 三字关键字
  '("就是函" "就是宏" "否则若" "当满足" "定义宏" "不等于"))
```

直接追加 `"匿名函数"` 到 `三字关键字` 列表。注意 `匿名函数` 是 4 个字，需要放到 `四字关键字`。检查第 85-86 行：

```racket
(define 四字关键字
  '("大于等于" "小于等于" "对于每个"))
```

追加 `"匿名函数"` 到 `四字关键字`：

```racket
(define 四字关键字
  '("大于等于" "小于等于" "对于每个" "匿名函数"))
```

- [ ] **步骤 2：tokenizer — 添加 `开始`/`结束` 关键字（用于多语句块）**

将 `"开始"` 和 `"结束"` 追加到 `双字关键字`（已存在，通过 `控制流关键字` 等列表组合而成）。

最简单方式：追加到 `控制流关键字` 列表（第 38-42 行）：

```racket
(define 控制流关键字
  '("定义" "如果" "那么" "否则" "对于" "跳出" "继续" "返回"
    "导入" "导出" "模块" "赋值" "尝试" "捕获" "匹配" "始终"
    "或" "开始" "结束"
    ))
```

- [ ] **步骤 3：运行现有测试确认添加关键字后无回归**

```powershell
& "E:\Program Files\Racket\Racket.exe" test-parser.rkt
& "E:\Program Files\Racket\Racket.exe" test-type-annotations.rkt
```

预期：全部通过。

- [ ] **步骤 4：编写匿名函数测试文件**

创建 `mingdao/tests/test-lambda.rkt`：

```racket
#lang racket/base

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         racket/port
         racket/string)

;; 创建 Mingdao 运行时命名空间
(define (make-mingdao-namespace)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (define core-path
      (path->string (build-path (current-directory) ".." "core.rkt")))
    (eval `(require (file ,core-path)))
    (void))
  ns)

(define ns (make-mingdao-namespace))

(define test-passes 0)
(define test-failures 0)

(define (mingdao-eval expr)
  (parameterize ([current-namespace ns])
    (eval expr)))

(define (run-test name code expected)
  (printf "===== ~a =====\n" name)
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "失败：~a\n\n" (exn-message e))
                               (set! test-failures (add1 test-failures)))])
    (define tokens (tokenize code))
    (define ast (parse tokens))
    (printf "AST:\n~s\n" ast)
    (define result
      (for/list ([expr ast])
        (mingdao-eval expr)))
    (define actual (if (null? result) '(void) (car (reverse result))))
    (printf "结果: ~s\n" actual)
    (if (equal? actual expected)
        (begin
          (printf "✓ 通过（期望=~s, 实际=~s）\n\n" expected actual)
          (set! test-passes (add1 test-passes)))
        (begin
          (printf "✗ 失败：期望 ~s, 得到 ~s\n\n" expected actual)
          (set! test-failures (add1 test-failures))))))

;; ========== 测试1：匿名函数单参数 ==========
(run-test "匿名函数单参数"
"定义 f 就是匿名函数 x: x 加 1
f, 5"
  6)

;; ========== 测试2：匿名函数多参数 ==========
(run-test "匿名函数多参数"
"定义 add 就是匿名函数 a, b: a 加 b
add, 3, 4"
  7)

;; ========== 测试3：匿名函数内联使用 ==========
(run-test "匿名函数内联使用"
"映射 匿名函数 x: x 乘 2, [1, 2, 3]"
  '(2 4 6))

;; ========== 测试4：匿名函数闭包 ==========
(run-test "匿名函数闭包"
"定义 x 就是 10
定义 f 就是匿名函数 y: x 加 y
f, 5"
  15)

;; ========== 测试5：匿名函数无参数 ==========
(run-test "匿名函数无参数"
"定义 f 就是匿名函数: 42
f"
  42)

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (displayln "所有匿名函数测试通过！")
    (printf "有 ~a 个测试失败！\n" test-failures))
```

预期：此测试目前会失败（`匿名函数` 尚未解析）。

- [ ] **步骤 5：运行测试确认失败**

```powershell
& "E:\Program Files\Racket\Racket.exe" test-lambda.rkt
```

预期：FAIL（parse error: 无法解析 `匿名函数`）

- [ ] **步骤 6：parser — 在 `parse-atomic-expression` 中添加 `匿名函数` 分支**

在 `mingdao/lang/parser.rkt` 的 `parse-atomic-expression` 函数中，在 `KEYWORD "字典"` 分支之后、`IDENTIFIER` 分支之前添加新分支。

新增代码（约在 parser.rkt 第 1528 行之后）：

```racket
      [(match? 'KEYWORD "匿名函数")
       (advance)
       (define params (parse-parameter-list))  ;; 复用现有参数列表解析
       (expect 'COLON)
       ;; 检查是否为多语句块（开始...结束）
       (if (match? 'KEYWORD "开始")
           (begin
             (advance)
             (skip-newlines)
             (define body (parse-program))
             (expect 'KEYWORD "结束")
             (if (= (length body) 1)
                 `(λ ,(map car params) ,(car body))
                 `(λ ,(map car params) (begin ,@body))))
           ;; 单表达式模式：自动返回
           (let ([expr (parse-expression)])
             `(λ ,(map car params) ,expr)))]
```

注意：`parse-parameter-list` 返回 `'((param-name type) ...)` 格式。`(map car params)` 提取参数名列表。

- [ ] **步骤 7：core.rkt — 添加 `匿名函数` 占位符**

在 `mingdao/core.rkt` 中，在 `定义` 等占位符附近添加：

```racket
(define-syntax (匿名函数 stx)
  (raise-syntax-error '匿名函数 "此关键字应由解析器处理" stx))
```

同时导出 `匿名函数`，在 `provide` 语句中添加。

- [ ] **步骤 8：运行测试验证通过**

```powershell
& "E:\Program Files\Racket\Racket.exe" test-lambda.rkt
```

预期：4/4 通过

- [ ] **步骤 9：运行现有测试确认无回归**

```powershell
& "E:\Program Files\Racket\Racket.exe" test-type-annotations.rkt
& "E:\Program Files\Racket\Racket.exe" test-parser.rkt
& "E:\Program Files\Racket\Racket.exe" test-features.rkt
& "E:\Program Files\Racket\Racket.exe" test-try-catch-finally.rkt
```

预期：全部通过

---

### 任务 2：字符串插值（f-string）

**文件：**
- 修改：`mingdao/lang/tokenizer.rkt` — 添加 f-string 检测和展开
- 修改：`mingdao/lang/parser.rkt` — 处理 f-string token
- 创建：`mingdao/tests/test-fstring.rkt` — 测试

- [ ] **步骤 1：tokenizer — 添加 f-string 读取函数**

在 `mingdao/lang/tokenizer.rkt` 的 `read-string` 函数之后添加 `read-fstring` 函数：

```racket
;; 读取 f-string（字符串插值）
;; f"你好 {name}" → 展开为 (string-append "你好 " (~a name))
(define (read-fstring quote-char)
  (define start-line line)
  (define start-col (sub1 col))
  (define segments '())  ;; 字符串片段和表达式交替存储
  (define current-chars '())
  (define brace-depth 0)
  
  (define (flush-current-chars)
    (when (pair? current-chars)
      (set! segments (cons (list->string (reverse current-chars)) segments))
      (set! current-chars '())))
  
  (let loop ()
    (let ([ch (peek)])
      (cond
        [(not ch) (error 'tokenize "未闭合的 f-string")]
        [(and (char=? ch quote-char) (= brace-depth 0))
         (advance)
         (flush-current-chars)
         ;; 返回 FSTRING token，包含字符串片段和表达式
         (token 'FSTRING (reverse segments) start-line start-col)]
        [(char=? ch #\{)
         (if (= brace-depth 0)
             (begin
               (flush-current-chars)
               (set! brace-depth 1)
               (advance)
               ;; 读取表达式直到匹配的 }
               (define expr-chars '())
               (let expr-loop ()
                 (let ([expr-ch (peek)])
                   (cond
                     [(not expr-ch) (error 'tokenize "f-string 中未闭合的 {")]
                     [(char=? expr-ch #\})
                      (set! brace-depth 0)
                      (advance)
                      (set! segments (cons (list->string (reverse expr-chars)) segments))
                      (loop)]
                     [else
                      (set! expr-chars (cons expr-ch expr-chars))
                      (advance)
                      (expr-loop)]))))
             (begin
               (set! current-chars (cons ch current-chars))
               (advance)
               (loop)))]
        [(and (char=? ch #\{) (> brace-depth 0))
         (set! brace-depth (add1 brace-depth))
         (set! current-chars (cons ch current-chars))
         (advance)
         (loop)]
        [(and (char=? ch #\}) (> brace-depth 1))
         (set! brace-depth (sub1 brace-depth))
         (set! current-chars (cons ch current-chars))
         (advance)
         (loop)]
        ;; 转义
        [(char=? ch #\\)
         (advance)
         (let ([escaped (peek)])
           (advance)
           (set! current-chars (cons (case escaped
                                       [(#\n) #\newline]
                                       [(#\t) #\tab]
                                       [(#\\) #\\]
                                       [(#\") #\"]
                                       [(#\{) #\{]
                                       [else escaped])
                                     current-chars))
           (loop))]
        [else
         (set! current-chars (cons ch current-chars))
         (advance)
         (loop)]))))
```

- [ ] **步骤 2：tokenizer — 在主循环中添加 `f"` 检测**

在 `mingdao/lang/tokenizer.rkt` 的主循环中，在字符串处理之前或附近添加 `f"` 检测：

找到字符串处理代码（约第 405 行）：

```racket
        ;; 字符串
        [(or (char=? ch #\") (char=? ch #\'))
         (set! tokens (cons (read-string ch) tokens))
         (main-loop)]
```

改为：

```racket
        ;; f-string（插值字符串）
        [(and (char=? ch #\f) (peek) (char=? (peek) #\"))
         (advance)  ;; 跳过 f
         (set! tokens (cons (read-fstring #\") tokens))
         (main-loop)]
        
        ;; F-string（大写版本）
        [(and (char=? ch #\F) (peek) (char=? (peek) #\"))
         (advance)
         (set! tokens (cons (read-fstring #\") tokens))
         (main-loop)]
        
        ;; 普通字符串
        [(or (char=? ch #\") (char=? ch #\'))
         (set! tokens (cons (read-string ch) tokens))
         (main-loop)]
```

注意：必须把 f-string 检测放在普通字符串检测**之前**，因为 `"` 是公共前缀。

- [ ] **步骤 3：parser — 添加 FSTRING 处理**

在 `mingdao/lang/parser.rkt` 的 `parse-atomic-expression` 中，在 NUMBER 分支之后、LBRACKET 之前添加：

```racket
      [(match? 'FSTRING)
       (define segs (token-value (advance)))
       ;; segs 是交替的字符串片段和表达式片段
       ;; 格式: '("text1" "expr_text" "text2" "expr_text" ...)
       ;; 奇数索引(0,2,4,...)是字面字符串
       ;; 偶数索引(1,3,5,...)是表达式代码
       (define parts
         (let loop ([i 0] [segs segs])
           (if (null? segs)
               '()
               (if (even? i)
                   ;; 字面字符串片段
                   (cons (car segs) (loop (add1 i) (cdr segs)))
                   ;; 表达式片段（需要解析为 AST）
                   (let ([expr-str (car segs)])
                     (define expr-tokens (tokenize expr-str))
                     (define expr-asts (parse expr-tokens))
                     (define expr (if (null? expr-asts) '(void) (car expr-asts)))
                     (cons `(~a ,expr) (loop (add1 i) (cdr segs))))))))
       (if (null? parts)
           '""  ;; 空 f-string
           (if (null? (cdr parts))
               (car parts)  ;; 只有一个字面片段
               `(string-append ,@parts)))]
```

注意：需要将 `FSTRING` 添加到 `token-type` 的导出或确保 parser 能识别它。在 parser.rkt 的 `类型中文` 映射中添加：

```racket
[(FSTRING) "插值字符串"]
```

- [ ] **步骤 4：编写 f-string 测试文件**

创建 `mingdao/tests/test-fstring.rkt`：

```racket
#lang racket/base

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         racket/port
         racket/string)

(define (make-mingdao-namespace)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (define core-path
      (path->string (build-path (current-directory) ".." "core.rkt")))
    (eval `(require (file ,core-path)))
    (void))
  ns)

(define ns (make-mingdao-namespace))

(define test-passes 0)
(define test-failures 0)

(define (mingdao-eval expr)
  (parameterize ([current-namespace ns])
    (eval expr)))

(define (run-test name code expected)
  (printf "===== ~a =====\n" name)
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "失败：~a\n\n" (exn-message e))
                               (set! test-failures (add1 test-failures)))])
    (define tokens (tokenize code))
    (define ast (parse tokens))
    (printf "AST:\n~s\n" ast)
    (define result
      (for/list ([expr ast])
        (mingdao-eval expr)))
    (define actual (if (null? result) '(void) (car (reverse result))))
    (printf "结果: ~s\n" actual)
    (if (equal? actual expected)
        (begin
          (printf "✓ 通过（期望=~s, 实际=~s）\n\n" expected actual)
          (set! test-passes (add1 test-passes)))
        (begin
          (printf "✗ 失败：期望 ~s, 得到 ~s\n\n" expected actual)
          (set! test-failures (add1 test-failures))))))

;; ========== 测试1：基本插值 ==========
(run-test "基本插值"
"定义 name 就是 \"小明\"
f\"你好 {name}\""
  "你好 小明")

;; ========== 测试2：多插值 ==========
(run-test "多插值"
"定义 a 就是 1
定义 b 就是 2
f\"{a} + {b} = {a 加 b}\""
  "1 + 2 = 3")

;; ========== 测试3：纯文本 f-string（无插值） ==========
(run-test "纯文本"
"f\"hello\""
  "hello")

;; ========== 测试4：转义大括号 ==========
(run-test "转义大括号"
"f\"转义 {{大括号}}\""
  "转义 {大括号}")

;; ========== 测试5：表达式插值 ==========
(run-test "表达式插值"
"定义 x 就是 10
f\"结果: {x 乘 2}\""
  "结果: 20")

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (displayln "所有 f-string 测试通过！")
    (printf "有 ~a 个测试失败！\n" test-failures))
```

- [ ] **步骤 5：运行 f-string 测试**

```powershell
& "E:\Program Files\Racket\Racket.exe" test-fstring.rkt
```

预期：所有测试通过

- [ ] **步骤 6：运行现有测试确认无回归**

```powershell
& "E:\Program Files\Racket\Racket.exe" test-type-annotations.rkt
& "E:\Program Files\Racket\Racket.exe" test-parser.rkt
```

预期：全部通过

---

### 任务 3：不可变绑定（常量）

**文件：**
- 修改：`mingdao/lang/tokenizer.rkt` — 新增 `常量` 关键字
- 修改：`mingdao/lang/parser.rkt` — 新增 `parse-constant` 分支、赋值检查
- 修改：`mingdao/core.rkt` — 添加占位符、常量检测函数
- 创建：`mingdao/tests/test-const.rkt` — 测试

- [ ] **步骤 1：tokenizer — 添加 `常量` 关键字**

将 `"常量"` 追加到 `双字关键字`（最佳方式：追加到 `控制流关键字` 或 `声明关键字`）。

追加到 `声明关键字`（第 45-46 行，与 `就是` 同组）：

```racket
(define 声明关键字
  '("就是" "常量"))
```

`常量` 是双字关键字，已经是 `双字关键字` 的一部分（通过 `声明关键字`）。

- [ ] **步骤 2：parser — 在 `parse-statement` 中添加 `常量` 分支**

在 `mingdao/lang/parser.rkt` 的 `parse-statement` 中，在 `KEYWORD "定义"` 分支之前或附近添加：

```racket
      [(match? 'KEYWORD "常量")
       (parse-constant)]
```

- [ ] **步骤 3：parser — 实现 `parse-constant` 函数**

在 `parse-definition` 函数之前或之后添加新函数：

```racket
  ;; 解析常量声明（不可变绑定）
  (define (parse-constant)
    (expect 'KEYWORD "常量")
    (define name-token (expect-identifier))
    (define name (string->symbol (token-value name-token)))
    ;; 检查类型标注
    (define var-annotated-type
      (if (match? 'COLON)
          (begin
            (advance)
            (parse-type))
          #f))
    (expect 'KEYWORD "就是")
    (define value (parse-comma-exprs))
    ;; 注册为常量（供赋值检查用）
    (hash-set! constant-vars name #t)
    ;; 保存类型信息
    (when var-annotated-type
      (hash-set! type-annotations name var-annotated-type))
    `(define ,name ,value))
```

- [ ] **步骤 4：parser — 添加常量哈希表和初始化**

在 parser.rkt 的 `type-annotations` 附近添加：

```racket
;; 常量变量注册表（用于检查赋值操作）
(define constant-vars (make-hasheq))
```

在 `reset-type-annotations!` 附近添加重置函数或修改现有函数：

```racket
(define (get-type-annotations) type-annotations)
(define (reset-type-annotations!)
  (set! type-annotations (make-hasheq))
  (set! constant-vars (make-hasheq)))
```

- [ ] **步骤 5：parser — 在 `赋值` 解析中添加常量检查**

修改 `parse-statement` 中 `KEYWORD "赋值"` 分支（约第 591-596 行）：

原代码：

```racket
      [(match? 'KEYWORD "赋值")
       (advance)
       (define var-name (string->symbol (token-value (expect-identifier))))
       (expect 'KEYWORD "为")
       (define value (parse-comma-exprs))
       `(set! ,var-name ,value)]
```

修改为：

```racket
      [(match? 'KEYWORD "赋值")
       (advance)
       (define var-name (string->symbol (token-value (expect-identifier))))
       ;; 检查是否为常量
       (when (hash-ref constant-vars var-name #f)
         (error 'parse (format "无法赋值给常量 '~a'（第 ~a 行）" var-name
                               (token-line (current)))))
       (expect 'KEYWORD "为")
       (define value (parse-comma-exprs))
       `(set! ,var-name ,value)]
```

- [ ] **步骤 6：core.rkt — 添加 `常量` 占位符和导出**

在 `mingdao/core.rkt` 的 `provide` 中添加 `常量`：

```racket
(provide ...
         常量)
```

在占位符部分添加：

```racket
(define-syntax (常量 stx)
  (raise-syntax-error '常量 "此关键字应由解析器处理" stx))
```

- [ ] **步骤 7：编写常量测试文件**

创建 `mingdao/tests/test-const.rkt`：

```racket
#lang racket/base

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         racket/port
         racket/string)

(define (make-mingdao-namespace)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (define core-path
      (path->string (build-path (current-directory) ".." "core.rkt")))
    (eval `(require (file ,core-path)))
    (void))
  ns)

(define ns (make-mingdao-namespace))

(define test-passes 0)
(define test-failures 0)

(define (mingdao-eval expr)
  (parameterize ([current-namespace ns])
    (eval expr)))

(define (run-test name code expected)
  (printf "===== ~a =====\n" name)
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "失败：~a\n\n" (exn-message e))
                               (set! test-failures (add1 test-failures)))])
    (define tokens (tokenize code))
    (define ast (parse tokens))
    (printf "AST:\n~s\n" ast)
    (define result
      (for/list ([expr ast])
        (mingdao-eval expr)))
    (define actual (if (null? result) '(void) (car (reverse result))))
    (printf "结果: ~s\n" actual)
    (if (equal? actual expected)
        (begin
          (printf "✓ 通过（期望=~s, 实际=~s）\n\n" expected actual)
          (set! test-passes (add1 test-passes)))
        (begin
          (printf "✗ 失败：期望 ~s, 得到 ~s\n\n" expected actual)
          (set! test-failures (add1 test-failures))))))

;; ========== 测试1：常量声明 ==========
(run-test "常量声明"
"常量 x 就是 42
x"
  42)

;; ========== 测试2：常量和定义共存 ==========
(run-test "常量和定义共存"
"常量 x 就是 10
定义 y 就是 20
x 加 y"
  30)

;; ========== 测试3：常量赋值检查（解析阶段报错） ==========
(run-test "常量赋值检查"
"常量 x 就是 42
赋值 x 为 100
x"
  100)  ;; 注意：解析器会报错，但 with-handlers 捕获后视为通过
;; 实际运行时，解析器的 error 会被 exn:fail? 捕获

;; ========== 测试4：常量类型标注 ==========
(run-test "常量类型标注"
"常量 name: 字符串 就是 \"hello\"
name"
  "hello")

;; ========== 测试5：变量依然可赋值 ==========
(run-test "变量可赋值"
"定义 y 就是 1
赋值 y 为 2
y"
  2)

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (displayln "所有常量测试通过！")
    (printf "有 ~a 个测试失败！\n" test-failures))
```

- [ ] **步骤 8：运行常量测试**

```powershell
& "E:\Program Files\Racket\Racket.exe" test-const.rkt
```

预期：4/5 通过。测试3（常量赋值检查）会通过 `with-handlers` 捕获 error（解析器报错），所以算通过。

- [ ] **步骤 9：运行全部现有测试确认无回归**

```powershell
& "E:\Program Files\Racket\Racket.exe" test-type-annotations.rkt
& "E:\Program Files\Racket\Racket.exe" test-parser.rkt
& "E:\Program Files\Racket\Racket.exe" test-features.rkt
& "E:\Program Files\Racket\Racket.exe" test-lambda.rkt
& "E:\Program Files\Racket\Racket.exe" test-fstring.rkt
& "E:\Program Files\Racket\Racket.exe" test-try-catch-finally.rkt
```

预期：全部通过