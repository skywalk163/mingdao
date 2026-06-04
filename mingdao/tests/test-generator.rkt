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

;; ========== 测试1：简单生成器 ==========
(run-test "简单生成器"
"定义 计数器 就是函 start:
  产出 start
  产出 start 加 1
  产出 start 加 2
定义 gen 就是 计数器, 0
取第一个, gen"
  0)

;; ========== 测试2：多次调用生成器 ==========
(run-test "多次调用生成器"
"定义 计数器 就是函 start:
  产出 start
  产出 start 加 1
  产出 start 加 2
定义 gen 就是 计数器, 5
取第一个, gen
取第一个, gen"
  6)

;; ========== 测试3：转换为列表 ==========
(run-test "转换为列表"
"定义 计数器 就是函 start:
  产出 start
  产出 start 加 1
  产出 start 加 2
定义 gen 就是 计数器, 1
转换列表, gen"
  '(1 2 3))

;; ========== 测试4：取前N个元素 ==========
(run-test "取前N个元素"
"定义 自然数 就是函 start:
  定义 i 就是 start
  当满足 真值:
    产出 i
    赋值 i 为 i 加 1
定义 gen 就是 自然数, 0
取前N个, 5, gen"
  '(0 1 2 3 4))

;; ========== 测试5：生成器参数 ==========
(run-test "生成器参数"
"定义 range 就是函 start, end:
  定义 i 就是 start
  当满足 i 小于 end:
    产出 i
    赋值 i 为 i 加 1
定义 gen 就是 range, 2, 5
转换列表, gen"
  '(2 3 4))

;; ========== 测试6：普通函数不受影响 ==========
(run-test "普通函数不受影响"
"定义 add 就是函 a, b:
  返回 a 加 b
add, 3, 4"
  7)

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (displayln "所有生成器测试通过！")
    (printf "有 ~a 个测试失败！\n" test-failures))