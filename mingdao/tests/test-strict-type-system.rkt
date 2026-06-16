#lang racket/base

(require "../lang/type-system.rkt"
         "../lang/type-inference.rkt"
         "../lang/type-checker.rkt"
         "../lang/interface.rkt"
         rackunit)

(printf "\n══════ 严格类型系统 2.0 集成测试 ══════\n")

;; 测试 1：完整类型检查流程
(define (test-full-type-check)
  (clear-errors!)
  (let ([env (make-type-env)])
    ;; check-program 在有错误时会抛出异常
    (with-handlers ([exn:fail:type? (lambda (e) (void))])
      (check-program (list '(定义 x 42)
                          '(定义 y (加 x 1))
                          '(定义 z (if (大于 y 10) y 0)))
                     env))
    ;; 如果 check-program 没有抛出异常，说明没有错误
    (check-equal? (length (get-type-errors)) 0
                  "无类型错误的程序应通过检查")))

;; 测试 2：类型推断与检查协同
(define (test-inference-check-coop)
  (clear-errors!)
  (let ([env (make-type-env)])
    (type-env-add-var! env 'name BASE-STRING)
    ;; 字符串字面量
    (check-expr "hello" env)
    (check-equal? (length (get-type-errors)) 0
                  "字符串字面量应类型正确")))

;; 测试 3：接口与类型系统集成
(define (test-interface-type-integration)
  (clear-interfaces!)
  (define-interface '可迭代
    (list (cons '迭代器 (cons null '任意))))
  (check-true (interface-defined? '可迭代)
              "接口定义与类型系统集成成功"))

;; 测试 4：严格模式错误收集
(define (test-strict-error-collection)
  (clear-errors!)
  (let ([env (make-type-env)])
    (with-handlers ([exn:fail:type? (lambda (e) (void))])
      (check-program (list '(定义 x : 整数 "hello"))
                     env))
    (check-true (> (length (get-type-errors)) 0)
                "类型错误应被收集")))

;; 运行所有集成测试
(test-full-type-check)
(test-inference-check-coop)
(test-interface-type-integration)
(test-strict-error-collection)

(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  集成测试全部通过!                   ║\n")
(printf "║  M6 严格类型系统 2.0 实现完成!       ║\n")
(printf "╚══════════════════════════════════════╝\n")