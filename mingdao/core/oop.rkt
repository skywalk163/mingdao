#lang racket/base

;; 面向对象模块
;; 包含接口、类、对象等面向对象特性

(require racket/list
         (for-syntax racket/base))

(provide ;; 接口/特质
         interfaces define-interface 实现 方法
         ;; 类系统
         classes 定义类 define-class 新建 自己)

;; ==================== 接口/特质相关 ====================

(define interfaces (make-hash))

(define-syntax (define-interface stx)
  (syntax-case stx ()
    [(_ name methods)
     #'(hash-set! interfaces 'name (map car 'methods))]))

(define-syntax (实现 stx)
  (raise-syntax-error '实现 "此关键字应由解析器处理" stx))

(define-syntax (方法 stx)
  (raise-syntax-error '方法 "此关键字应由解析器处理" stx))

;; ==================== 面向对象 - 类和对象 ====================

(define classes (make-hash))

(define (定义类 name fields methods)
  (hash-set! classes name (list fields methods))
  (void))

(define-syntax (define-class stx)
  (syntax-case stx ()
    [(_ name fields methods)
     (let ([name-stx #'name])
       (with-syntax ([class-symbol (datum->syntax name-stx (string->symbol (format "'~a" (syntax-e name-stx))))])
         #'(hash-set! classes class-symbol (list fields methods))))]))

(define (新建 class-name . args)
  (define actual-class-name class-name)
  (define class-info (hash-ref classes actual-class-name #f))
  (unless class-info
    (error '新建 (format "类 '~a' 未定义" actual-class-name)))
  (define fields (first class-info))
  (define methods (second class-info))
  (define obj (make-hasheq))
  (for ([field fields])
    (hash-set! obj (first field) (eval (second field))))
  obj)

(define 自己 #f)