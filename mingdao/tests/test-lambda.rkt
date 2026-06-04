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

;; ========== 测试3：匿名函数内联使用（括号语法） ==========
(run-test "匿名函数内联使用"
"映射(匿名函数 x: x 乘 2, [1, 2, 3])"
  '(2 4 6))

;; ========== 测试4：匿名函数闭包 ==========
(run-test "匿名函数闭包"
"定义 x 就是 10
定义 f 就是匿名函数 y: x 加 y
f, 5"
  15)

;; ========== 测试5：匿名函数多语句 ==========
(run-test "匿名函数多语句"
"定义 f 就是匿名函数 x: 开始
  定义 y 就是 x 加 1
  返回 y
结束
f, 5"
  6)

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (displayln "所有匿名函数测试通过！")
    (printf "有 ~a 个测试失败！\n" test-failures))