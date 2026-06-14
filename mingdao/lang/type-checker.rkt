#lang racket/base
;; 明道语言类型检查器（增强版）
;; 编译时检查类型标注一致性，输出警告但不阻断执行

(require racket/match
         racket/list
         racket/string)

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
;; 函数返回类型表（函数名 → 返回类型）
;; ============================================================

(define builtin-return-types
  (make-hash
   '((加 . (λ (ts) (if (member '浮点数 ts) '浮点数 '整数)))
     (减 . (λ (ts) (if (member '浮点数 ts) '浮点数 '整数)))
     (乘 . (λ (ts) (if (member '浮点数 ts) '浮点数 '整数)))
     (除 . (λ (ts) '浮点数))
     (模 . (λ (ts) (if (member '浮点数 ts) '浮点数 '整数)))
     (幂 . (λ (ts) (if (member '浮点数 ts) '浮点数 '整数)))
     (大于 . (λ (ts) '布尔))
     (小于 . (λ (ts) '布尔))
     (大于等于 . (λ (ts) '布尔))
     (小于等于 . (λ (ts) '布尔))
     (等于 . (λ (ts) '布尔))
     (不等 . (λ (ts) '布尔))
     (equal? . (λ (ts) '布尔))
     (与 . (λ (ts) (check-same-type ts '布尔)))
     (或 . (λ (ts) (check-same-type ts '布尔)))
     (非 . (λ (ts) '布尔))
     (not . (λ (ts) '布尔))
     (长度 . (λ (ts) '整数))
     (打印 . (λ (ts) (if (null? ts) '任意 (car ts))))
     (索引 . (λ (ts) '任意))
     (字符串长度 . (λ (ts) '整数))
     (转整数 . (λ (ts) '整数))
     (转浮点数 . (λ (ts) '浮点数))
     (转字符串 . (λ (ts) '字符串))
     (正弦 . (λ (ts) '浮点数))
     (余弦 . (λ (ts) '浮点数))
     (圆周率 . (λ (ts) '浮点数))
     (阶乘 . (λ (ts) '整数))
     (随机整数 . (λ (ts) '整数))
     (绝对值 . (λ (ts) (car ts)))
     (最大值 . (λ (ts) (car ts)))
     (最小值 . (λ (ts) (car ts)))
     (数字转字符串 . (λ (ts) '字符串))
     (字符串转数字 . (λ (ts) '整数))
     (字符串转符号 . (λ (ts) '符号))
     (符号转字符串 . (λ (ts) '字符串))
     (是整数 . (λ (ts) '布尔))
     (是浮点数 . (λ (ts) '布尔))
     (是字符串 . (λ (ts) '布尔))
     (是数 . (λ (ts) '布尔))
     (是空 . (λ (ts) '布尔))
     (获取类型 . (λ (ts) '字符串)))))

(define (check-same-type ts expected)
  (if (and (pair? ts) (null? (cdr ts)) (eq? (car ts) expected))
      expected
      '布尔))

;; ============================================================
;; 类型推断
;; ============================================================

;; 推断表达式的类型，env 是 hash 表 (var → type)
;; function-returns 是 hash 表 (fn-name → return-type)
(define (infer-type expr env [function-returns #hasheq()])
  (match expr
    [(? exact-integer?) '整数]
    [(? inexact-real?) '浮点数]
    [(? number?) '浮点数]
    [(? string?) '字符串]
    [(? boolean?) '布尔]
    [(? null?) '空值]
    [(? symbol? s)
     (or (hash-ref env s #f)
         (hash-ref function-returns s #f)
         '任意)]
    ;; 列表字面量 (列表 ...)
    [`(列表 . ,items)
     (if (null? items)
         '列表
         (let ([elem-types (map (λ (e) (infer-type e env function-returns)) items)])
           (if (and (pair? elem-types)
                    (for/and ([t elem-types]) (equal? t (car elem-types))))
               `(列表 ,(car elem-types))
               '列表)))]
    [`(字典 . ,pairs)
     '字典]
    [`(,(? symbol? op) ,a ,b)
     (cond
       [(member op '(加 减 乘 除 模 幂))
        (let ([ta (infer-type a env function-returns)]
              [tb (infer-type b env function-returns)])
          (if (or (eq? ta '浮点数) (eq? tb '浮点数)) '浮点数 '整数))]
       [(member op '(大于 小于 大于等于 小于等于 等于 不等 equal?))
        '布尔]
       [(eq? op '非) '布尔]
       [(member op '(与 或)) '布尔]
       [else (hash-ref builtin-return-types op
                       (λ () (hash-ref function-returns op '任意)))])]
    [`(if ,cond ,then ,else) 
     (let ([tt (infer-type then env function-returns)]
           [te (infer-type else env function-returns)])
       (if (equal? tt te) tt '任意))]
    [`(,(? symbol? fn) . ,args)
     (define arg-types (map (λ (a) (infer-type a env function-returns)) args))
     (hash-ref builtin-return-types fn
               (λ () (hash-ref function-returns fn '任意)))]
    [`(返回 ,val)
     (infer-type val env function-returns)]
    [`(= ,var ,val)
     (infer-type val env function-returns)]
    [`(for ,var ,from ,to ,body)
     '任意]
    [`(for-each ,var ,in-list ,body)
     '任意]
    [`(定义 ,var ,val)
     (infer-type val env function-returns)]
    [`(定义 (,fn . ,params) . ,body)
     '任意]
    [(? procedure?) '函数]
    [(? vector?) '任意]
    [(? list?) '列表]
    [(? hash?) '字典]
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
             (not (not (member b (cdr a)))))
        (and (pair? a) (eq? (car a) '或)
             (pair? b) (eq? (car b) '或)
             (for/and ([t (cdr b)])
               (not (not (member t (cdr a))))))
        (and (pair? a) (pair? b)
             (eq? (car a) (car b))
             (for/and ([ta (cdr a)] [tb (cdr b)])
               (compatible? ta tb)))
        (and (pair? a) (pair? b)
             (eq? (car a) (car b))
             (null? (cdr b)))))
  
  (compatible? annotated-expanded actual-expanded))

;; ============================================================
;; 类型报告辅助
;; ============================================================

(define (类型->中文 t)
  (cond
    [(eq? t '整数) "整数"]
    [(eq? t '浮点数) "浮点数"]
    [(eq? t '字符串) "字符串"]
    [(eq? t '布尔) "布尔"]
    [(eq? t '空值) "空值"]
    [(eq? t '任意) "任意"]
    [(eq? t '列表) "列表"]
    [(eq? t '字典) "字典"]
    [(pair? t)
     (string-join
      (cons (symbol->string (car t))
            (map (λ (x) (类型->中文 x)) (cdr t)))
      "<" ">" "")]
    [(eq? t '符号) "符号"]
    [(eq? t '函数) "函数"]
    [else (format "~a" t)]))

;; ============================================================
;; 类型检查入口（增强版）
;; ============================================================

(define (check-types ast type-env type-aliases [output-fn displayln])
  ;; 从 type-env 提取变量类型和函数返回类型
  (define var-env type-env)        ;; 变量 → 类型
  (define fn-returns type-env)     ;; 函数名 → 返回类型 (与 type-env 共用)
  
  ;; 当前正在检查的函数及其返回类型（用于 返回 语句检查）
  (define current-function-return-type (make-parameter #f))
  
  (define (check-expr expr env)
    (match expr
      ;; 变量定义: (define var value) — var 必须是符号
      [`(定义 ,(? symbol? var) ,val)
       (define var-type (hash-ref env var '任意))
       (define val-type (infer-type val env fn-returns))
       ;; 递归检查值表达式
       (check-val val env)
       (unless (type-compatible? var-type val-type)
         (output-fn (format "类型警告: 变量 '~a' 标注为 ~a，但实际得到 ~a"
                            var (类型->中文 var-type) (类型->中文 val-type))))]
      
      ;; 函数定义: (define (fn . params) . body)
      [`(定义 (,fn . ,params) . ,body)
       (define fn-return-type (hash-ref env fn '任意))
       ;; 在函数体内检查返回类型
       (parameterize ([current-function-return-type fn-return-type])
         (for ([b body])
           (check-expr b env)))]
      
      ;; 返回语句: (返回 value)
      [`(返回 ,val)
       (define val-type (infer-type val env fn-returns))
       (define expected-type (current-function-return-type))
       (when expected-type
         (unless (type-compatible? expected-type val-type)
           (output-fn (format "类型警告: 函数返回类型声明为 ~a，但返回了 ~a"
                              (类型->中文 expected-type) (类型->中文 val-type)))))
       (check-val val env)]
      
      ;; 赋值: (= var value) 来自 赋值 x = expr
      [`(= ,var ,val)
       (define var-type (hash-ref env var '任意))
       (define val-type (infer-type val env fn-returns))
       (unless (type-compatible? var-type val-type)
         (output-fn (format "类型警告: 赋值给 '~a'，变量类型为 ~a，但值类型为 ~a"
                            var (类型->中文 var-type) (类型->中文 val-type))))
       (check-val val env)]
      
      ;; 条件: (if cond then else)
      [`(if ,cond ,then ,else)
       (define cond-type (infer-type cond env fn-returns))
       (unless (type-compatible? '布尔 cond-type)
         (output-fn (format "类型警告: if 条件应返回布尔值，但得到 ~a" (类型->中文 cond-type))))
       (check-expr cond env)
       (check-expr then env)
       (check-expr else env)]
      
      ;; 赋值(兼容旧格式): (赋值 var val)
      [`(赋值 ,var ,val)
       (define var-type (hash-ref env var '任意))
       (define val-type (infer-type val env fn-returns))
       (unless (type-compatible? var-type val-type)
         (output-fn (format "类型警告: 赋值给 '~a'，变量类型为 ~a，但值类型为 ~a"
                            var (类型->中文 var-type) (类型->中文 val-type))))
       (check-val val env)]
      
      ;; 遍历: (for 变量 从 到 做 ...)
      [(and `(for ,var ,from ,to ,body) (app car 'for))
       (check-val from env)
       (check-val to env)
       (check-expr body env)]
      
      ;; for-each: (for-each 变量 列表 做 ...)
      [(and `(for-each ,var ,lst ,body) (app car 'for-each))
       (check-val lst env)
       (check-expr body env)]
      
      ;; 算术/比较运算: (op a b)
      [(and `(,op ,a ,b) (app car (? (λ (x) (member x '(加 减 乘 除 模 幂 大于 小于 大于等于 小于等于 等于 不等 equal? non 与 或))))))
       (check-val a env)
       (check-val b env)
       ;; 对算术运算检查操作数类型
       (when (member op '(加 减 乘 除 模 幂))
         (define ta (infer-type a env fn-returns))
         (define tb (infer-type b env fn-returns))
         (unless (and (type-compatible? '数值 ta) (type-compatible? '数值 tb))
           (output-fn (format "类型警告: 运算 ~a 需要数值类型参数，但得到 ~a 和 ~a"
                              op (类型->中文 ta) (类型->中文 tb)))))]
      
      ;; 非运算: (非 val)
      [`(非 ,val)
       (check-val val env)]
      
      ;; 函数调用: (fn . args)
      [(and `(,fn . ,args) (app car (and (? symbol?) (? (λ (x) (not (member x '(定义 如果 for for-each 返回 赋值 =))))))))
       (for ([arg args])
         (check-val arg env))]
      
      ;; 列表字面量: (列表 . items)
      [`(列表 . ,items)
       (for ([item items])
         (check-val item env))]
      
      ;; 其他: 不检查
      [_ (void)]))
  
  (define (check-val val env)
    (match val
      [(? pair?)
       (check-expr val env)]
      [_ (void)]))
  
  (for ([expr ast])
    (check-expr expr var-env))
  (void))

(provide 类型->中文)