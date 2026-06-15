#lang racket/base

;; 明道语言模块系统测试

(require rackunit
         "../lang/module.rkt")

(displayln "========== 开始运行模块系统测试 ==========")

;; 测试 1：循环依赖检测
(display "  - 循环依赖检测: ")
(let ()
  (define modules (hash 'a '(b) 'b '(c) 'c '(a)))
  (define cycles (detect-circular-deps modules))
  (check-true (not (null? cycles)) "应检测到循环依赖")
  (displayln "✓"))

;; 测试 2：无循环依赖
(display "  - 无循环依赖: ")
(let ()
  (define modules (hash 'a '(b) 'b '(c)))
  (define cycles (detect-circular-deps modules))
  (check-true (null? cycles) "不应检测到循环依赖")
  (displayln "✓"))

;; 测试 3：resolve-package 相对路径
(display "  - 相对路径解析: ")
(let ()
  (define path (resolve-package "./test.mingdao" #f))
  (check-equal? path "./test.mingdao")
  (displayln "✓"))

;; 测试 4：resolve-package 绝对路径
(display "  - 绝对路径解析: ")
(let ()
  (define path (resolve-package "/absolute/path.mingdao" #f))
  (check-equal? path "/absolute/path.mingdao")
  (displayln "✓"))

;; 测试 5：extract-exports 函数
(display "  - 导出列表提取: ")
(let ()
  (define ast '((mingdao-export PI 双倍) (define x 5)))
  (define exports (extract-exports ast))
  (check-equal? (length exports) 2 "应提取2个导出")
  (displayln "✓"))

;; 测试 6：extract-dependencies 函数
(display "  - 依赖列表提取: ")
(let ()
  (define ast '((mingdao-import "./utils") (mingdao-import "./math" #:as m) (define x 5)))
  (define deps (extract-dependencies ast))
  (check-equal? (length deps) 2 "应提取2个依赖")
  (displayln "✓"))

(displayln "========== 测试完成 ==========")
