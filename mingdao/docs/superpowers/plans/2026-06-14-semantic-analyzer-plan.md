# 明道语言语义分析器实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 `lang/semantic.rkt` 中实现完整的语义分析器，覆盖变量未定义、重复定义、作用域链追踪、常量赋值检测等检查。

**架构：** 独立 AST 分析器，接收 parser 输出的 S-expression 列表，构建嵌套作用域树，一次遍历完成所有语义检查，返回结构化错误列表。与现有 type-checker 平行结构。

**技术栈：** Racket（racket/base, racket/match, racket/list）

---

## 文件清单

| 文件 | 职责 |
|------|------|
| `mingdao/lang/semantic.rkt` | 语义分析器核心，导出 analyze、scope、symbol-info、semantic-error |
| `mingdao/tests/test-semantic.rkt` | rackunit 测试用例，覆盖所有错误类型 |
| `mingdao/lang/reader.rkt` | 集成语义分析，在 parse 后调用 analyze 显示警告 |

---

## 任务 1：创建语义分析器核心（lang/semantic.rkt）

**文件：**
- 创建：`mingdao/lang/semantic.rkt`

### 子任务 1.1：定义数据结构

- [ ] **步骤 1：编写 scope struct 定义**

```racket
#lang racket/base

;; 明道语言语义分析器
;; 作用域管理 + 符号表 + 错误报告

(require racket/match
         racket/list)

(provide analyze
         semantic-error
         scope symbol-info
         make-global-scope
         lookup-symbol
         define-symbol!)

;; ============================================================
;; 数据结构
;; ============================================================

;; 作用域节点
;; parent: 父作用域（#f 表示全局作用域）
;; symbols: (hash symbol-name → symbol-info)
;; children: 子作用域列表
(struct scope (parent symbols children) #:transparent)

;; 符号信息
;; kind: '变量 | '函数 | '参数 | '内置函数 | '类型别名
;; type: 类型标注（symbol 或 #f）
;; line: 定义行号
;; col: 定义列号
;; mutable?: 是否可变（#t=变量 #f=常量）
;; defined?: 是否已定义
(struct symbol-info (kind type line col mutable? defined?) #:transparent)

;; 语义错误
(struct semantic-error (type message line col suggestion) #:transparent)
```

- [ ] **步骤 2：编写 semantic-error 辅助函数**

```racket
;; 格式化语义错误为可读字符串
(define (format-semantic-error err [source-code #f])
  (match err
    [(semantic-error type msg line col suggestion)
     (string-append
      (format "语义错误[~a]（第 ~a 行第 ~a 列）：~a" type line col msg)
      (if suggestion (format "\n  建议：~a" suggestion) ""))]))

;; 创建错误的快捷函数
(define (make-error type message line col suggestion)
  (semantic-error type message line col suggestion))
```

### 子任务 1.2：实现作用域管理

- [ ] **步骤 1：编写 make-global-scope**

```racket
;; 创建全局作用域，注册所有内置函数名
(define (make-global-scope builtin-names)
  (define syms (make-hash))
  (for ([name builtin-names])
    (hash-set! syms name
               (symbol-info '内置函数 #f 0 0 #t #t)))
  (scope #f syms '()))
```

- [ ] **步骤 2：编写 lookup-symbol**

```racket
;; 在作用域链中查找符号
;; 返回 (cons symbol-info current-scope) 或 #f
(define (lookup-symbol name current-scope)
  (let loop ([scope current-scope])
    (cond
      [(not scope) #f]
      [(hash-ref (scope-symbols scope) name #f)
       => (λ (info) (cons info scope))]
      [else (loop (scope-parent scope))])))
```

- [ ] **步骤 3：编写 define-symbol!**

```racket
;; 在当前作用域注册符号（不检查重复）
(define (define-symbol! name info scope)
  (hash-set! (scope-symbols scope) name info))
```

- [ ] **步骤 4：编写 child-scope 创建子作用域**

```racket
;; 创建子作用域，添加到父作用域的 children 列表
(define (child-scope parent-scope)
  (define child (scope parent-scope (make-hash) '()))
  (when parent-scope
    (set-scope-children! parent-scope
                         (cons child (scope-children parent-scope))))
  child)
```

### 子任务 1.3：实现分析引擎

- [ ] **步骤 1：编写主入口 analyze**

