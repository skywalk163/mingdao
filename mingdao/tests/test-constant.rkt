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

;; ========== 测试1：常量定义 ==========
(run-test "常量定义"
"常量 x 就是 42
x"
  42)

;; ========== 测试2：常量字符串 ==========
(run-test "常量字符串"
"常量 name 就是 \"小明\"
name"
  "小明")

;; ========== 测试3：常量可读 ==========
(run-test "常量可读"
"常量 x 就是 10
x 加 5"
  15)

;; ========== 测试4：常量在函数中使用 ==========
(run-test "常量在函数中使用"
"常量 rate 就是 0.8
定义 calc 就是函 price:
  price 乘 rate
calc, 100"
  80.0)

;; ========== 测试5：赋值检查（期望解析错误） ==========
(let ([ok #f])
  (with-handlers ([exn:fail? (lambda (e)
                               (set! ok (string-contains? (exn-message e) "不可赋值修改")))])
    (define tokens (tokenize "常量 x 就是 1\n赋值 x 为 2"))
    (define ast (parse tokens))
    (void))
  (printf "===== 赋值检查 =====\n")
  (if ok
      (begin
        (printf "✓ 通过（正确拦截常量赋值）\n\n")
        (set! test-passes (add1 test-passes)))
      (begin
        (printf "✗ 失败：未正确拦截常量赋值\n\n")
        (set! test-failures (add1 test-failures)))))

;; ========== 测试6：常量整数运算 ==========
(run-test "常量整数运算"
"常量 a 就是 3
常量 b 就是 4
a 加 b"
  7)

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (displayln "所有常量测试通过！")
    (printf "有 ~a 个测试失败！\n" test-failures))