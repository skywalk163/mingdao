#lang racket/base
;; 明道语言语义分析器
;; 负责：作用域构建、变量未定义检测、重复定义检测、常量赋值检测、作用域遮蔽警告

(require racket/match
         racket/list
         racket/hash
         racket/string)

(provide analyze
         semantic-error
         scope
         symbol-info
         make-global-scope
         lookup-symbol
         define-symbol!
         infer-type
         type->string
         (struct-out semantic-error)
         (struct-out scope)
         (struct-out symbol-info))

;; ============================================================
;; 当前模块上下文
;; ============================================================

(define current-module-name (make-parameter #f))

(define (current-module)
  (current-module-name))

;; ============================================================
;; 数据结构定义
;; ============================================================

(struct scope (parent    ; 父作用域（#f 表示全局）
               symbols   ; (hash symbol-name-string → symbol-info)
               children) ; 子作用域列表（mutable for append）
  #:transparent #:mutable)

(struct symbol-info (kind     ; '变量 | '函数 | '参数 | '内置函数 | '类型别名
                     type     ; 类型标注（symbol 或 #f）
                     line     ; 定义行号
                     col      ; 定义列号
                     mutable? ; 是否可变（#t=变量 #f=常量）
                     defined? ; 是否已定义
                     public?  ; 是否公开（#t=公开 #f=私有）
                     module)  ; 所属模块
  #:transparent)

(struct semantic-error (type      ; 'undefined-var | 'redefined | 'shadowed | 'constant-assign | 'unused
                        message   ; 中文错误描述
                        line      ; 行号
                        col       ; 列号
                        suggestion) ; 修复建议（字符串或 #f）
  #:transparent)

;; ============================================================
;; 基本操作函数
;; ============================================================

(define (make-global-scope builtin-names)
  (define gs (scope #f (make-hash) null))
  (for ([name builtin-names])
    (define-symbol! name (symbol-info '内置函数 #f 0 0 #f #t #t #f) gs))
  gs)

(define (lookup-symbol name current-scope [add-error! #f])
  (let loop ([s current-scope])
    (cond
      [(not s) #f]
      [(hash-has-key? (scope-symbols s) name)
       (define info (hash-ref (scope-symbols s) name))
       (when add-error!
         (check-accessibility name info s add-error!))
       (cons info s)]
      [else (loop (scope-parent s))])))

(define (define-symbol! name info sc)
  (hash-set! (scope-symbols sc) name info)
  (void))

(define (make-child-scope parent)
  (define child (scope parent (make-hash) null))
  (set-scope-children! parent (cons child (scope-children parent)))
  child)

(define (symbol-name sym)
  (symbol->string sym))

(define (make-error type msg line col [suggestion #f])
  (semantic-error type msg line col suggestion))

;; ============================================================
;; 特殊形式列表（跳过检查）
;; ============================================================

(define special-forms
  (list "quote" "if" "begin" "let" "let*" "letrec"
        "lambda" "λ" "define" "set!" "quasiquote" "unquote"
        "unquote-splicing" "cond" "case" "do" "and" "or"
        "when" "unless" "for" "for-each" "in-range" "async"
        "async/await" "thread" "semaphore" "mutex" "channel"
        "异步" "等待"))

;; ============================================================
;; 位置提取
;; ============================================================

(define (get-line e)
  (if (syntax? e)
      (or (syntax-line e) 0)
      0))

(define (get-col e)
  (if (syntax? e)
      (or (syntax-column e) 0)
      0))

;; ============================================================
;; 建议信息
;; ============================================================

(define (kind->suggestion kind)
  (cond
    [(eq? kind '函数) "重命名函数"]
    [(eq? kind '参数) "重命名参数"]
    [else "重命名或使用赋值语句代替"]))

;; ============================================================
;; 辅助函数：定义带检查的符号
;; ============================================================

(define (register-with-checks! name-str name-sym kind mutable? current-scope add-error!
                                [type #f] #:public? [public? #t])
  ;; 重复定义检查
  (when (hash-has-key? (scope-symbols current-scope) name-str)
    (add-error! (make-error 'redefined
                            (format "重复定义: 符号 '~a' 在当前作用域已存在" name-str)
                            (get-line name-sym)
                            (get-col name-sym)
                            (kind->suggestion kind))))
  ;; 遮蔽检查
  (define parent-found (lookup-symbol name-str (scope-parent current-scope)))
  (when parent-found
    (add-error! (make-error 'shadowed
                            (format "作用域遮蔽: 符号 '~a' 遮蔽了父作用域中的同名符号" name-str)
                            (get-line name-sym)
                            (get-col name-sym)
                            "考虑重命名以提高可读性")))
  ;; 注册
  (define-symbol! name-str
                  (symbol-info kind type (get-line name-sym) (get-col name-sym) mutable? #t public? (current-module))
                  current-scope))

;; ============================================================
;; 辅助函数：检查赋值
;; ============================================================

(define (check-assign! var-sym current-scope add-error!)
  (define var-str (symbol-name var-sym))
  (define found (lookup-symbol var-str current-scope))
  (cond
    [found
     (define info (car found))
     (unless (symbol-info-mutable? info)
       (add-error! (make-error 'constant-assign
                               (format "常量赋值: 符号 '~a' 是不可变绑定，不能被赋值" var-str)
                               (get-line var-sym)
                               (get-col var-sym)
                               "将其声明为变量或使用其他变量名")))]
    [else
     (add-error! (make-error 'undefined-var
                             (format "未定义变量: '~a' 在任何作用域中均未定义" var-str)
                             (get-line var-sym)
                             (get-col var-sym)
                             "在使用前定义此变量"))]))

;; ============================================================
;; 辅助函数：检查符号引用
;; ============================================================

(define (check-symbol-reference! sym current-scope add-error! is-fn?)
  (define sym-str (symbol-name sym))
  (define found (lookup-symbol sym-str current-scope))
  (unless (or found (member sym-str special-forms string=?))
    (add-error! (make-error 'undefined-var
                            (if is-fn?
                                (format "未定义函数: '~a' 在任何作用域中均未定义" sym-str)
                                (format "未定义变量: '~a' 在任何作用域中均未定义" sym-str))
                            (get-line sym)
                            (get-col sym)
                            (if is-fn?
                                "在使用前定义此函数或检查拼写"
                                "在使用前定义此变量")))))

;; ============================================================
;; 辅助函数：在子作用域中分析 body
;; ============================================================

(define (analyze-in-child! body-exprs parent-scope analyze-expr)
  (define child (make-child-scope parent-scope))
  (for ([b body-exprs])
    (analyze-expr b child)))

;; ============================================================
;; 主分析入口
;; ============================================================

(define (analyze ast builtin-names)
  (define global-scope (make-global-scope builtin-names))
  (define errors null)
  
  (define (add-error! e)
    (set! errors (cons e errors)))
  
  (define (analyze-expr expr current-scope)
    (match expr
      
      ;; 变量定义: (define name value)
      [`(define ,(? symbol? name) ,val)
       (define val-type (infer-type val current-scope))
       (register-with-checks! (symbol-name name) name '变量 #t current-scope add-error! val-type)
       (analyze-expr val current-scope)]
      
      ;; 函数定义: (define (fn . params) . body)
      [`(define (,(? symbol? fn) . ,params) . ,body)
       (define fn-str (symbol-name fn))
       (define child-scope (make-child-scope current-scope))
       (for ([p params])
         (when (symbol? p)
           (register-with-checks! (symbol-name p) p '参数 #t child-scope add-error!)))
       ;; 先分析函数体
       (for ([b body])
         (analyze-expr b child-scope))
       ;; 推导返回类型：从 return 语句或最后一条表达式推断
       (define fn-return-type
         (let loop ([b body])
           (cond
             [(null? b) '任意]
             [(and (pair? (car b)) (eq? (caar b) 'return) (pair? (cdar b)))
              (infer-type (cadar b) child-scope)]
             [else (loop (cdr b))])))
       (define final-type
         (if (eq? fn-return-type '任意)
             (and (pair? body) (infer-type (last body) child-scope))
             fn-return-type))
       (register-with-checks! fn-str fn '函数 #f current-scope add-error!
                              (or final-type '任意))]
      
      ;; 赋值: (set! var val)
      [`(set! ,(? symbol? var) ,val)
       (check-assign! var current-scope add-error!)
       (analyze-expr val current-scope)]
      
      ;; 赋值: (= var val)
      [`(= ,(? symbol? var) ,val)
       (check-assign! var current-scope add-error!)
       (analyze-expr val current-scope)]
      
      ;; 条件: (if cond then else)
      [`(if ,cond ,then ,else)
       (analyze-expr cond current-scope)
       (analyze-expr then (make-child-scope current-scope))
       (analyze-expr else (make-child-scope current-scope))]
      
      ;; for 循环: (for ((var (in-range start end))) body ...)
      [`(for ((,(? symbol? var) (in-range ,from-expr ,to-expr))) . ,body)
       (analyze-expr from-expr current-scope)
       (analyze-expr to-expr current-scope)
       (define child-scope (make-child-scope current-scope))
       (register-with-checks! (symbol-name var) var '变量 #t child-scope add-error!)
       (for ([b body])
         (analyze-expr b child-scope))]
      
      ;; for-each 循环: (for ((var list-expr)) body ...)
      [`(for ((,(? symbol? var) ,lst-expr)) . ,body)
       (analyze-expr lst-expr current-scope)
       (define child-scope (make-child-scope current-scope))
       (when (symbol? var)
         (register-with-checks! (symbol-name var) var '变量 #t child-scope add-error!))
       (for ([b body])
         (analyze-expr b child-scope))]
      
      ;; do-while: (let/ec label . body)
      [`(let/ec ,(? symbol? label) . ,body)
       (define child-scope (make-child-scope current-scope))
       (register-with-checks! (symbol-name label) label '变量 #f child-scope add-error!)
       (for ([b body])
         (analyze-expr b child-scope))]
      
      ;; 匹配: (匹配 val . clauses)
      [`(匹配 ,val . ,clauses)
       (analyze-expr val current-scope)
       (for ([clause clauses])
         (analyze-expr clause (make-child-scope current-scope)))]
      
      ;; 尝试: (尝试 body . handlers)
      [`(尝试 ,body . ,handlers)
       (analyze-expr body (make-child-scope current-scope))
       (for ([h handlers])
         (analyze-expr h (make-child-scope current-scope)))]
      
      ;; 返回: (return val)
      [`(return ,val)
       (analyze-expr val current-scope)]
      
      ;; 导入: (导入 . _)
      [`(导入 . ,_) (void)]
      
      ;; 导出: (mingdao-export . _)
      [`(mingdao-export . ,_) (void)]
      
      ;; 列表字面量: (列表 . items)
      [`(列表 . ,items)
       (for ([item items])
         (analyze-expr item current-scope))]
      
      ;; begin 块
      [`(begin . ,exprs)
       (for ([e exprs])
         (analyze-expr e current-scope))]
      
      ;; 函数调用: (fn arg1 arg2 ...)
      [`(,(? symbol? fn) . ,args)
       (check-symbol-reference! fn current-scope add-error! #t)
       (for ([arg args])
         (analyze-expr arg current-scope))]
      
      ;; 单个符号引用
      [(? symbol? sym)
       (check-symbol-reference! sym current-scope add-error! #f)]
      
      ;; 原子值（数字、字符串、布尔、字符、null）：不检查
      [(or (? number?) (? string?) (? boolean?) (? char?) (? null?))
       (void)]
      
      ;; 其他：不检查
      [_ (void)]))
  
  ;; 遍历每个顶层表达式
  (for ([expr ast])
    (analyze-expr expr global-scope))
  
  ;; 返回错误列表（按出现顺序）
  (reverse errors))

;; ============================================================
;; 内置函数返回类型表
;; ============================================================

(define builtin-return-types
  (hash
   "加" (λ (ts) (if (member '浮点数 ts) '浮点数 '整数))
   "减" (λ (ts) (if (member '浮点数 ts) '浮点数 '整数))
   "乘" (λ (ts) (if (member '浮点数 ts) '浮点数 '整数))
   "除" (λ (ts) '浮点数)
   "模" (λ (ts) (if (member '浮点数 ts) '浮点数 '整数))
   "幂" (λ (ts) (if (member '浮点数 ts) '浮点数 '整数))
   "大于" (λ (ts) '布尔)
   "小于" (λ (ts) '布尔)
   "等于" (λ (ts) '布尔)
   "不等" (λ (ts) '布尔)
   "大于等于" (λ (ts) '布尔)
   "小于等于" (λ (ts) '布尔)
   "非" (λ (ts) '布尔)
   "与" (λ (ts) '布尔)
   "或" (λ (ts) '布尔)
   "转整数" (λ (ts) '整数)
   "转浮点数" (λ (ts) '浮点数)
   "数字转字符串" (λ (ts) '字符串)
   "长度" (λ (ts) '整数)
   "索引" (λ (ts) '任意)
   "范围" (λ (ts) '(列表 整数))
   "绝对值" (λ (ts) (if (null? ts) '任意 (car ts)))
   "最大值" (λ (ts) (if (null? ts) '任意 (car ts)))
   "最小值" (λ (ts) (if (null? ts) '任意 (car ts)))
   "正弦" (λ (ts) '浮点数)
   "余弦" (λ (ts) '浮点数)
   "正切" (λ (ts) '浮点数)
   "阶乘" (λ (ts) '整数)
   "随机整数" (λ (ts) '整数)
   "随机浮点数" (λ (ts) '浮点数)
   "字符串长度" (λ (ts) '整数)
   "字符串转列表" (λ (ts) '(列表 字符串))
   "打印" (λ (ts) (if (null? ts) '任意 (car ts)))
   "是整数" (λ (ts) '布尔)
   "是浮点数" (λ (ts) '布尔)
   "是字符串" (λ (ts) '布尔)
   "是数" (λ (ts) '布尔)
   "是空" (λ (ts) '布尔)
   "获取类型" (λ (ts) '字符串)
   "表示" (λ (ts) '字符串)))

;; ============================================================
;; 类型格式化
;; ============================================================

(define (type->string t)
  (cond
    [(eq? t '整数) "整数"]
    [(eq? t '浮点数) "浮点数"]
    [(eq? t '字符串) "字符串"]
    [(eq? t '布尔) "布尔"]
    [(eq? t '空值) "空值"]
    [(eq? t '任意) "任意"]
    [(eq? t '列表) "列表"]
    [(eq? t '字典) "字典"]
    [(eq? t '函数) "函数"]
    [(eq? t '符号) "符号"]
    [(pair? t)
     (string-append (type->string (car t))
                    "<"
                    (string-join (map type->string (cdr t)) ", ")
                    ">")]
    [else (format "~a" t)]))

(define (infer-binary-op op a b scope)
  (match op
    [(or '加 '减 '乘 '模 '幂)
     (let ([ta (infer-type a scope)]
           [tb (infer-type b scope)])
       (if (or (eq? ta '浮点数) (eq? tb '浮点数)) '浮点数 '整数))]
    ['除 '浮点数]
    [(or '大于 '小于 '等于 '不等 '大于等于 '小于等于 'equal?)
     '布尔]
    [(or '非 'not)
     '布尔]
    [(or '与 '或)
     '布尔]
    [_ (let* ([op-str (symbol->string op)]
              [handler (hash-ref builtin-return-types op-str #f)])
         (if handler
             (handler (map (λ (e) (infer-type e scope)) (list a b)))
             '任意))]))

;; ============================================================
;; 类型推导主函数
;; ============================================================

(define (infer-type expr scope)
  (match expr
    ;; 字面量
    [(? exact-integer?) '整数]
    [(? number?) '浮点数]
    [(? string?) '字符串]
    [(? boolean?) '布尔]
    [(? null?) '空值]
    [(? void?) '空值]
    
    ;; 符号引用：查作用域链
    [(? symbol? s)
     (define name (symbol->string s))
     (define found (lookup-symbol name scope))
     (if found
         (or (symbol-info-type (car found)) '任意)
         '任意)]
    
    ;; if 表达式
    [`(if ,_ ,then ,else)
     (let ([tt (infer-type then scope)]
           [te (infer-type else scope)])
       (if (equal? tt te) tt '任意))]
    
    ;; 列表字面量
    [`(列表 . ,items)
     (if (null? items)
         '列表
         (let ([elem-types (map (λ (e) (infer-type e scope)) items)])
           (if (and (pair? elem-types)
                    (for/and ([t elem-types]) (equal? t (car elem-types))))
               `(列表 ,(car elem-types))
               '列表)))]
    
    ;; return / 赋值（右值推导）
    [`(return ,val)
     (infer-type val scope)]
    [`(= ,_ ,val)
     (infer-type val scope)]
    [`(set! ,_ ,val)
     (infer-type val scope)]
    
    ;; 二元运算 (op a b)
    [`(,(? symbol? op) ,a ,b)
     (infer-binary-op op a b scope)]
    
    ;; 函数调用 (fn args...)
    [`(,(? symbol? fn) . ,args)
     (define arg-types (map (λ (a) (infer-type a scope)) args))
     (define handler (hash-ref builtin-return-types (symbol->string fn) #f))
     (if handler
         (handler arg-types)
         (let* ([fn-str (symbol->string fn)]
                [found (lookup-symbol fn-str scope)])
           (if found
               (or (symbol-info-type (car found)) '任意)
               '任意)))]
    
    ;; 其他：无法推导
    [_ '任意]))

;; ============================================================
;; 可见性检查
;; ============================================================

(define (check-accessibility name-str info current-scope add-error!)
  (unless (or (not info)
              (symbol-info-public? info)
              (equal? (symbol-info-module info) (current-module)))
    (add-error! (semantic-error
                  'access-denied
                  (format "符号 '~a' 是私有的，无法在此处访问" name-str)
                  0 0
                  "请将符号改为公开，或在同一模块内访问"))))
