#lang racket/base
;; 明道语言严格类型检查器 2.0
;; 严格模式：类型不匹配时抛出异常而非警告

(require racket/match
         racket/list
         racket/string)

(require "type-system.rkt"
         "type-inference.rkt")

(provide check-program check-expr
         *type-errors* get-type-errors clear-errors!
         make-type-env type-env-add-var! type-env-add-fn!
         type-env-lookup-var type-env-lookup-fn
         type-base type-generic type-union type-param
         type-equal? BASE-INTEGER BASE-FLOAT BASE-STRING BASE-BOOLEAN BASE-NULL BASE-ANY
         exn:fail:type?)

;; ============================================================
;; 类型错误结构
;; ============================================================

(struct type-error (message location type-info) #:transparent)

;; ============================================================
;; 错误管理
;; ============================================================

(define *type-errors* '())

(define (record-error! msg loc info)
  (set! *type-errors*
        (cons (type-error msg loc info) *type-errors*)))

(define (get-type-errors)
  (reverse *type-errors*))

(define (clear-errors!)
  (set! *type-errors* '()))

;; ============================================================
;; 异常结构
;; ============================================================

(struct exn:fail:type exn:fail () #:transparent)

;; ============================================================
;; 辅助函数
;; ============================================================

(define (类型->中文 t)
  (cond
    [(type-base? t)
     (cond
       [(eq? (type-base-name t) '整数) "整数"]
       [(eq? (type-base-name t) '浮点数) "浮点数"]
       [(eq? (type-base-name t) '字符串) "字符串"]
       [(eq? (type-base-name t) '布尔) "布尔"]
       [(eq? (type-base-name t) '空值) "空值"]
       [(eq? (type-base-name t) '任意) "任意"]
       [else (symbol->string (type-base-name t))])]
    [(type-generic? t)
     (format "~a<~a>"
             (type-generic-name t)
             (string-join (map 类型->中文 (type-generic-args t)) ", "))]
    [(type-union? t)
     (string-join (map 类型->中文 (type-union-types t)) " | ")]
    [(type-param? t)
     (symbol->string (type-param-name t))]
    [else (format "~a" t)]))

(define (expr->string expr)
  (if (pair? expr)
      (format "(~a ~a)"
              (car expr)
              (string-join (map expr->string (cdr expr)) " "))
      (format "~a" expr)))

(define (位置->字符串 loc)
  (cond
    [(pair? loc) (format "~a" loc)]
    [loc (format "~a" loc)]
    [else "未知位置"]))

;; ============================================================
;; 严格类型兼容检查
;; ============================================================

(define (strict-type-compatible? target source)
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
     (ormap (lambda (t) (strict-type-compatible? t source))
            (type-union-types target))]
    ;; 类型参数
    [(type-param? target) #t]
    ;; 泛型类型
    [(and (type-generic? target) (type-generic? source)
           (eq? (type-generic-name target) (type-generic-name source))
           (= (length (type-generic-args target))
              (length (type-generic-args source))))
     (for/and ([t (type-generic-args target)]
               [s (type-generic-args source)])
       (strict-type-compatible? t s))]
    [else #f]))

(define (数值类型? t)
  (or (type-equal? t BASE-INTEGER)
      (type-equal? t BASE-FLOAT)))

(define (布尔类型? t)
  (type-equal? t BASE-BOOLEAN))

;; ============================================================
;; 解析类型标注
;; ============================================================

(define (parse-type-annotation type-sym)
  (cond
    [(eq? type-sym '整数) BASE-INTEGER]
    [(eq? type-sym '浮点数) BASE-FLOAT]
    [(eq? type-sym '字符串) BASE-STRING]
    [(eq? type-sym '布尔) BASE-BOOLEAN]
    [(eq? type-sym '空值) BASE-NULL]
    [(eq? type-sym '任意) BASE-ANY]
    [(symbol? type-sym) (type-base type-sym)]
    [(and (pair? type-sym) (eq? (car type-sym) '或))
     (type-union (map parse-type-annotation (cdr type-sym)))]
    [(and (pair? type-sym) (eq? (car type-sym) '列表))
     (if (null? (cdr type-sym))
         (type-generic '列表 (list BASE-ANY))
         (type-generic '列表 (map parse-type-annotation (cdr type-sym))))]
    [else (type-base type-sym)]))

;; ============================================================
;; 主检查入口
;; ============================================================

(define (check-program ast env)
  (clear-errors!)
  (for ([expr ast])
    (check-expr expr env))
  (let ([errors (get-type-errors)])
    (unless (null? errors)
      (raise (exn:fail:type
              (format "发现 ~a 个类型错误:\n~a"
                      (length errors)
                      (string-join (map (lambda (e)
                                          (format "错误: ~a" (type-error-message e)))
                                        errors)
                                   "\n"))
              (current-continuation-marks))))))

(define (check-expr expr env)
  "检查表达式，返回推断的类型"
  (match expr
    ;; 变量定义: (定义 x val)
    [`(定义 ,(? symbol? var) ,val)
     (define val-type (infer-expr-type val env))
     (check-val val env)
     (type-env-add-var! env var val-type)
     val-type]

    ;; 变量定义带类型标注: (定义 x: Type val)
    [`(定义 ,(? symbol? var) : ,type-sym ,val)
     (define declared-type (parse-type-annotation type-sym))
     (define val-type (infer-expr-type val env))
     (check-val val env)
     (unless (strict-type-compatible? declared-type val-type)
       (record-error!
        (format "变量 '~a' 标注为 ~a，但实际得到 ~a"
                var (类型->中文 declared-type) (类型->中文 val-type))
        expr
        (list 'expected declared-type 'actual val-type)))
     (type-env-add-var! env var declared-type)
     declared-type]

    ;; 函数定义: (定义 (fn . params) . body)
    [`(定义 (,fn . ,params) . ,body)
     (check-function-definition fn params body env)
     ;; params 是简单符号列表，如 (x y z)
     ;; 转换为参数类型列表
     (type-env-add-fn! env fn (map (lambda (p) BASE-ANY) params) BASE-ANY)
     BASE-ANY]

    ;; 函数定义带返回类型: (定义 (fn . params): ReturnType . body)
    [`(定义 (,fn . ,params) : ,return-sym . ,body)
     (define return-type (parse-type-annotation return-sym))
     (check-function-definition fn params body env)
     (type-env-add-fn! env fn (map (lambda (p) BASE-ANY) params) return-type)
     return-type]

    ;; 返回语句: (返回 val)
    [`(返回 ,val)
     (define val-type (infer-expr-type val env))
     (check-val val env)
     val-type]

    ;; 赋值: (= var val)
    [`(= ,(? symbol? var) ,val)
     (define var-type (type-env-lookup-var env var))
     (define val-type (infer-expr-type val env))
     (check-val val env)
     (when var-type
       (unless (strict-type-compatible? var-type val-type)
         (record-error!
          (format "赋值给 '~a'，变量类型为 ~a，但值类型为 ~a"
                  var (类型->中文 var-type) (类型->中文 val-type))
          expr
          (list 'expected var-type 'actual val-type))))
     val-type]

    ;; 条件: (if cond then else)
    [`(if ,cond ,then ,else)
     (define cond-type (infer-expr-type cond env))
     (check-val cond env)
     (unless (布尔类型? cond-type)
       (record-error!
        (format "if 条件应返回布尔值，但得到 ~a" (类型->中文 cond-type))
        cond
        (list 'expected BASE-BOOLEAN 'actual cond-type)))
     (check-expr then env)
     (check-expr else env)]

    ;; 赋值(兼容旧格式): (赋值 var val)
    [`(赋值 ,(? symbol? var) ,val)
     (define var-type (type-env-lookup-var env var))
     (define val-type (infer-expr-type val env))
     (check-val val env)
     (when var-type
       (unless (strict-type-compatible? var-type val-type)
         (record-error!
          (format "赋值给 '~a'，变量类型为 ~a，但值类型为 ~a"
                  var (类型->中文 var-type) (类型->中文 val-type))
          expr
          (list 'expected var-type 'actual val-type))))
     val-type]

    ;; 遍历: (for 变量 从 start 到 end 做 body)
    [`(for ,(? symbol? var) 从 ,from 到 ,to 做 ,body)
     (define from-type (infer-expr-type from env))
     (define to-type (infer-expr-type to env))
     (check-val from env)
     (check-val to env)
     (check-expr body env)
     BASE-ANY]

    ;; for-each: (for-each 变量 列表 做 body)
    [`(for-each ,(? symbol? var) ,lst 做 ,body)
     (define lst-type (infer-expr-type lst env))
     (check-val lst env)
     (check-expr body env)
     BASE-ANY]

    ;; 算术运算: (加 a b)
    [`(加 ,a ,b)
     (define a-type (infer-expr-type a env))
     (define b-type (infer-expr-type b env))
     (check-val a env)
     (check-val b env)
     (unless (and (数值类型? a-type) (数值类型? b-type))
       (record-error!
        (format "运算 加 需要数值类型参数，但得到 ~a 和 ~a"
                (类型->中文 a-type) (类型->中文 b-type))
        expr
        (list 'expected '(数值 数值) 'actual (list a-type b-type))))
     (if (or (type-equal? a-type BASE-FLOAT)
             (type-equal? b-type BASE-FLOAT))
         BASE-FLOAT
         BASE-INTEGER)]

    ;; 算术运算: (减 a b)
    [`(减 ,a ,b)
     (define a-type (infer-expr-type a env))
     (define b-type (infer-expr-type b env))
     (check-val a env)
     (check-val b env)
     (unless (and (数值类型? a-type) (数值类型? b-type))
       (record-error!
        (format "运算 减 需要数值类型参数，但得到 ~a 和 ~a"
                (类型->中文 a-type) (类型->中文 b-type))
        expr
        (list 'expected '(数值 数值) 'actual (list a-type b-type))))
     (if (or (type-equal? a-type BASE-FLOAT)
             (type-equal? b-type BASE-FLOAT))
         BASE-FLOAT
         BASE-INTEGER)]

    ;; 算术运算: (乘 a b)
    [`(乘 ,a ,b)
     (define a-type (infer-expr-type a env))
     (define b-type (infer-expr-type b env))
     (check-val a env)
     (check-val b env)
     (unless (and (数值类型? a-type) (数值类型? b-type))
       (record-error!
        (format "运算 乘 需要数值类型参数，但得到 ~a 和 ~a"
                (类型->中文 a-type) (类型->中文 b-type))
        expr
        (list 'expected '(数值 数值) 'actual (list a-type b-type))))
     (if (or (type-equal? a-type BASE-FLOAT)
             (type-equal? b-type BASE-FLOAT))
         BASE-FLOAT
         BASE-INTEGER)]

    ;; 算术运算: (除 a b)
    [`(除 ,a ,b)
     (define a-type (infer-expr-type a env))
     (define b-type (infer-expr-type b env))
     (check-val a env)
     (check-val b env)
     (unless (and (数值类型? a-type) (数值类型? b-type))
       (record-error!
        (format "运算 除 需要数值类型参数，但得到 ~a 和 ~a"
                (类型->中文 a-type) (类型->中文 b-type))
        expr
        (list 'expected '(数值 数值) 'actual (list a-type b-type))))
     (if (or (type-equal? a-type BASE-FLOAT)
             (type-equal? b-type BASE-FLOAT))
         BASE-FLOAT
         BASE-INTEGER)]

    ;; 算术运算: (模 a b)
    [`(模 ,a ,b)
     (define a-type (infer-expr-type a env))
     (define b-type (infer-expr-type b env))
     (check-val a env)
     (check-val b env)
     (unless (and (数值类型? a-type) (数值类型? b-type))
       (record-error!
        (format "运算 模 需要数值类型参数，但得到 ~a 和 ~a"
                (类型->中文 a-type) (类型->中文 b-type))
        expr
        (list 'expected '(数值 数值) 'actual (list a-type b-type))))
     (if (or (type-equal? a-type BASE-FLOAT)
             (type-equal? b-type BASE-FLOAT))
         BASE-FLOAT
         BASE-INTEGER)]

    ;; 算术运算: (幂 a b)
    [`(幂 ,a ,b)
     (define a-type (infer-expr-type a env))
     (define b-type (infer-expr-type b env))
     (check-val a env)
     (check-val b env)
     (unless (and (数值类型? a-type) (数值类型? b-type))
       (record-error!
        (format "运算 幂 需要数值类型参数，但得到 ~a 和 ~a"
                (类型->中文 a-type) (类型->中文 b-type))
        expr
        (list 'expected '(数值 数值) 'actual (list a-type b-type))))
     (if (or (type-equal? a-type BASE-FLOAT)
             (type-equal? b-type BASE-FLOAT))
         BASE-FLOAT
         BASE-INTEGER)]

    ;; 比较运算: (大于 a b)
    [`(大于 ,a ,b)
     (check-val a env)
     (check-val b env)
     BASE-BOOLEAN]

    ;; 比较运算: (小于 a b)
    [`(小于 ,a ,b)
     (check-val a env)
     (check-val b env)
     BASE-BOOLEAN]

    ;; 比较运算: (大于等于 a b)
    [`(大于等于 ,a ,b)
     (check-val a env)
     (check-val b env)
     BASE-BOOLEAN]

    ;; 比较运算: (小于等于 a b)
    [`(小于等于 ,a ,b)
     (check-val a env)
     (check-val b env)
     BASE-BOOLEAN]

    ;; 比较运算: (等于 a b)
    [`(等于 ,a ,b)
     (check-val a env)
     (check-val b env)
     BASE-BOOLEAN]

    ;; 比较运算: (不等 a b)
    [`(不等 ,a ,b)
     (check-val a env)
     (check-val b env)
     BASE-BOOLEAN]

    ;; 逻辑运算: (与 a b)
    [`(与 ,a ,b)
     (define a-type (infer-expr-type a env))
     (define b-type (infer-expr-type b env))
     (check-val a env)
     (check-val b env)
     (unless (and (布尔类型? a-type) (布尔类型? b-type))
       (record-error!
        (format "运算 与 需要布尔类型参数，但得到 ~a 和 ~a"
                (类型->中文 a-type) (类型->中文 b-type))
        expr
        (list 'expected '(布尔 布尔) 'actual (list a-type b-type))))
     BASE-BOOLEAN]

    ;; 逻辑运算: (或 a b)
    [`(或 ,a ,b)
     (define a-type (infer-expr-type a env))
     (define b-type (infer-expr-type b env))
     (check-val a env)
     (check-val b env)
     (unless (and (布尔类型? a-type) (布尔类型? b-type))
       (record-error!
        (format "运算 或 需要布尔类型参数，但得到 ~a 和 ~a"
                (类型->中文 a-type) (类型->中文 b-type))
        expr
        (list 'expected '(布尔 布尔) 'actual (list a-type b-type))))
     BASE-BOOLEAN]

    ;; 非运算: (非 val)
    [`(非 ,val)
     (define val-type (infer-expr-type val env))
     (check-val val env)
     (unless (布尔类型? val-type)
       (record-error!
        (format "非运算需要布尔类型参数，但得到 ~a" (类型->中文 val-type))
        expr
        (list 'expected BASE-BOOLEAN 'actual val-type)))
     BASE-BOOLEAN]

    ;; 列表字面量: (列表 . items)
    [`(列表 . ,items)
     (for ([item items])
       (check-val item env))
     (if (null? items)
         (type-generic '列表 (list BASE-ANY))
         (let ([item-types (map (lambda (i) (infer-expr-type i env)) items)])
           (if (for/and ([t item-types]) (type-equal? t (car item-types)))
               (type-generic '列表 (list (car item-types)))
               (type-generic '列表 (list BASE-ANY)))))]

    ;; 字典字面量: (字典 . pairs)
    [`(字典 . ,pairs)
     BASE-ANY]

    ;; 函数调用: (fn . args)
    [`(,fn . ,args)
     (check-function-call fn args env)]

    ;; 符号（变量引用）
    [(? symbol? s)
     (or (type-env-lookup-var env s)
         (type-env-lookup-fn env s)
         BASE-ANY)]

    ;; 字面量
    [(? exact-integer?) BASE-INTEGER]
    [(? inexact-real?) BASE-FLOAT]
    [(? number?) BASE-FLOAT]
    [(? string?) BASE-STRING]
    [(? boolean?) BASE-BOOLEAN]
    [(? null?) BASE-NULL]

    [_ BASE-ANY]))

;; ============================================================
;; 函数定义检查
;; ============================================================

(define (check-function-definition fn-name params body env)
  "检查函数定义"
  ;; params 可以是简单符号列表 (x y z) 或带类型的 ((x : Type) (y : Type))
  (for ([p params])
    (cond
      [(symbol? p) (type-env-add-var! env p BASE-ANY)]
      [(and (pair? p) (symbol? (car p)))
       (type-env-add-var! env (car p) BASE-ANY)]
      [else
       (record-error!
        (format "函数参数格式错误: ~a" p)
        fn-name
        'invalid-parameter)]))
  (for ([b body])
    (check-expr b env)))

;; ============================================================
;; 函数调用检查
;; ============================================================

(define (check-function-call fn-name args env)
  "检查函数调用"
  (define fn-sig (type-env-lookup-fn env fn-name))
  (if fn-sig
      (let ()
        (define expected-params (car fn-sig))
        (define return-type (cadr fn-sig))
        (unless (= (length expected-params) (length args))
          (record-error!
           (format "函数 '~a' 需要 ~a 个参数，但提供了 ~a 个"
                   fn-name (length expected-params) (length args))
           fn-name
           (list 'expected-arity (length expected-params) 'actual-arity (length args))))
        (for ([arg args]
              [expected-type expected-params])
          (define arg-type (infer-expr-type arg env))
          (check-val arg env)
          (unless (strict-type-compatible? expected-type arg-type)
            (record-error!
             (format "函数 '~a' 参数类型不匹配：期望 ~a，得到 ~a"
                     fn-name (类型->中文 expected-type) (类型->中文 arg-type))
             arg
             (list 'expected expected-type 'actual arg-type))))
        return-type)
      (begin
        (for ([arg args])
          (check-val arg env))
        BASE-ANY)))

;; ============================================================
;; 值检查辅助
;; ============================================================

(define (check-val val env)
  "递归检查值表达式"
  (when (pair? val)
    (check-expr val env)))