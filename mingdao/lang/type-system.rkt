#lang racket/base
;; 明道语言类型系统核心
;; 定义类型表达式数据结构和兼容性判断

(provide
 ;; 类型表达式结构
 make-type-expr type-expr? type-base type-base? type-param type-param?
 type-generic type-generic? type-union type-union? type-interface
 type-interface? type-alias type-alias?
 type-expr-name type-expr-args type-expr-types type-expr-target
 type-expr-methods
 ;; struct 访问器
 type-base-name type-param-name type-generic-name type-generic-args
 type-union-types type-interface-name type-interface-methods
 type-alias-name type-alias-target
 ;; 类型环境
 make-type-env type-env? type-env-vars type-env-fns type-env-types
 type-env-ifaces type-env-generics
 type-env-add-var! type-env-add-fn! type-env-add-type!
 type-env-add-iface! type-env-add-generic!
 type-env-lookup-var type-env-lookup-fn type-env-lookup-type
 type-env-lookup-iface type-env-lookup-generic
 ;; 基础类型常量
 *base-types* BASE-INTEGER BASE-FLOAT BASE-STRING BASE-BOOLEAN
 BASE-NULL BASE-ANY
 ;; 内置类型判断
 builtin-type?
 ;; 类型兼容性判断
 type-compatible? type-equal?)

;; ============================================================
;; 类型表达式结构
;; ============================================================