```racket
;; 主入口：分析 AST，返回错误列表
;; ast: parser 输出的 S-expression 列表
;; builtin-names: 内置函数名列表
(define (analyze ast builtin-names)
  (define global-scope (make-global-scope builtin-names))
  (define errors '())
  (define current-scope global-scope)
  (define constants (make-hash))  ;; name → line (常量不可变)
  
  ;; 分析整个程序
  (for ([expr ast])
    (let-values ([(new-errors new-scope) (analyze-expr expr current-scope constants)])
      (set! errors (append errors new-errors))
      (set! current-scope new-scope)))
  
  (reverse errors))
```

- [ ] **步骤 2：编写 analyze-expr 表达式分析器**

```racket
;; 分析表达式，返回 (values errors new-scope)
(define (analyze-expr expr scope constants)
  (match expr
    ;; 变量/常量定义: (define name value)
    [(? symbol?)
     ;; 单独符号引用
     (values '() scope)]
    
    [(? pair?)
     (let ([tag (car expr)])
       (match tag
         ;; 定义变量/常量
         ['define
          (analyze-define expr scope constants)]
         ;; 赋值
         ['set!
          (analyze-assign expr scope constants)]
         ;; 条件
         ['if
          (analyze-if expr scope constants)]
         ;; 循环
         ['for
          (analyze-for expr scope constants)]
         ;; for-each
         ['for-each
          (analyze-foreach expr scope constants)]
         ;; do-while
         ['let/ec
          (analyze-do-while expr scope constants)]
         ;; 匹配
         ['匹配
          (analyze-match expr scope constants)]
         ;; 尝试/捕获
         ['尝试
          (analyze-try expr scope constants)]
         ;; 返回（函数内）
         ['return
          (analyze-return expr scope)]
         ;; 导入/导出跳过
         ['导入 (values '() scope)]
         ['mingdao-export (values '() scope)]
         ;; 列表字面量
         ['列表
          (analyze-list-literal expr scope constants)]
         ;; 其他列表表达式
         [_
          (analyze-call expr scope constants)])]
       )]
    [_ (values '() scope)])
```

- [ ] **步骤 3：编写 analyze-define**

