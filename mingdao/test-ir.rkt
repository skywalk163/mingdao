#lang racket/base

(require "lang/ir.rkt"
         racket/string
         racket/format)

(displayln "=== M6 中间表示与优化测试 ===\n")

;; ========== 测试辅助函数 ==========
(define passed 0)
(define failed 0)

(define-syntax-rule (test-equal name actual expected)
  (let ((a actual) (e expected))
    (if (equal? a e)
        (begin
          (set! passed (+ passed 1))
          (displayln (format "  [PASS] ~a" name)))
        (begin
          (set! failed (+ failed 1))
          (displayln (format "  [FAIL] ~a" name))
          (displayln (format "    expected: ~a" e))
          (displayln (format "    actual:   ~a" a))))))

;; ========== 测试1: 常量折叠 ==========
(displayln "--- 测试1: 常量折叠 ---")
(define m1 (ast->ir '((define r (+ 3 4)))))
(define r1-block (car (ir-function-blocks (car (ir-module-functions m1)))))
(define r1-first-instr (car (ir-block-instrs r1-block)))
(test-equal "(+ 3 4) 折叠后第一条是 assign" (ir-assign? r1-first-instr) #t)
(when (ir-assign? r1-first-instr)
  (test-equal "(+ 3 4) 折叠后值为7" (ir-const-value (ir-assign-source r1-first-instr)) 7))
(displayln "IR:")
(displayln (ir-module->string m1))
(newline)

;; ========== 测试2: 复杂常量折叠 ==========
(displayln "--- 测试2: 复杂常量折叠 (* (+ 2 3) 4) ---")
(define m2 (ast->ir '((define r (* (+ 2 3) 4)))))
(displayln "IR:")
(displayln (ir-module->string m2))
(newline)

;; ========== 测试3: 变量赋值和引用 ==========
(displayln "--- 测试3: 变量赋值和引用 ---")
(define m3 (ast->ir '((define x 42) (define y (+ x 1)))))
(displayln "IR:")
(displayln (ir-module->string m3))
(newline)

;; ========== 测试4: if 控制流 ==========
(displayln "--- 测试4: if 控制流 ---")
(define m4 (ast->ir '((define (f n)
                        (if (> n 0) n 0)))))
(test-equal "if lowering 产生多个块" (> (length (ir-function-blocks (car (ir-module-functions m4)))) 1) #t)
(displayln "IR:")
(displayln (ir-module->string m4))
(newline)

;; ========== 测试5: IR -> Racket 代码 ==========
(displayln "--- 测试5: IR -> Racket 代码（常量折叠） ---")
(define r5 (module->racket '((define r (+ 3 4)))))
(displayln (format "emit: ~a" r5))
(newline)

(displayln "--- 测试6: IR -> Racket 代码（变量赋值） ---")
(define r6 (module->racket '((define x 42) (define y (+ x 1)))))
(displayln (format "emit: ~a" r6))
(newline)

;; ========== 测试7: IR -> Racket 代码（函数定义） ---
(displayln "--- 测试7: IR -> Racket 代码（函数） ---")
(define r7 (module->racket '((define (f n)
                                (if (> n 0) n 0)))))
(displayln (format "emit: ~a" r7))
(newline)

;; ========== 测试8: 验证 emit 出的代码可以实际执行 ==========
(displayln "--- 测试8: emit 代码可执行性验证 ---")

(define (eval-code exprs)
  (with-handlers ([exn:fail? (lambda (e) (cons 'error (exn-message e)))])
    (cons 'ok (eval `(let () ,@exprs) (make-base-namespace)))))

;; 测试 3+4 的执行
(let ((result (eval-code (append '((define r 0)) (module->racket '((define r (+ 3 4)))) '(r)))))
  (displayln (format "执行 (+ 3 4): ~a" result)))

;; 测试 x=42, y=x+1
(let ((result (eval-code (append '((define x 0) (define y 0))
                                  (module->racket '((define x 42) (define y (+ x 1))))
                                  '((list x y))))))
  (displayln (format "执行 x=42, y=x+1: ~a" result)))

;; 测试 if 函数执行
(let ((result (eval-code (append (module->racket '((define (f n) (if (> n 0) n 0))))
                                  '((list (f 5) (f -3) (f 0)))))))
  (displayln (format "执行 f(5), f(-3), f(0): ~a" result)))

(newline)

;; ========== 测试9: 无优化模式 ==========
(displayln "--- 测试9: 无优化模式 ---")
(parameterize ([use-ir-optimization? #f])
  (define r9 (module->racket '((define r (+ 3 4)))))
  (displayln (format "未优化 emit: ~a" r9)))
(newline)

;; ========== 测试10: 表达式类型 ==========
(displayln "--- 测试10: 多种表达式类型 ---")
(define m10 (ast->ir '((define a 10)
                       (define b (- a 3))
                       (define c (* 2 5))
                       (define d (/ 10 2)))))
(displayln "IR:")
(displayln (ir-module->string m10))
(newline)

(displayln "=== M6 测试完成 ===")
(displayln (format "通过: ~a / 失败: ~a" passed failed))
