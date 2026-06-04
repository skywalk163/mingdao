# 类型注解系统 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为明道语言添加可选的渐进类型注解（Python 风格 `:类型` 语法），在编译时进行类型检查但不阻断执行。

**架构：** 在解析器 (parser.rkt) 中解析类型标注并构建类型元数据，新增 type-checker.rkt 作为独立的编译时类型检查阶段，检查结果输出警告信息但不修改生成的 Racket 代码。

**技术栈：** Racket/base, racket/match, 现有 parser/tokenizer 框架

---

### 任务 1：在 parser.rkt 中添加类型名识别

**文件：**
- 修改：`mingdao\lang\parser.rkt` — 在函数名前缀列表添加类型名

- [ ] **步骤 1：在 parser.rkt 中定义类型名集合**

在 `parse-definition` 函数附近（或 parser 文件顶部区域）添加类型名判断：

```racket
;; 内置类型名（用于类型标注）
(define 类型名列表
  '("整数" "浮点数" "字符串" "布尔" "空值" "任意" "列表" "字典"))

(define (是类型名? str)
  (member str 类型名列表))
```

- [ ] **步骤 2：运行简单测试验证文件无语法错误**

运行：`& "E:\Program Files\Racket\racket.exe" -e "(require \"../lang/parser.rkt\")" -e "(displayln \"OK\")"`
路径：`g:\dumategithub\langbyracket\mingdao\tests`
预期：输出 OK

- [ ] **步骤 3：Commit**

```bash
git add mingdao/lang/parser.rkt
git commit -m "feat: add type name recognition in parser"
```

### 任务 2：修改 parse-parameter-list 支持参数类型标注

**文件：**
- 修改：`mingdao\lang\parser.rkt:797-807`
- 测试：后续任务

- [ ] **步骤 1：修改 parse-parameter-list 函数**

当前返回 `'(a b)`，改为返回 `'((a 整数) (b 字符串))`。当参数名后跟 `:类型` 时，读取类型名；否则类型记为 `'任意`。

```racket
;; 解析参数列表（支持可选类型标注）
(define (parse-parameter-list)
  (define params '())
  (let loop ()
    (cond
      [(match-identifier?)
       (define pname (string->symbol (token-value (advance))))
       (define ptype
         (if (match? 'COLON)
             (begin
               (advance)
               (define tname (token-value (expect-identifier)))
               (string->symbol tname))
             '任意))
       (set! params (cons (list pname ptype) params))
       (when (match? 'COMMA)
         (advance)
         (loop))]
      [else (void)]))
    (reverse params))
```

- [ ] **步骤 2：更新 parse-definition 中函数定义的参数展开**

在 `parse-definition` 中（约第 651-658 行），`parse-parameter-list` 返回了带类型的参数列表 `'((a 整数) (b 字符串))`，但生成的 Racket `define` 只需要参数名列表。需要提取参数名：

```racket
;; 在 "就是函" 处理分支中，替换第 657-658 行为：
(define param-names (map car params))
(if (= (length body) 1)
    `(define (,name ,@param-names) (let/ec return ,(car body)))
    `(define (,name ,@param-names) (let/ec return (begin ,@body))))
```

- [ ] **步骤 3：运行现有测试确认未破坏功能**

运行：`& "E:\Program Files\Racket\racket.exe" test-try-catch-finally.rkt`
路径：`g:\dumategithub\langbyracket\mingdao\tests`
预期：全部 10 个测试通过

- [ ] **步骤 4：Commit**

```bash
git add mingdao/lang/parser.rkt
git commit -m "feat: parse parameter type annotations"
```

### 任务 3：修改 parse-definition 支持变量类型标注

**文件：**
- 修改：`mingdao\lang\parser.rkt:641-693`

- [ ] **步骤 1：在 parse-definition 中读取变量名后检查类型标注**

在 `(define name (string->symbol (token-value name-token)))` 之后添加：

```racket
;; 检查类型标注
(define var-type
  (if (match? 'COLON)
      (begin
        (advance)
        (define tname (token-value (expect-identifier)))
        (string->symbol tname))
      '任意))
```

同时将变量定义 AST 从 `(define ,name ,final-value)` 改为携带类型信息。为最小化对现有代码的影响，类型信息放在变量名后作为一个标注：

