#lang racket/base

;; 明道语言类型注解系统 - 运行时执行测试

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         "../lang/type-checker.rkt"
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
    (reset-type-annotations!)
    (define tokens (tokenize code))
    (define ast (parse tokens))
    (printf "AST:\n~s\n" ast)
    ;; 执行类型检查
    (define type-env (get-type-annotations))
    (check-types ast type-env collect-warning)
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

;; ========== 测试11：泛型列表 ==========
(run-test "泛型列表"
"定义 xs: 列表<整数> 就是 [1, 2, 3]
xs"
  '(1 2 3))

;; ========== 测试12：泛型字典 ==========
(run-test "泛型字典"
"定义 d: 字典<字符串, 整数> 就是 字典 \"a\": 1
d"
  (make-hash '(("a" . 1))))

;; ========== 测试13：联合类型 PIPE ==========
(run-test "联合类型 PIPE"
"定义 x: 整数 | 字符串 就是 42
x"
  42)

;; ========== 测试14：联合类型 或 ==========
(run-test "联合类型 或"
"定义 s: 整数 或 字符串 就是 \"hi\"
s"
  "hi")

;; ========== 测试15：泛型基类型兼容 ==========
(run-test "泛型基类型兼容"
"定义 xs: 列表 就是 [1, 2, 3]
xs"
  '(1 2 3))

;; ========== 测试16：联合成员赋值 ==========
(run-test "联合成员赋值"
"定义 v: 整数 | 字符串 就是 \"hello\"
v"
  "hello")

;; ========== 测试17：函数参数泛型 ==========
(run-test "函数参数泛型"
"定义 fn 就是函 xs: 列表<整数>:
  xs
fn, [1]"
  '(1))

;; ========== 测试18：函数返回联合类型 ==========
(run-test "函数返回联合类型"
"定义 fn 就是函 flag: 整数: 整数 | 字符串:
  返回 flag
fn, 42"
  42)

;; ========== 测试19：空值联合 ==========
(run-test "空值联合"
"定义 v: 整数 或 空值 就是 空值
v"
  '())

;; ========== 测试20：嵌套泛型 ==========
(run-test "嵌套泛型"
"定义 xs: 列表<列表<整数>> 就是 [[1]]
xs"
  '((1)))

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (displayln "所有类型注解测试通过！")
    (printf "有 ~a 个测试失败！\n" test-failures))