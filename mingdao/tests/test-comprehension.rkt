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

;; ========== 测试1：普通列表 ==========
(run-test "普通列表"
"[1, 2, 3]"
  '(1 2 3))

;; ========== 测试2：列表推导式 ==========
(run-test "列表推导式"
"[对于 x 从 [1, 2, 3]: 加, x, 1]"
  '(2 3 4))

;; ========== 测试3：平方列表推导式 ==========
(run-test "平方列表推导式"
"[对于 x 从 [1, 2, 3]: 乘, x, x]"
  '(1 4 9))

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (printf "所有 列表推导式 测试通过！\n")
    (printf "有 ~a 个测试失败！\n" test-failures))