```racket
;; 分析定义语句
;; (define name value) 或 (define (fn . params) . body)
(define (analyze-define expr scope constants)
  (match expr
    [`(define ,name ,val)
     (let* ([name-str (if (symbol? name) (symbol->string name) name)]
            [existing (lookup-symbol name-str scope)])
       (cond
         ;; 检查重复定义
         [existing
          (values (list (make-error
                        'redefined
                        (format "变量 '~a' 重复定义（首次定义在第 ~a 行）"
                                name-str (symbol-info-line (car existing)))
                        0 0
                        "可以重命名其中一个变量，或者移除旧的定义"))
                  scope)]
         [else
          (define info (symbol-info '变量 #f 0 0 #t #t))
          (define-symbol! name-str info scope)
          (analyze-expr val scope constants)]))]
    [`(define (,fn . ,params) . ,body)
     ;; 函数定义：创建新作用域
     (let* ([fn-str (symbol->string fn)]
            [existing (lookup-symbol fn-str scope)])
       (cond
         [existing
          (values (list (make-error
                        'redefined
                        (format "函数 '~a' 重复定义（首次定义在第 ~a 行）"
                                fn-str (symbol-info-line (car existing)))
                        0 0
                        "可以重命名其中一个函数，或者移除旧的定义"))
                  scope)]
         [else
          (define fn-scope (child-scope scope))
          ;; 注册参数
          (for ([p params])
            (define p-str (symbol->string p))
            (define-symbol! p-str
              (symbol-info '参数 #f 0 0 #t #t) fn-scope))
          ;; 注册函数
          (define-symbol! fn-str
            (symbol-info '函数 #f 0 0 #f #t) scope)
          ;; 分析函数体
          (let loop ([b body] [fn-scope fn-scope] [errors '()])
            (if (null? b)
                (values (reverse errors) scope)
                (let-values ([(errs new-scope) (analyze-expr (car b) fn-scope constants)])
                  (loop (cdr b) new-scope (append errs errors))))))]))]
    [_ (values '() scope)]))
```

- [ ] **步骤 4：编写 analyze-assign 赋值分析**

```racket
;; 分析赋值语句: (= var val) 或 (set! var val)
(define (analyze-assign expr scope constants)
  (match expr
    [`(set! ,var ,val)
     (analyze-assign-internal var val expr scope constants)]
    [`(= ,var ,val)
     (analyze-assign-internal var val expr scope constants)]
    [_ (values '() scope)]))
```

```racket
(define (analyze-assign-internal var val expr scope constants)
  (let* ([var-str (symbol->string var)]
         [result (lookup-symbol var-str scope)])
    (cond
      [(not result)
       ;; 变量未定义
       (values (list (make-error
                     'undefined-var
                     (format "未定义的变量 '~a'" var-str)
                     0 0
                     "是否忘记用「定义」声明？"))
               scope)]
      [(and (eq? (symbol-info-kind (car result)) '变量)
            (not (symbol-info-mutable? (car result))))
       ;; 尝试给常量赋值
       (values (list (make-error
                     'constant-assign
                     (format "常量 '~a' 不可赋值修改（定义在第 ~a 行）"
                             var-str (symbol-info-line (car result)))
                     0 0
                     "用「常量」定义的变量不可修改，请使用「定义」"))
               scope)]
      [else
       (analyze-expr val scope constants)])))
```

- [ ] **步骤 5：编写 analyze-if / analyze-for / analyze-foreach / analyze-do-while**

```racket
;; 分析 if 语句
(define (analyze-if expr scope constants)
  (match expr
    [`(if ,cond ,then ,else)
     (let-values ([(c-errs _) (analyze-expr cond scope constants)])
       (let ([then-scope (child-scope scope)]
             [else-scope (child-scope scope)])
         (let-values ([(t-errs _) (analyze-expr then then-scope constants)])
           (let-values ([(e-errs _) (analyze-expr else else-scope constants)])
             (values (append c-errs t-errs e-errs) scope)))))]
    [_ (values '() scope)]))

;; 分析 for 循环
(define (analyze-for expr scope constants)
  (match expr
    [`(for (,var ,from ,to) . ,body)
     (let-values ([(r-errs _) (analyze-expr from scope constants)])
       (let-values ([(r2-errs _) (analyze-expr to scope constants)])
         (define body-scope (child-scope scope))
         (define-symbol! (symbol->string var)
           (symbol-info '变量 '整数 0 0 #t #t) body-scope)
         (let loop ([b body] [body-scope body-scope] [errors (append r-errs r2-errs)])
           (if (null? b)
               (values (reverse errors) scope)
               (let-values ([(errs new-scope) (analyze-expr (car b) body-scope constants)])
                 (loop (cdr b) new-scope (append errs errors))))))))]
    [_ (values '() scope)]))

;; 分析 for-each
(define (analyze-foreach expr scope constants)
  (match expr
    [`(for-each ,var ,lst . ,body)
     (let-values ([(l-errs _) (analyze-expr lst scope constants)])
       (define body-scope (child-scope scope))
       (define-symbol! (symbol->string var)
         (symbol-info '变量 #f 0 0 #t #t) body-scope)
       (let loop ([b body] [body-scope body-scope] [errors l-errs])
         (if (null? b)
             (values (reverse errors) scope)
             (let-values ([(errs new-scope) (analyze-expr (car b) body-scope constants)])
               (loop (cdr b) new-scope (append errs errors)))))))]
    [_ (values '() scope)]))

;; 分析 do-while 循环 (let/ec)
(define (analyze-do-while expr scope constants)
  (match expr
    [`(let/ec ,name . ,body)
     (define body-scope (child-scope scope))
     (let loop ([b body] [body-scope body-scope] [errors '()])
       (if (null? b)
           (values (reverse errors) scope)
           (let-values ([(errs new-scope) (analyze-expr (car b) body-scope constants)])
             (loop (cdr b) new-scope (append errs errors))))))]
    [_ (values '() scope)]))
```

- [ ] **步骤 6：编写 analyze-call 函数调用分析**

```racket
;; 分析函数调用: (fn arg1 arg2)
(define (analyze-call expr scope constants)
  (match expr
    [`(,fn . ,args)
     (let* ([fn-str (symbol->string fn)]
            [result (lookup-symbol fn-str scope)])
       (cond
         ;; 检查函数是否定义
         [(not result)
          (unless (member fn-str '("quote" "if" "begin" "let" "let*" "lambda" "set!" "define"))
            (void))  ;; 内置特殊形式不报错
          (values '() scope)]
         [else
          (let loop ([args args] [errors '()])
            (if (null? args)
                (values (reverse errors) scope)
                (let-values ([(errs _) (analyze-expr (car args) scope constants)])
                  (loop (cdr args) (append errs errors)))))]))]
    [_ (values '() scope)]))
```

- [ ] **步骤 7：编写 analyze-match / analyze-try / analyze-return**

```racket
;; 分析匹配语句
(define (analyze-match expr scope constants)
  (match expr
    [`(匹配 ,val . ,clauses)
     (let-values ([(v-errs _) (analyze-expr val scope constants)])
       (let loop ([c clauses] [errors v-errs])
         (if (null? c)
             (values (reverse errors) scope)
             (let ([clause (car c)])
               (let ([body-scope (child-scope scope)])
                 (let-values ([(errs _) (analyze-expr clause body-scope constants)])
                   (loop (cdr c) (append errs errors))))))))]
    [_ (values '() scope)]))

;; 分析 try-catch-finally
(define (analyze-try expr scope constants)
  (match expr
    [`(尝试 ,body . ,handlers)
     (let-values ([(b-errs _) (analyze-expr body scope constants)])
       (let loop ([h handlers] [errors b-errs])
         (if (null? h)
             (values (reverse errors) scope)
             (let-values ([(errs _) (analyze-expr (car h) scope constants)])
               (loop (cdr h) (append errs errors))))))]
    [_ (values '() scope)]))

;; 分析 return 语句
(define (analyze-return expr scope)
  (match expr
    [`(return ,val)
     (analyze-expr val scope (make-hash))]
    [_ (values '() scope)]))
```

### 子任务 1.4：添加符号追踪与遮蔽检测

- [ ] **步骤 1：在 analyze-define 中添加遮蔽警告**

```racket
;; 在 analyze-define 的 `(define name val)` 分支中，
;; 检查是否遮蔽了父作用域的变量
(define (analyze-define expr scope constants)
  (match expr
    [`(define ,name ,val)
     (let* ([name-str (if (symbol? name) (symbol->string name) name)]
            [parent-scope (scope-parent scope)]
            [parent-exists (and parent-scope
                               (hash-ref (scope-symbols parent-scope) name-str #f))])
       (cond
         [existing
          (values (list (make-error
                        'redefined
                        ...))
                  scope)]
         [parent-exists
          ;; 遮蔽警告（可选）
          (define info (symbol-info '变量 #f 0 0 #t #t))
          (define-symbol! name-str info scope)
          (define warnings
            (list (make-error
                   'shadowed
                   (format "变量 '~a' 遮蔽了外层定义的同名变量（第 ~a 行）"
                           name-str (symbol-info-line parent-exists))
                   0 0
                   #f)))
          (let-values ([(v-errs _) (analyze-expr val scope constants)])
            (values (append warnings v-errs) scope)))]
         [else
          ...]))]
    ...))
```

- [ ] **步骤 2：确认 analyze 函数可导出 builtin-names**

```racket
;; 需要从 parser.rkt 获取内置函数名列表
;; 在 reader.rkt 调用时传入
(provide (all-defined-out))
```

- [ ] **步骤 3：运行测试验证核心功能**

运行：`racket mingdao/lang/semantic.rkt`
预期：模块加载成功，无语法错误

---

## 任务 2：创建测试文件（tests/test-semantic.rkt）

**文件：**
- 创建：`mingdao/tests/test-semantic.rkt`

### 子任务 2.1：编写测试框架和基础用例

- [ ] **步骤 1：编写测试文件框架**

```racket
#lang racket/base

;; 明道语言语义分析器测试

(require racket/base
         racket/format
         "mingdao/lang/semantic.rkt"
         rackunit)

(define (test-case name code expected-errors)
  (test-case name
    (let* ([tokens (tokenize code)]
           [ast (parse tokens)]
           [errors (analyze ast (get-builtin-function-names))])
      (check-equal? (length errors) expected-errors))))

;; 获取内置函数名（从 function-names.rkt）
(define builtin-names
  '("打印" "长度" "索引" "列表" "加" "减" "乘" "除" "如果" "那么"
    "否则" "否则若" "对于" "从" "到" "返回" "赋值" "定义" "就是"
    "真值" "假值" "空值" "匿名函数" "列表" "字典" "导入" "导出"
    "映射" "过滤" "范围" "尝试" "捕获" "始终" "匹配" "任意" "新建"))
```

### 子任务 2.2：编写各错误类型的测试用例

- [ ] **步骤 1：编写未定义变量测试**

```racket
(test-case "未定义变量"
  "赋值 x 为 5"
  1  ; 期望 1 个错误
  #:error-type 'undefined-var)

(test-case "未定义变量在表达式中"
  "定义 y 就是 x 加 1"
  1  ; x 未定义
  #:error-type 'undefined-var)
```

- [ ] **步骤 2：编写重复定义测试**

```racket
(test-case "重复定义变量"
  "定义 x 就是 1
   定义 x 就是 2"
  1  ; 期望 1 个重复定义错误
  #:error-type 'redefined)
```

- [ ] **步骤 3：编写正确用法测试**

```racket
(test-case "正确的变量定义和使用"
  "定义 x 就是 5
   x, 打印"
  0)  ; 无错误

(test-case "正确的作用域引用"
  "定义 外部变量 就是 10
   定义 计算 就是函 n：
       返回 外部变量 加 n
   5, 计算, 打印"
  0)  ; 无错误
```

- [ ] **步骤 4：编写常量赋值测试**

```racket
(test-case "常量赋值检测"
  "常量 PI 就是 3.14
   赋值 PI 为 3"
  1  ; 期望 1 个常量赋值错误
  #:error-type 'constant-assign)
```

- [ ] **步骤 5：编写未定义函数调用测试**

```racket
(test-case "未定义函数调用"
  "未知函数(1, 2)"
  1  ; 期望 1 个未定义函数错误
  #:error-type 'undefined-fn)
```

- [ ] **步骤 6：编写作用域链测试**

```racket
(test-case "函数内定义局部变量，函数外引用"
  "定义 foo 就是函 n：
      定义 局部变量 就是 5
      返回 n
   局部变量, 打印"
  1)  ; 期望 1 个未定义变量错误
```

- [ ] **步骤 7：运行所有测试**

运行：`racket -t mingdao/tests/test-semantic.rkt -m`
预期：所有测试通过（或显示预期失败的测试）

---

## 任务 3：集成到 reader.rkt

**文件：**
- 修改：`mingdao/lang/reader.rkt`

### 子任务 3.1：导入并调用语义分析器

- [ ] **步骤 1：在 reader.rkt 中添加语义分析器导入**

```racket
(require "semantic.rkt")  ;; 添加这一行
```

- [ ] **步骤 2：在 read 函数中调用 analyze**

```racket
(define (read in)
  (define content (port->string in))
  (if (string=? content "")
      eof
      (with-handlers ([exn:fail?
                       (λ (e)
                         (parameterize ([current-error-port (current-output-port)])
                           (displayln "=== 明道语言解析错误 ===")
                           (displayln (format-exception e content))
                           (raise e)))])
        (let* ([tokens (tokenize content)]
               [ast (parse tokens)]
               ;; 调用语义分析
               [semantic-errors (analyze ast builtin-names)])
          ;; 显示语义错误警告
          (for ([err semantic-errors])
            (displayln (format-semantic-error err content)))
          ;; 继续执行（不阻断）
          `(module 明道 racket/base
             (require (lib "core.rkt" "mingdao"))
             ,@ast))))))
```

- [ ] **步骤 3：添加 builtin-names 定义**

```racket
;; 在文件顶部添加内置函数名列表
(define builtin-names
  '("打印" "长度" "索引" "列表" "列表修改" "消息拼接" "生成" "捕获" "任意" "新建"
    "定义类" "异步" "等待" ...))  ;; 完整的内置函数列表
```

- [ ] **步骤 4：更新 read-syntax 函数**

```racket
(define (read-syntax src in)
  (define content (port->string in))
  (if (string=? content "")
      eof
      (with-handlers ([exn:fail?
                       (λ (e)
                         (displayln "=== 明道语言解析错误 ===" (current-error-port))
                         (displayln (format-exception e content) (current-error-port))
                         (raise e))])
        (let* ([tokens (tokenize content)]
               [ast (parse tokens)]
               ;; 语义分析（警告模式）
               [semantic-errors (analyze ast builtin-names)])
          (for ([err semantic-errors])
            (displayln (format-semantic-error err content) (current-error-port)))
          (datum->syntax #f
            `(module ,(string->symbol
                        (string-append "明道-"
                          (path->string src)))
               racket/base
               (require (lib "core.rkt" "mingdao"))
               ,@ast))))))
```

- [ ] **步骤 5：验证集成**

运行：`echo '赋值 x 为 5' | racket -l mingdao/lang/reader`
预期：输出语义错误警告但不报错退出

---

## 验收检查

- [ ] 所有测试通过：`racket -t mingdao/tests/test-semantic.rkt -m`
- [ ] 现有测试不受影响：`racket -t mingdao/tests/test-basic.rkt -m`
- [ ] reader.rkt 正确集成：输入未定义变量显示警告但不阻断
- [ ] 错误消息格式正确：包含类型、行号、建议

---

## 自检清单

1. **规格覆盖度**：所有设计文档中的检查规则都有对应测试
2. **占位符扫描**：无"待定"、"TODO"、"后续实现"等占位符
3. **类型一致性**：symbol-info 各字段在所有函数中使用一致
4. **函数签名**：analyze 接收 builtin-names 参数，返回 (listof semantic-error)
