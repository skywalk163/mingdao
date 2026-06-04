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

;; ========== 测试6：数字插值 ==========
(run-test "数字插值"
"定义 price 就是 99
f\"价格: {price}元\""
  "价格: 99元")

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (displayln "所有 f-string 测试通过！")
    (printf "有 ~a 个测试失败！\n" test-failures))