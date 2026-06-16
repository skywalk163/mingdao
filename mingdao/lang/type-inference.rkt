#lang racket/base
;; 明道语言类型推断引擎

(require "type-system.rkt")

(provide infer-expr-type infer-list-type infer-call-type
         infer-function-return type-env-with-decls parse-type-expr)

;; ============================================================
;; 类型推断入口
;; ============================================================

(define (infer-expr-type expr env)
  "推断表达式的类型"
  (cond
    ;; 字面量
    [(exact-integer? expr) BASE-INTEGER]
    [(and (number? expr) (not (exact-integer? expr))) BASE-FLOAT]
    [(string? expr) BASE-STRING]
    [(boolean? expr) BASE-BOOLEAN]
    [(null? expr) BASE-NULL]
    
    ;; 符号 - 变量引用
    [(symbol? expr)
     (or (type-env-lookup-var env expr)
         (type-env-lookup-fn env expr)
         BASE-ANY)]
    
    ;; 二元运算 (必须在列表之前检查)
    [(and (pair? expr) (= (length expr) 3)
          (member (car expr) '(加 减 乘 除 模 幂)))
     (infer-binop-type (car expr) (cadr expr) (caddr expr) env)]
    
    ;; 比较运算
    [(and (pair? expr) (= (length expr) 3)
          (member (car expr) '(大于 小于 大于等于 小于等于 等于 不等)))
     BASE-BOOLEAN]
    
    ;; 逻辑运算
    [(and (pair? expr) (member (car expr) '(与 或 非)))
     BASE-BOOLEAN]
    
    ;; if 表达式
    [(and (pair? expr) (eq? (car expr) 'if) (= (length expr) 4))
     (infer-if-type (cadr expr) (caddr expr) (cadddr expr) env)]
    
    ;; 定义表达式
    [(and (pair? expr) (eq? (car expr) '定义))
     (infer-define-type expr env)]
    
    ;; 列表字面量 (必须在函数调用之前检查)
    [(and (pair? expr) (eq? (car expr) '列表))
     (infer-list-type (cdr expr) env)]
    
    ;; 列表字面量 (简化语法 [1, 2, 3])
    [(list? expr)
     (infer-list-type expr env)]
    
    ;; 函数调用 (必须是列表形式但不是列表字面量)
    [(and (pair? expr) (symbol? (car expr)))
     (infer-call-type (car expr) (cdr expr) env)]
    
    [else BASE-ANY]))

;; ============================================================
;; 列表类型推断
;; ============================================================

(define (infer-list-type items env)
  (if (null? items)
      (type-generic '列表 (list BASE-ANY))
      (let ([item-types (map (lambda (i) (infer-expr-type i env)) items)])
        (if (for/and ([t item-types]) (type-equal? t (car item-types)))
            (type-generic '列表 (list (car item-types)))
            (type-generic '列表 (list BASE-ANY))))))

;; ============================================================
;; 二元运算类型推断
;; ============================================================

(define (infer-binop-type op left right env)
  (let ([left-type (infer-expr-type left env)]
        [right-type (infer-expr-type right env)])
    (cond
      [(or (type-equal? left-type BASE-FLOAT)
           (type-equal? right-type BASE-FLOAT))
       BASE-FLOAT]
      [else BASE-INTEGER])))

;; ============================================================
;; if 类型推断
;; ============================================================

(define (infer-if-type cond then else-expr env)
  (let ([then-type (infer-expr-type then env)]
        [else-type (infer-expr-type else-expr env)])
    (if (type-equal? then-type else-type)
        then-type
        (if (type-compatible? then-type else-type)
            else-type
            (if (type-compatible? else-type then-type)
                then-type
                BASE-ANY)))))

;; ============================================================
;; 函数调用类型推断
;; ============================================================

(define (infer-call-type fn-name args env)
  (let ([fn-sig (type-env-lookup-fn env fn-name)])
    (if fn-sig
        (cadr fn-sig)  ; 返回第二项（返回类型）
        BASE-ANY)))

;; ============================================================
;; 函数返回类型推断
;; ============================================================

(define (infer-function-return fn-name env)
  "推断函数的返回类型"
  (let ([fn-sig (type-env-lookup-fn env fn-name)])
    (if fn-sig
        (cadr fn-sig)
        BASE-ANY)))

;; ============================================================
;; 定义表达式推断
;; ============================================================

(define (infer-define-type expr env)
  (cond
    ;; (定义 x val)
    [(and (= (length expr) 3) (symbol? (cadr expr)))
     (infer-expr-type (caddr expr) env)]
    ;; (定义 x: Type val)
    [(and (= (length expr) 4) (symbol? (cadr expr)))
     (parse-type-expr (caddr expr))]
    ;; (定义 (fn . params) . body)
    [(and (pair? (cadr expr)) (symbol? (caadr expr)))
     BASE-ANY]
    [#t BASE-ANY]))

;; ============================================================
;; 辅助：解析类型表达式字符串
;; ============================================================

(define (parse-type-expr type-sym)
  (cond
    [(eq? type-sym '整数) BASE-INTEGER]
    [(eq? type-sym '浮点数) BASE-FLOAT]
    [(eq? type-sym '字符串) BASE-STRING]
    [(eq? type-sym '布尔) BASE-BOOLEAN]
    [(eq? type-sym '空值) BASE-NULL]
    [(eq? type-sym '任意) BASE-ANY]
    [else (type-base type-sym)]))

;; ============================================================
;; 带声明的类型环境
;; ============================================================

(define (type-env-with-decls decls env)
  "将变量和函数声明添加到类型环境"
  (for-each (lambda (decl)
              (cond
                [(and (pair? decl) (eq? (car decl) '定义) (= (length decl) 3)
                      (symbol? (cadr decl)))
                 (let ([t (infer-expr-type (caddr decl) env)])
                   (type-env-add-var! env (cadr decl) t))]
                [(and (pair? decl) (eq? (car decl) '定义)
                      (pair? (cadr decl)) (symbol? (caadr decl)))
                 (type-env-add-fn! env (caadr decl) (length (cdadr decl)) BASE-ANY)]
                [else (void)]))
            decls)
  env)