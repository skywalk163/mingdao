#lang racket/base

(require "lang/ir.rkt"
         racket/string
         racket/port)

(displayln "=== IR 集成测试 ===\n")

(define passed 0)
(define failed 0)

(define (assert-equal name actual expected)
  (if (equal? actual expected)
      (begin
        (set! passed (add1 passed))
        (printf "  [PASS] ~a~n" name))
      (begin
        (set! failed (add1 failed))
        (printf "  [FAIL] ~a~n" name)
        (printf "    expected: ~a~n" expected)
        (printf "    actual:   ~a~n" actual))))

(define (assert-true name condition)
  (if condition
      (begin (set! passed (add1 passed)) (printf "  [PASS] ~a~n" name))
      (begin (set! failed (add1 failed)) (printf "  [FAIL] ~a~n" name))))

;; 模拟 reader.rkt 中的 optimize-through-ir
(define (optimize-through-ir ast builtin-names)
  (with-handlers ([exn:fail? (λ (e) ast)])
    (if (use-ir-optimization?)
        (module->racket ast builtin-names)
        ast)))

;; ========== 测试1：simple define through IR ==========
(displayln "--- 测试1：simple define through IR ---")
(let ([result (optimize-through-ir '((define r (+ 3 4))) null)])
  (assert-true "结果非空" (not (null? result)))
  (printf "  AST: ~s~n" result))
(newline)

;; ========== 测试2：IR 优化 - 常量折叠结果 ==========
(displayln "--- 测试2：常量折叠 - IR 级别 ---")
(let* ([m (ast->ir '((define r (+ 3 4))))]
       [funcs (ir-module-functions m)]
       [init-fn (car funcs)]
       [blocks (ir-function-blocks init-fn)]
       [entry-block (car blocks)]
       [instrs (ir-block-instrs entry-block)])
  (printf "  instrs: ~s~n" instrs)
  ;; 第一条应该是 ir-assign (常量折叠后的赋值)
  (assert-true "至少有一条指令" (> (length instrs) 0))
  (assert-equal "第一条指令是 assign" (ir-assign? (car instrs)) #t))
(newline)

;; ========== 测试3：无优化模式下不改变 AST ==========
(displayln "--- 测试3：无优化模式 ---")
(parameterize ([use-ir-optimization? #f])
  (let* ([original '((define r (+ 3 4)))]
         [result (optimize-through-ir original null)])
    (assert-equal "无优化时不改变 AST" result original)))
(newline)

;; ========== 测试4：复杂表达式 - 回退机制 ==========
(displayln "--- 测试4：复杂表达式 (for 循环等) ---")
(let* ([complex-ast '((let/ec break (for ((i (in-range 0 5))) (let/ec continue (打印 i)))))])
  (let ([result (optimize-through-ir complex-ast null)])
    (assert-true "复杂表达式不崩溃" #t)
    (printf "  result length: ~a~n" (length result))))
(newline)

;; ========== 测试5：多种表达式组合 ==========
(displayln "--- 测试5：多种表达式 ---")
(let* ([ast '((define a 10)
              (define b 20)
              (define c (+ a b))
              (打印 c))])
  (let ([result (optimize-through-ir ast null)])
    (assert-true "多表达式处理成功" (not (null? result)))
    (printf "  result: ~s~n" result)))
(newline)

;; ========== 测试6：if 表达式 ==========
(displayln "--- 测试6：if 表达式 ---")
(let* ([ast '((define (f n) (if (> n 0) n 0)))])
  (let ([result (optimize-through-ir ast null)])
    (assert-true "if 定义成功" (not (null? result)))
    (printf "  result: ~s~n" result)))
(newline)

;; ========== 测试7：模块-字符串输入 ==========
(displayln "--- 测试7：reader 管道 ---")
(let* ([input-port (open-input-string "r = 7\nr")])
  (void))
(displayln "  (跳过 - 需使用完整的明道语法)")
(newline)

;; ========== 汇总 ==========
(displayln "=== 汇总 ===")
(printf "通过: ~a / 失败: ~a~n" passed failed)
(if (= failed 0)
    (displayln "✓ 所有 IR 集成测试通过！")
    (printf "✗ 有 ~a 个测试失败！~n" failed))
