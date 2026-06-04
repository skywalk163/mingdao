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

;; ========== 测试1：创建有值 Option 并检查类型 ==========
(run-test "创建有值 Option 并检查类型"
"定义 opt 就是 有, 42
是有值, opt"
  #t)

;; ========== 测试2：创建无值 Option 并检查类型 ==========
(run-test "创建无值 Option 并检查类型"
"定义 opt 就是 无
是有值, opt"
  #f)

;; ========== 测试3：从有值中取值 ==========
(run-test "从有值中取值"
"定义 opt 就是 有, 42
取值, opt"
  42)

;; ========== 测试4：从无值中取值（使用默认值） ==========
(run-test "从无值中取值（使用默认值）"
"定义 opt 就是 无
取值, opt, 0"
  0)

;; ========== 测试5：使用默认值函数 ==========
(run-test "使用默认值函数"
"定义 opt 就是 无
默认值, opt, 100"
  100)

;; ========== 测试6：映射函数到有值 ==========
(run-test "映射函数到有值"
"定义 opt 就是 有, 5
定义 result 就是 选项映射, opt, 匿名函数 x: x 乘 2
是有值, result"
  #t)

;; ========== 测试7：映射后的取值 ==========
(run-test "映射后的取值"
"定义 opt 就是 有, 5
定义 result 就是 选项映射, opt, 匿名函数 x: x 乘 2
取值, result"
  10)

;; ========== 测试8：映射函数到无值 ==========
(run-test "映射函数到无值"
"定义 opt 就是 无
定义 result 就是 选项映射, opt, 匿名函数 x: x 乘 2
是有值, result"
  #f)

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (printf "所有 Option 测试通过！\n")
    (printf "有 ~a 个测试失败！\n" test-failures))