```racket
`(define ,name ,final-value)  ;; 保持原样，类型信息交由类型检查器处理
```

实际上，我们不需要改变变量定义的 AST 生成。类型信息只需在解析器内部跟踪，通过调用类型检查器来验证。但为了类型检查器能获取到信息，可以在解析时收集到一个类型环境中。

**更简单的方案：** 变量和函数的类型信息不嵌入 AST，而是让类型检查器独立遍历 AST 并做推断。类型标注只影响类型检查器，不影响代码生成。

因此，变量定义的代码生成不需要修改。只是在解析时记录变量是否标注了类型。改动如下：

```racket
;; 在 定义 解析中，读取变量名后：
(define name-token (expect-identifier))
(define name (string->symbol (token-value name-token)))
(define name-str (token-value name-token))

;; 新增：检查类型标注（只消耗 token，不改变 AST）
(when (match? 'COLON)
  (advance)
  (expect-identifier))  ;; 类型名，只消费不存储到 AST

;; 其余代码不变...
```

- [ ] **步骤 2：在 "就是函" 分支中解析返回类型**

在 `(expect 'COLON)` 之后（原第 652 行），需要区分 `:返回类型:` 和 `:体` 两种情况。修改后的代码：

```racket
(expect 'COLON)  ;; 参数列表后的冒号
(skip-newlines)

;; 检查是否为返回类型
(define return-type
  (let ([next-tok (current)])
    (if (and next-tok (eq? (token-type next-tok) 'IDENTIFIER)
             (是类型名? (token-value next-tok)))
        (begin
          (define tname (token-value (advance)))  ;; 读取返回类型
          (expect 'COLON)  ;; 返回类型后的冒号
          (string->symbol tname))
        '任意)))

(skip-newlines)
(expect 'INDENT)
(define body (parse-program))
(expect 'DEDENT)
```

注意：这里的 `是类型名?` 我们只在 parser 内部定义了一个函数，但需要确保它在 parse-definition 之前就已定义。

- [ ] **步骤 3：运行现有测试确认未破坏功能**

运行：`& "E:\Program Files\Racket\racket.exe" test-try-catch-finally.rkt`
路径：`g:\dumategithub\langbyracket\mingdao\tests`
预期：全部 10 个测试通过

- [ ] **步骤 4：Commit**

```bash
git add mingdao/lang/parser.rkt
git commit -m "feat: parse variable type annotations and function return types"
```

### 任务 4：创建类型检查器 type-checker.rkt

**文件：**
- 创建：`mingdao\lang\type-checker.rkt`
- 修改：`mingdao\lang\parser.rkt` — 导出类型名列表

- [ ] **步骤 1：创建 type-checker.rkt**

```racket
#lang racket/base
;; 明道语言类型检查器
;; 编译时检查类型标注一致性，输出警告但不阻断执行

(provide check-types infer-type type-compatible?

         ;; 类型名→谓词映射
         类型谓词表)

;; ============================================================
;; 类型谓词映射
;; ============================================================

(define 类型谓词表
  '((整数   . exact-integer?)
    (浮点数 . (lambda (x) (and (number? x) (inexact? x))))
    (字符串 . string?)
    (布尔   . boolean?)
    (空值   . null?)
    (任意   . (lambda (_) #t))
    (列表   . list?)
    (字典   . hash?)))

;; ============================================================
;; 类型推断
;; ============================================================

;; 推断表达式的类型，env 是 (hash 'var 'type) 的形式
(define (infer-type expr env)
  (match expr
    [(? exact-integer?) '整数]
    [(? number?) '浮点数]        ;; 浮点数字面量
    [(? string?) '字符串]
    [(? boolean?) '布尔]
    [(? null?) '空值]
    [(? list?) '列表]
    [(? hash?) '字典]
    ;; 变量引用：查环境
    [(? symbol? s)
     (hash-ref env s '任意)]
    ;; 算术运算：加 减 乘 除 模 幂
    [`(,op ,a ,b)
     (match op
       [(or '加 '减 '乘 '除 '模 '幂)
        (let ([ta (infer-type a env)]
              [tb (infer-type b env)])
          (if (or (eq? ta '浮点数) (eq? tb '浮点数))
              '浮点数
              '整数))]
       [(or '大于 '小于 '大于等于 '小于等于 '等于 '不等)
        '布尔]
       ['非 '布尔]
       [(or '与 '或) '布尔]
       ;; 列表操作
       [(or '索引 '长度)
        (if (eq? (infer-type a env) '字典)
            '任意  ;; 字典索引返回任意
            '任意)]  ;; 列表索引返回任意
       [_
        (hash-ref env op '任意)])]  ;; 函数调用返回任意
    ;; 函数定义（内部不检查）
    [(? procedure?) '任意]
    ;; 向量（元组内部表示）
    [(? vector?) '任意]
    ;; 默认
    [_ '任意]))

;; ============================================================
;; 类型兼容性检查
;; ============================================================

(define (type-compatible? annotated actual)
  (or (eq? annotated '任意)       ;; 标注为任意 → 接受一切
      (eq? actual '任意)          ;; 实际为任意 → 接受（无标注的变量可能是任何类型）
      (eq? annotated actual)      ;; 相同类型
      (and (eq? annotated '浮点数) (eq? actual '整数))))  ;; 整数可赋值给浮点数

;; ============================================================
;; 类型检查入口
;; ============================================================

(define (check-types ast [env (make-hasheq)] [output-fn displayln])
  (define (check-expr expr env)
    (match expr
      ;; 变量定义: (define var value)
      [`(define ,var ,val)
       (define var-type (hash-ref env var '任意))
       (define val-type (infer-type val env))
       (unless (type-compatible? var-type val-type)
         (output-fn (format "类型警告: 变量 '~a' 标注为 ~a，但实际得到 ~a"
                            var var-type val-type)))
       (hash-set! env var var-type)]

      ;; 函数定义: (define (fn params ...) body)
      [`(define (,fn . ,params) . ,body)
       ;; 函数体不在此处深度检查（第一版简化）
       (void)]

      ;; 其他表达式：忽略
      [_ (void)]))
  
  (for ([expr ast])
    (check-expr expr env))
  (void))
```

- [ ] **步骤 2：在 parser.rkt 中导出 `是类型名?` 和 `类型名列表`**

在 parser.rkt 顶部 `provide` 中添加导出：

```racket
(provide parse
         是类型名?
         类型名列表)
```

- [ ] **步骤 3：运行简单测试验证 type-checker.rkt 可加载**

运行：`& "E:\Program Files\Racket\racket.exe" -e "(require \"../lang/type-checker.rkt\")" -e "(displayln \"OK\")"`
路径：`g:\dumategithub\langbyracket\mingdao\tests`
预期：输出 OK

- [ ] **步骤 4：Commit**

```bash
git add mingdao/lang/type-checker.rkt mingdao/lang/parser.rkt
git commit -m "feat: create type checker module"
```

### 任务 5：将类型检查器集成到测试框架

**文件：**
- 创建：`mingdao\tests\test-type-annotations.rkt` — 类型注解测试文件

测试文件使用与 `test-try-catch-finally.rkt` 相同的测试框架，增加类型检查步骤。

- [ ] **步骤 1：创建测试文件**

```racket
#lang racket/base

;; 明道语言类型注解系统 - 运行时执行测试

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         "../lang/type-checker.rkt"
         racket/port)

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

;; 收集类型警告
(define type-warnings '())
(define (collect-warning msg)
  (set! type-warnings (cons msg type-warnings)))

(define (run-test name code expected)
  (printf "===== ~a =====\n" name)
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "失败：~a\n\n" (exn-message e))
                               (set! test-failures (add1 test-failures)))])
    (set! type-warnings '())
    (define tokens (tokenize code))
    (define ast (parse tokens))
    (printf "AST:\n~s\n" ast)
    ;; 执行类型检查
    (check-types ast (make-hasheq) collect-warning)
    (when (pair? type-warnings)
      (printf "类型警告: ~a\n" (string-join (reverse type-warnings) "; ")))
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

;; ========== 测试1：变量整数标注 ==========
(run-test "变量整数标注"
"定义 x: 整数 就是 42
x"
  42)

;; ========== 测试2：变量字符串标注 ==========
(run-test "变量字符串标注"
"定义 s: 字符串 就是 \"你好\"
s"
  "你好")

;; ========== 测试3：变量布尔标注 ==========
(run-test "变量布尔标注"
"定义 b: 布尔 就是 真值
b"
  #t)

;; ========== 测试4：无标注默认任意 ==========
(run-test "无标注默认任意"
"定义 x 就是 42
x"
  42)

;; ========== 测试5：参数类型标注（无返回类型） ==========
(run-test "参数类型标注"
"定义 fn 就是函 a: 整数:
  a
fn, 5"
  5)

;; ========== 测试6：参数+返回类型 ==========
(run-test "参数+返回类型"
"定义 fn 就是函 a: 整数, b: 整数: 整数:
  返回 a 加 b
fn, 3, 4"
  7)

;; ========== 测试7：浮点数兼容整数 ==========
(run-test "浮点数兼容整数"
"定义 f: 浮点数 就是 42
f"
  42)

;; ========== 测试8：类型不匹配（不阻断） ==========
(run-test "类型不匹配（不阻断）"
"定义 x: 整数 就是 \"字符串\"
x"
  "字符串")

;; ========== 测试9：函数无类型标注参数 ==========
(run-test "函数无参数类型"
"定义 fn 就是函 a, b:
  a 加 b
fn, 3, 4"
  7)

;; ========== 测试10：嵌套作用域 ==========
(run-test "嵌套作用域"
"定义 x: 整数 就是 1
定义 x: 字符串 就是 \"a\"
x"
  "a")

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (displayln "所有类型注解测试通过！")
    (printf "有 ~a 个测试失败！\n" test-failures))
```

- [ ] **步骤 2：运行测试确认结果**

运行：`& "E:\Program Files\Racket\racket.exe" test-type-annotations.rkt`
路径：`g:\dumategithub\langbyracket\mingdao\tests`
预期：所有测试通过

- [ ] **步骤 3：Commit**

```bash
git add mingdao/tests/test-type-annotations.rkt
git commit -m "test: add type annotation tests"
```

### 任务 6：修复解析器中的冒号歧义问题

**文件：**
- 修改：`mingdao\lang\parser.rkt` — parse-definition 函数

- [ ] **步骤 1：修复变量定义中的 COLON 消费逻辑**

当前变量定义流程是：
```
定义 变量名
  → (match? 'KEYWORD "就是函") ??
  → (match? 'KEYWORD "就是宏") ??
  → (match? 'KEYWORD "就是")
  → else 报错
```

由于变量定义也可能出现 `:类型` 后跟 `就是`，需要确保 `:` 不会与 `就是函` 等的匹配混淆。修改后的逻辑：

```racket
;; 定义变量名后
;; 检查是否有类型标注
(when (match? 'COLON)
  (advance)                          ;; 消费 :
  (expect-identifier))               ;; 消费类型名

;; 然后匹配 "就是" / "就是函" / "就是宏"
```

但是注意顺序：`定义 x: 整数 就是 42` 解析流程：
1. `expect-identifier` 读取 "x"
2. 此时下一 token 是 COLON
3. 消费 COLON
4. `expect-identifier` 读取 "整数"
5. 下一 token 是 KEYWORD "就是"
6. 进入正常的 "就是" 分支

但注意，当前代码在读取变量名后就检查 `(match? 'KEYWORD "就是函")`，如果下一个 token 是 COLON 而不是 KEYWORD，匹配会失败。所以必须在匹配 `就是函/就是宏/就是` 之前先处理类型标注。

```racket
(define (parse-definition)
  (expect 'KEYWORD "定义")
  (define name-token (expect-identifier))
  (define name (string->symbol (token-value name-token)))
  (define name-str (token-value name-token))
  
  ;; 检查类型标注（变量名: 类型）
  (when (match? 'COLON)
    (advance)              ;; 消费 :
    (expect-identifier))   ;; 消费类型名（如 "整数"）
  
  (cond
    [(match? 'KEYWORD "就是函")
     ...
```

- [ ] **步骤 2：运行测试确认类型注解测试通过**

运行：`& "E:\Program Files\Racket\racket.exe" test-type-annotations.rkt`
路径：`g:\dumategithub\langbyracket\mingdao\tests`
预期：所有测试通过

- [ ] **步骤 3：运行现有测试确认未破坏功能**

运行：`& "E:\Program Files\Racket\racket.exe" test-try-catch-finally.rkt`
路径：`g:\dumategithub\langbyracket\mingdao\tests`
预期：全部 10 个测试通过

- [ ] **步骤 4：Commit**

```bash
git add mingdao/lang/parser.rkt
git commit -m "fix: handle colon before matching definition keywords"
```