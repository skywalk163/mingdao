#lang racket/base
;; 明道语言接口系统
;; 定义接口数据结构、继承关系和实现检查

(require "type-system.rkt")

(provide
 ;; 接口定义
 define-interface interface-defined?
 get-interface-methods get-interface-parents
 ;; 接口实现检查
 implements-interface? check-interface-implementation method-compatible?
 ;; 接口继承
 interface-extends?
 ;; 内部数据结构（供测试）
 interface-def?
 ;; 测试辅助
 clear-interfaces! *interfaces*
 ;; 重新导出 type-system 的内容
 type-base)

;; ============================================================
;; 接口定义结构
;; ============================================================

;; 接口定义：(interface-def name methods parents)
;; name: 符号，接口名
;; methods: 方法签名列表 (list method-signature ...)
;; parents: 父接口列表 (list parent-name ...)
(struct interface-def (name methods parents) #:transparent)

;; 全局接口定义哈希表
(define *interfaces* (make-hash))

;; ============================================================
;; 接口定义函数
;; ============================================================

(define (define-interface name methods [parents null])
  "定义新接口，添加到全局接口表中"
  (hash-set! *interfaces* name (interface-def name methods parents))
  name)

(define (interface-defined? name)
  "检查接口是否已定义"
  (hash-has-key? *interfaces* name))

(define (get-interface name)
  "获取接口定义结构"
  (hash-ref *interfaces* name #f))

(define (get-interface-methods name)
  "获取接口方法列表"
  (cond
    [(interface-defined? name)
     (interface-def-methods (get-interface name))]
    [else #f]))

(define (get-interface-parents name)
  "获取父接口列表"
  (cond
    [(interface-defined? name)
     (interface-def-parents (get-interface name))]
    [else #f]))

;; ============================================================
;; 方法签名兼容性检查
;; ============================================================

;; 方法签名格式：(cons method-name (cons param-types return-type))
;; 例如：(cons '转字符串 (cons null '字符串))
;; 例如：(cons '大于 (cons (list '任意) '布尔))

(define (method-compatible? required provided)
  "检查提供的方法签名是否满足要求
   required: 必需的方法签名 (cons param-types return-type)
   provided: 提供的方法签名 (cons param-types return-type)"
  (cond
    ;; 如果没有要求，兼容
    [(null? required) #t]
    [else
     (let ([req-params (car required)]
           [req-return (cdr required)]
           [prov-params (car provided)]
           [prov-return (cdr provided)])
       ;; 检查参数数量
       (and (= (length req-params) (length prov-params))
            ;; 检查返回类型兼容性
            (or (eq? req-return prov-return)
                (type-compatible? req-return prov-return))))]))

;; ============================================================
;; 接口实现检查
;; ============================================================

(define (find-method method-name methods)
  "在方法列表中查找指定名称的方法"
  (cond
    [(null? methods) #f]
    [(eq? (caar methods) method-name) (cdar methods)]
    [else (find-method method-name (cdr methods))]))

(define (check-interface-implementation type methods name)
  "检查类型是否正确实现了指定接口，返回 #t 或错误信息"
  (cond
    [(not (interface-defined? name))
     (format "接口 ~a 未定义" name)]
    [else
     (let* ([iface (get-interface name)]
            [required-methods (interface-def-methods iface)])
       (define (check-all-methods req-methods)
         (cond
           [(null? req-methods) #t]
           [else
            (let* ([req-method (car req-methods)]
                   [method-name (car req-method)]
                   [required-sig (cdr req-method)]
                   [provided-sig (find-method method-name methods)])
              (cond
                [(not provided-sig)
                 (format "类型 ~a 未实现方法 ~a" type method-name)]
                [(not (method-compatible? required-sig provided-sig))
                 (format "方法 ~a 的签名不兼容：要求 ~a，提供 ~a"
                         method-name required-sig provided-sig)]
                [else (check-all-methods (cdr req-methods))]))]))
       (check-all-methods required-methods))]))

(define (implements-interface? type methods name)
  "检查类型是否实现了指定接口
   type: 类型名称
   methods: 方法列表 (list (cons method-name signature) ...)
   name: 接口名"
  (let ([result (check-interface-implementation type methods name)])
    (if (eq? result #t) #t #f)))

;; ============================================================
;; 接口继承检查
;; ============================================================

(define (interface-extends? child parent)
  "检查 child 接口是否继承自 parent 接口
   递归检查继承链"
  (cond
    [(not (interface-defined? child)) #f]
    [(not (interface-defined? parent)) #f]
    [else
     (let ([parents (get-interface-parents child)])
       (cond
         ;; 直接父接口
         [(memq parent parents) #t]
         ;; 递归检查父接口的父接口
         [else
          (ormap (lambda (p) (interface-extends? p parent))
                 parents)]))]))

;; ============================================================
;; 清除接口（用于测试）
;; ============================================================

(define (clear-interfaces!)
  "清除所有接口定义（主要用于测试）"
  (hash-clear! *interfaces*))