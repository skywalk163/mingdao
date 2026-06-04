#lang racket/base

;; 关键字占位符模块
;; 提供由解析器处理的关键字占位符

(require (for-syntax racket/base))

(provide 定义 就是 就是函 如果 那么 否则 否则若 对于 从 到 每个从
         返回 跳出 继续 当满足 匿名函数 字典 赋值 导出 模块
         常量 定义宏 就是宏 匹配)

;; 这些关键字主要由 parser 处理
;; 这里提供占位符以便模块能正常加载

(define-syntax (定义 stx)
  (raise-syntax-error '定义 "此关键字应由解析器处理" stx))

(define-syntax (就是 stx)
  (raise-syntax-error '就是 "此关键字应由解析器处理" stx))

(define-syntax (就是函 stx)
  (raise-syntax-error '就是函 "此关键字应由解析器处理" stx))

(define-syntax (如果 stx)
  (raise-syntax-error '如果 "此关键字应由解析器处理" stx))

(define-syntax (那么 stx)
  (raise-syntax-error '那么 "此关键字应由解析器处理" stx))

(define-syntax (否则 stx)
  (raise-syntax-error '否则 "此关键字应由解析器处理" stx))

(define-syntax (否则若 stx)
  (raise-syntax-error '否则若 "此关键字应由解析器处理" stx))

(define-syntax (对于 stx)
  (raise-syntax-error '对于 "此关键字应由解析器处理" stx))

(define-syntax (从 stx)
  (raise-syntax-error '从 "此关键字应由解析器处理" stx))

(define-syntax (到 stx)
  (raise-syntax-error '到 "此关键字应由解析器处理" stx))

(define-syntax (每个从 stx)
  (raise-syntax-error '每个从 "此关键字应由解析器处理" stx))

(define-syntax (返回 stx)
  (raise-syntax-error '返回 "此关键字应由解析器处理" stx))

(define-syntax (匿名函数 stx)
  (raise-syntax-error '匿名函数 "此关键字应由解析器处理" stx))

(define-syntax (跳出 stx)
  (raise-syntax-error '跳出 "此关键字应由解析器处理" stx))

(define-syntax (继续 stx)
  (raise-syntax-error '继续 "此关键字应由解析器处理" stx))

(define-syntax (当满足 stx)
  (raise-syntax-error '当满足 "此关键字应由解析器处理" stx))

(define-syntax (字典 stx)
  (raise-syntax-error '字典 "此关键字应由解析器处理" stx))

(define-syntax (赋值 stx)
  (raise-syntax-error '赋值 "此关键字应由解析器处理" stx))

(define-syntax (导出 stx)
  (raise-syntax-error '导出 "此关键字应由解析器处理" stx))

(define-syntax (模块 stx)
  (raise-syntax-error '模块 "此关键字应由解析器处理" stx))

(define-syntax (常量 stx)
  (raise-syntax-error '常量 "此关键字应由解析器处理" stx))

(define-syntax (定义宏 stx)
  (raise-syntax-error '定义宏 "此关键字应由解析器处理" stx))

(define-syntax (就是宏 stx)
  (raise-syntax-error '就是宏 "此关键字应由解析器处理" stx))

(define-syntax (匹配 stx)
  (raise-syntax-error '匹配 "此关键字应由解析器处理" stx))