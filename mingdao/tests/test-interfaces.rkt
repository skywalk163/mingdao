#lang racket/base
;; 明道语言接口系统测试
;; 使用 rackunit 进行单元测试

(require racket/base
         racket/string
         rackunit
         "../lang/interface.rkt")

;; ============================================================
;; 测试辅助函数
;; ============================================================

(define (clear-test-interfaces!)
  "清除所有接口定义"
  (hash-clear! *interfaces*))

;; ============================================================
;; 测试1：接口定义
;; ============================================================

(test-case "定义接口"
  (clear-test-interfaces!)
  ;; 定义一个可打印接口
  (define-interface '可打印
    (list (cons '转字符串 (cons null '字符串))
          (cons '打印 (cons null '空值))))
  (check-true (interface-defined? '可打印)))

;; ============================================================
;; 测试2：接口存在性检查
;; ============================================================

(test-case "接口存在性检查"
  (clear-test-interfaces!)
  ;; 定义接口
  (define-interface '可比较
    (list (cons '等于 (cons (list '任意) '布尔))))
  
  (check-true (interface-defined? '可比较))
  (check-false (interface-defined? '不存在)))

;; ============================================================
;; 测试3：获取接口方法列表
;; ============================================================

(test-case "获取接口方法列表"
  (clear-test-interfaces!)
  (define-interface '可排序
    (list (cons '比较 (cons (list '任意) '布尔))
          (cons '大于 (cons (list '任意) '布尔))))
  
  (define methods (get-interface-methods '可排序))
  (check-not-false methods)
  (check-equal? (length methods) 2)
  (check-equal? (caar methods) '比较)
  (check-equal? (cadar methods) (list '任意)))

;; ============================================================
;; 测试4：获取父接口列表
;; ============================================================

(test-case "获取父接口列表"
  (clear-test-interfaces!)
  (define-interface '可比较
    (list (cons '等于 (cons (list '任意) '布尔))))
  (define-interface '可排序
    (list (cons '大于 (cons (list '任意) '布尔)))
    (list '可比较))
  
  (define parents (get-interface-parents '可排序))
  (check-not-false parents)
  (check-equal? (length parents) 1)
  (check-eq? (car parents) '可比较))

;; ============================================================
;; 测试5：接口实现检查（正确实现）
;; ============================================================

(test-case "接口实现检查-正确实现"
  (clear-test-interfaces!)
  ;; 定义接口
  (define-interface '可打印
    (list (cons '转字符串 (cons null '字符串))))
  
  ;; 定义一个正确实现该接口的类型
  (define methods
    (list (cons '转字符串 (cons null '字符串))))
  
  (check-true (implements-interface? '字符串类型 methods '可打印))
  (check-equal? (check-interface-implementation '字符串类型 methods '可打印) #t))

;; ============================================================
;; 测试6：方法签名不兼容（参数数量不匹配）
;; ============================================================

(test-case "方法签名不兼容-参数数量不匹配"
  (clear-test-interfaces!)
  ;; 定义接口：要求一个参数
  (define-interface '可比较
    (list (cons '比较 (cons (list '任意) '布尔))))
  
  ;; 实现时参数数量不匹配：提供两个参数
  (define bad-methods
    (list (cons '比较 (cons (list '任意 '任意) '布尔))))
  
  (check-false (implements-interface? '类型 bad-methods '可比较))
  (check-true (string-contains? 
               (check-interface-implementation '类型 bad-methods '可比较)
               "不兼容")))

;; ============================================================
;; 测试7：方法签名不兼容（返回类型不匹配）
;; ============================================================

(test-case "方法签名不兼容-返回类型不匹配"
  (clear-test-interfaces!)
  ;; 定义接口：要求返回整数
  (define-interface '可转换
    (list (cons '转换 (cons null '整数))))
  
  ;; 实现时返回类型不匹配：返回字符串
  (define bad-methods
    (list (cons '转换 (cons null '字符串))))
  
  (check-false (implements-interface? '类型 bad-methods '可转换)))

;; ============================================================
;; 测试8：缺少方法实现
;; ============================================================

(test-case "缺少方法实现"
  (clear-test-interfaces!)
  (define-interface '可打印
    (list (cons '打印 (cons null '空值))
          (cons '转字符串 (cons null '字符串))))
  
  ;; 只提供一个方法
  (define partial-methods
    (list (cons '打印 (cons null '空值))))
  
  (check-false (implements-interface? '类型 partial-methods '可打印))
  (check-true (string-contains?
               (check-interface-implementation '类型 partial-methods '可打印)
               "未实现")))

;; ============================================================
;; 测试9：接口继承
;; ============================================================

(test-case "接口继承-直接父接口"
  (clear-test-interfaces!)
  (define-interface '可比较
    (list (cons '等于 (cons (list '任意) '布尔))))
  (define-interface '可排序
    (list (cons '大于 (cons (list '任意) '布尔)))
    (list '可比较))
  
  (check-true (interface-extends? '可排序 '可比较)))

(test-case "接口继承-间接父接口"
  (clear-test-interfaces!)
  (define-interface '可比较
    (list (cons '等于 (cons (list '任意) '布尔))))
  (define-interface '可排序
    (list (cons '大于 (cons (list '任意) '布尔)))
    (list '可比较))
  (define-interface '可相等可排序
    (list (cons '小于 (cons (list '任意) '布尔)))
    (list '可排序))
  
  (check-true (interface-extends? '可相等可排序 '可比较))
  (check-true (interface-extends? '可相等可排序 '可排序)))

(test-case "接口继承-无继承关系"
  (clear-test-interfaces!)
  (define-interface '可比较
    (list (cons '等于 (cons (list '任意) '布尔))))
  (define-interface '可打印
    (list (cons '打印 (cons null '空值))))
  
  (check-false (interface-extends? '可打印 '可比较)))

;; ============================================================
;; 测试10：方法兼容性检查
;; ============================================================

(test-case "方法兼容性-空要求"
  (clear-test-interfaces!)
  (check-true (method-compatible? null (cons null '字符串))))

(test-case "方法兼容性-完全匹配"
  (clear-test-interfaces!)
  (check-true (method-compatible? 
               (cons (list '整数) '布尔)
               (cons (list '整数) '布尔))))

(test-case "方法兼容性-返回类型兼容"
  (clear-test-interfaces!)
  (check-true (method-compatible?
               (cons null (type-base '任意))
               (cons null (type-base '整数)))))

;; ============================================================
;; 运行所有测试
;; ============================================================

;; 测试文件包含的所有测试都会自动运行