;; 抽象基类
(struct type-expr () #:transparent)

;; 基础类型：整数、浮点数、字符串等
(struct type-base type-expr (name) #:transparent)

;; 类型参数：泛型类型参数 T, U 等
(struct type-param type-expr (name) #:transparent)

;; 泛型类型：列表<整数>、字典<字符串, 整数>
(struct type-generic type-expr (name args) #:transparent)

;; 联合类型：整数 | 字符串
(struct type-union type-expr (types) #:transparent)

;; 接口类型：定义接口时使用
(struct type-interface type-expr (name methods) #:transparent)

;; 类型别名：定义类型 MyInt 就是 整数
(struct type-alias type-expr (name target) #:transparent)

;; make-type-expr 工厂函数
(define (make-type-expr name args)
  (cond
    [(eq? name '整数) BASE-INTEGER]
    [(eq? name '浮点数) BASE-FLOAT]
    [(eq? name '字符串) BASE-STRING]
    [(eq? name '布尔) BASE-BOOLEAN]
    [(eq? name '空值) BASE-NULL]
    [(eq? name '任意) BASE-ANY]
    [(and (symbol? name) (null? args)) (type-base name)]
    [else (type-generic name args)]))

;; 访问器
(define (type-expr-name t)
  (cond [(type-base? t) (type-base-name t)]
        [(type-param? t) (type-param-name t)]
        [(type-generic? t) (type-generic-name t)]
        [(type-union? t) '联合]
        [(type-interface? t) (type-interface-name t)]
        [(type-alias? t) (type-alias-name t)]
        [else '未知]))

(define (type-expr-args t)
  (and (type-generic? t) (type-generic-args t)))

(define (type-expr-types t)
  (and (type-union? t) (type-union-types t)))

(define (type-expr-target t)
  (and (type-alias? t) (type-alias-target t)))

(define (type-expr-methods t)
  (and (type-interface? t) (type-interface-methods t)))

;; ============================================================
;; 基础类型常量
;; ============================================================

(define BASE-INTEGER (type-base '整数))
(define BASE-FLOAT (type-base '浮点数))
(define BASE-STRING (type-base '字符串))
(define BASE-BOOLEAN (type-base '布尔))
(define BASE-NULL (type-base '空值))
(define BASE-ANY (type-base '任意))

(define *base-types*
  (hash '整数 BASE-INTEGER
        '浮点数 BASE-FLOAT
        '字符串 BASE-STRING
        '布尔 BASE-BOOLEAN
        '空值 BASE-NULL
        '任意 BASE-ANY))

(define (builtin-type? name)
  (hash-has-key? *base-types* name))

;; ============================================================
;; 类型环境
;; ============================================================

(struct type-env (vars fns types ifaces generics) #:transparent)

(define (make-type-env)
  (type-env (make-hash)   ; vars: 变量 → 类型
             (make-hash)   ; fns: 函数名 → (list params return-type)
             (make-hash)   ; types: 类型别名
             (make-hash)   ; ifaces: 接口定义
             (make-hash))) ; generics: 泛型约束

(define (type-env-add-var! env name type)
  (hash-set! (type-env-vars env) name type))

(define (type-env-add-fn! env name params return-type)
  (hash-set! (type-env-fns env) name (list params return-type)))

(define (type-env-add-type! env name target)
  (hash-set! (type-env-types env) name target))

(define (type-env-add-iface! env name methods)
  (hash-set! (type-env-ifaces env) name methods))

(define (type-env-add-generic! env name constraints)
  (hash-set! (type-env-generics env) name constraints))

(define (type-env-lookup-var env name)
  (hash-ref (type-env-vars env) name #f))

(define (type-env-lookup-fn env name)
  (hash-ref (type-env-fns env) name #f))

(define (type-env-lookup-type env name)
  (hash-ref (type-env-types env) name #f))

(define (type-env-lookup-iface env name)
  (hash-ref (type-env-ifaces env) name #f))

(define (type-env-lookup-generic env name)
  (hash-ref (type-env-generics env) name #f))

;; ============================================================
;; 类型兼容性判断
;; ============================================================

(define (type-compatible? target source)
  "判断 source 类型是否可以赋值给 target 类型"
  (cond
    ;; 任意类型兼容一切
    [(and (type-base? target) (eq? (type-base-name target) '任意)) #t]
    [(and (type-base? source) (eq? (type-base-name source) '任意)) #t]
    ;; 基础类型相同
    [(and (type-base? target) (type-base? source)
           (eq? (type-base-name target) (type-base-name source)))
     #t]
    ;; 浮点数与整数兼容（自动转换）
    [(and (type-base? target) (type-base? source)
           (eq? (type-base-name target) '浮点数)
           (eq? (type-base-name source) '整数))
     #t]
    ;; 联合类型
    [(type-union? target)
     (ormap (lambda (t) (type-compatible? t source))
            (type-union-types target))]
    ;; 类型参数
    [(type-param? target) #t]  ; 类型参数可匹配任何类型
    ;; 泛型类型
    [(and (type-generic? target) (type-generic? source)
           (eq? (type-generic-name target) (type-generic-name source))
           (= (length (type-generic-args target))
              (length (type-generic-args source))))
     (for/and ([t (type-generic-args target)]
               [s (type-generic-args source)])
       (type-compatible? t s))]
    [else #f]))

(define (type-equal? t1 t2)
  "判断两个类型是否完全相等"
  (cond
    [(and (type-base? t1) (type-base? t2))
     (eq? (type-base-name t1) (type-base-name t2))]
    [(and (type-param? t1) (type-param? t2))
     (eq? (type-param-name t1) (type-param-name t2))]
    [(and (type-generic? t1) (type-generic? t2)
          (eq? (type-generic-name t1) (type-generic-name t2))
          (= (length (type-generic-args t1))
             (length (type-generic-args t2))))
     (for/and ([a1 (type-generic-args t1)]
               [a2 (type-generic-args t2)])
       (type-equal? a1 a2))]
    [(and (type-union? t1) (type-union? t2)
          (= (length (type-union-types t1))
             (length (type-union-types t2))))
     (for/and ([t1 (type-union-types t1)]
               [t2 (type-union-types t2)])
       (type-equal? t1 t2))]
    [(and (type-interface? t1) (type-interface? t2)
          (eq? (type-interface-name t1) (type-interface-name t2))
          (equal? (type-interface-methods t1) (type-interface-methods t2)))]
    [(and (type-alias? t1) (type-alias? t2)
          (eq? (type-alias-name t1) (type-alias-name t2))
          (type-equal? (type-alias-target t1) (type-alias-target t2)))]
    [else #f]))