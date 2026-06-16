#lang racket/base

(require "../lang/type-system.rkt"
         "../lang/type-inference.rkt"
         rackunit)

(printf "\n══════ 泛型类型测试 ══════\n")

;; 测试 1：泛型列表类型
(define (test-generic-list)
  (let ([list-int (type-generic '列表 (list BASE-INTEGER))]
        [list-str (type-generic '列表 (list BASE-STRING))])
    (check-true (type-generic? list-int) "列表<整数> 是泛型")
    (check-equal? (type-generic-name list-int) '列表 "泛型名称为列表")
    (check-equal? (car (type-generic-args list-int)) BASE-INTEGER
                  "泛型参数为整数")
    (check-false (type-equal? list-int list-str)
                 "列表<整数> ≠ 列表<字符串>")))

;; 测试 2：嵌套泛型
(define (test-nested-generic)
  (let ([nested (type-generic '列表 (list (type-generic '列表 (list BASE-INTEGER))))]
        [flat (type-generic '列表 (list BASE-INTEGER))])
    (check-false (type-equal? nested flat)
                 "嵌套列表与扁平列表不同")))

;; 测试 3：泛型类型兼容性
(define (test-generic-compat)
  (let ([list-any (type-generic '列表 (list BASE-ANY))])
    (check-true (type-compatible? list-any
                                  (type-generic '列表 (list BASE-INTEGER)))
                "列表<任意> 兼容列表<整数>")))

;; 测试 4：类型参数推断
(define (test-type-param-inference)
  (let ([env (make-type-env)])
    (type-env-add-var! env 'xs (type-generic '列表 (list BASE-INTEGER)))
    (check-true (type-generic? (infer-expr-type 'xs env))
                "列表变量推断为泛型列表")))

;; 运行所有测试
(test-generic-list)
(test-nested-generic)
(test-generic-compat)
(test-type-param-inference)

(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  泛型类型测试全部通过!               ║\n")
(printf "╚══════════════════════════════════════╝\n")