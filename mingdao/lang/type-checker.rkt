#lang racket/base
;; 明道语言类型检查器
;; 编译时检查类型标注一致性，输出警告但不阻断执行

(require racket/match
         racket/list)

(provide check-types infer-type type-compatible? expand-type)

;; ============================================================
;; 类型展开（处理类型别名）
;; ============================================================

(define (expand-type type-expr type-aliases)
  (if (symbol? type-expr)
      (let ([expanded (hash-ref type-aliases type-expr #f)])
        (if expanded
            (expand-type expanded type-aliases)
            type-expr))
      (if (pair? type-expr)
          (cons (expand-type (car type-expr) type-aliases) 
                (map (lambda (t) (expand-type t type-aliases)) (cdr type-expr)))
          type-expr)))

;; ============================================================
;; 类型推断
;; ============================================================

;; 推断表达式的类型，env 是 hash 表 (var → type)
(define (infer-type expr env)
  (match expr
    [(? exact-integer?) '整数]
    [(? number?) '浮点数]
    [(? string?) '字符串]
    [(? boolean?) '布尔]
    [(? null?) '空值]
    [(? list?) '列表]
    [(? hash?) '字典]
    [(? symbol? s)
     (hash-ref env s '任意)]
    [`(,op ,a ,b)
     (match op
       [(or '加 '减 '乘 '除 '模 '幂)
        (let ([ta (infer-type a env)]
              [tb (infer-type b env)])
          (if (or (eq? ta '浮点数) (eq? tb '浮点数))
              '浮点数
              '整数))]
       [(or '大于 '小于 '大于等于 '小于等于 '等于 '不等 'equal?)
        '布尔]
       ['non '布尔]
       [(or '与 '或) '布尔]
       [_ '任意])]
    [(? procedure?) '任意]
    [(? vector?) '任意]
    [_ '任意]))

;; ============================================================
;; 类型兼容性检查
;; ============================================================

(define (type-compatible? annotated actual [type-aliases (make-hash)])
  (define annotated-expanded (expand-type annotated type-aliases))
  (define actual-expanded (expand-type actual type-aliases))
  
  (define (compatible? a b)
    (or (eq? a '任意)
        (eq? b '任意)
        (equal? a b)
        (and (eq? a '浮点数) (eq? b '整数))
        (and (pair? a) (symbol? b) (eq? (car a) b))
        (and (symbol? a) (pair? b) (eq? a (car b)))
        (and (pair? a) (eq? (car a) '或)
             (member b (cdr a)))
        (and (pair? a) (eq? (car a) '或)
             (pair? b) (eq? (car b) '或)
             (for/and ([t (cdr b)])
               (member t (cdr a))))
        (and (pair? a) (pair? b)
             (eq? (car a) (car b))
             (for/and ([ta (cdr a)] [tb (cdr b)])
               (compatible? ta tb)))
        (and (pair? a) (pair? b)
             (eq? (car a) (car b))
             (null? (cdr b)))))
  
  (compatible? annotated-expanded actual-expanded))

;; ============================================================
;; 类型检查入口
;; ============================================================

(define (check-types ast type-env type-aliases [output-fn displayln])
  (define (check-expr expr env)
    (match expr
      [`(define ,var ,val)
       (define var-type (hash-ref env var '任意))
       (define val-type (infer-type val env))
       (unless (type-compatible? var-type val-type type-aliases)
         (output-fn (format "类型警告: 变量 '~a' 标注为 ~a，但实际得到 ~a"
                            var var-type val-type)))]
      [`(define (,fn . ,params) . ,body)
       (void)]
      [_ (void)]))
  
  (for ([expr ast])
    (check-expr expr type-env))
  (void))