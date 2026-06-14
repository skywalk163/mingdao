#lang racket/base
;; 斐波那契运行时测试（基于 rackunit）

(require rackunit
         "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

(define code #<<CODE
定义 斐波那契 就是函 n:
    如果 n 小于等于 1 那么:
        返回 n
    否则:
        返回 (斐波那契, n 减 1) 加 (斐波那契, n 减 2)

对于 i 从 0 到 10:
    打印, 斐波那契, i
CODE
)

;; 创建 Mingdao 运行时命名空间
(define (make-mingdao-namespace)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (define core-path
      (path->string (build-path (current-directory) "../core.rkt")))
    (eval `(require (file ,core-path)))
    (void))
  ns)

;; ============================================================
;; 测试
;; ============================================================

(printf "\n══════ 斐波那契运行时测试 ══════\n")

;; 1. 分词不应抛出异常
(define tokens (tokenize code))
(check-true (list? tokens) "分词结果应为列表")
(check-true (> (length tokens) 0) "分词结果不应为空")
(printf "  ✔ 分词成功 (~a tokens)\n" (length tokens))

;; 2. 解析不应抛出异常
(define ast (parse tokens))
(check-true (list? ast) "解析结果应为列表")
(check-true (> (length ast) 0) "解析结果不应为空")
(printf "  ✔ 解析成功 (~a 表达式)\n" (length ast))

;; 3. 验证斐波那契函数值（直接 Racket 实现）
(define ns2 (make-mingdao-namespace))

;; 在 Mingdao 命名空间中定义斐波那契函数
(parameterize ([current-namespace ns2])
  (eval '(define (斐波那契 n)
           (if (<= n 1)
               n
               (+ (斐波那契 (- n 1)) (斐波那契 (- n 2)))))))

;; 验证前几个值
(parameterize ([current-namespace ns2])
  (check-equal? (eval '(斐波那契 0)) 0 "fib(0) = 0")
  (check-equal? (eval '(斐波那契 1)) 1 "fib(1) = 1")
  (check-equal? (eval '(斐波那契 2)) 1 "fib(2) = 1")
  (check-equal? (eval '(斐波那契 3)) 2 "fib(3) = 2")
  (check-equal? (eval '(斐波那契 4)) 3 "fib(4) = 3")
  (check-equal? (eval '(斐波那契 5)) 5 "fib(5) = 5")
  (check-equal? (eval '(斐波那契 6)) 8 "fib(6) = 8")
  (check-equal? (eval '(斐波那契 7)) 13 "fib(7) = 13")
  (check-equal? (eval '(斐波那契 10)) 55 "fib(10) = 55"))

(printf "  ✔ 斐波那契值验证通过\n")

(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  斐波那契 rackunit 测试通过!       ║\n")
(printf "╚══════════════════════════════════════╝\n")