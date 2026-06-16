#lang racket/base

;; 类型系统模块
;; 包含类型检查、类型转换、Option类型、结构体等

(require racket/list
         racket/format
         (for-syntax racket/base))

(provide ;; 类型检查函数
         布尔值 转字符串 获取类型
         是整数 是浮点数 是字符串 是符号 是字符 是数 是空 是可调用
         ;; 类型转换函数
         转整数 转浮点数
         ;; 比较函数
         是否相等 不等于 任一 数大于 数小于 数大于等于 数小于等于
         ;; 特殊值
         真值 假值 空值
         ;; Option/Maybe类型
         无 有 是有值 取值 默认值 选项映射
         ;; 命名结构体机制
         *结构体表* 定义结构体 结构 新建结构 字段
         ;; 运行时类型校验
         检查类型 校验类型 *运行时类型别名表*
         ;; 严格模式运行时类型校验
         *strict-runtime-mode*
         enable-strict-runtime!
         disable-strict-runtime!
         断言类型 运行时类型检查
         安全转整数 安全转浮点数)

;; ==================== Python风格类型与转换 ====================

(define (布尔值 x)
  (cond [(eq? x #f) #f]
        [(null? x) #f]
        [(and (number? x) (= x 0)) #f]
        [(and (string? x) (string=? x "")) #f]
        [else #t]))

(define (转字符串 x)
  (cond [(string? x) x]
        [(symbol? x) (symbol->string x)]
        [(number? x) (number->string x)]
        [(boolean? x) (if x "真" "假")]
        [(null? x) "空"]
        [else (~v x)]))

(define (获取类型 x)
  (cond [(null? x) '空值]
        [(boolean? x) '布尔]
        [(number? x) (if (integer? x) '整数 '浮点数)]
        [(string? x) '字符串]
        [(symbol? x) '符号]
        [(list? x) '列表]
        [(char? x) '字符]
        [else '未知]))

;; ==================== 类型检查函数 ====================

(define (是整数 x)
  (integer? x))

(define (是浮点数 x)
  (and (number? x) (real? x) (not (integer? x))))

(define (是字符串 x)
  (string? x))

(define (是符号 x)
  (symbol? x))

(define (是字符 x)
  (char? x))

(define (是数 x)
  (number? x))

(define (是空 x)
  (null? x))

(define (是可调用 x)
  (procedure? x))

;; ==================== 类型转换函数 ====================

(define (转整数 x)
  (cond [(integer? x) x]
        [(number? x) (inexact->exact (floor x))]
        [(string? x) (string->number x)]
        [else (error 转整数 "无法转换为整数: ~a" x)]))

(define (转浮点数 x)
  (cond [(number? x) (exact->inexact x)]
        [(string? x) (string->number x)]
        [else (error 转浮点数 "无法转换为浮点数: ~a" x)]))

;; ==================== 比较函数 ====================

(define (是否相等 a b)
  (equal? a b))

(define (不等于 a b)
  (not (equal? a b)))

(define (任一 . args)
  (ormap values args))

(define (数大于 a b)
  (> a b))

(define (数小于 a b)
  (< a b))

(define (数大于等于 a b)
  (>= a b))

(define (数小于等于 a b)
  (<= a b))

;; ==================== 特殊值 ====================

(define 真值 #t)
(define 假值 #f)
(define 空值 '())

;; ==================== Option/Maybe类型 ====================

(struct 无 () #:transparent)
(struct 有 (值) #:transparent)

(define (是有值 opt)
  (有? opt))

(define (取值 opt [默认 #f])
  (if (有? opt)
      (有-值 opt)
      默认))

(define (默认值 opt default-value)
  (if (有? opt)
      (有-值 opt)
      default-value))

(define (选项映射 opt func)
  (if (有? opt)
      (有 (func (有-值 opt)))
      (无)))

;; ==================== 命名结构体机制 ====================

(define *结构体表* (make-hash))

(define (定义结构体 名称 字段列表)
  (define struct-info (list 'struct 字段列表))
  (hash-set! *结构体表* 名称 struct-info)
  
  (define (make-struct . args)
    (unless (= (length args) (length 字段列表))
      (error '结构 (format "结构体 ~a 需要 ~a 个参数，但提供了 ~a 个" 
                           名称 (length 字段列表) (length args))))
    (cons 名称 (map cons 字段列表 args)))
  
  (define (get-field struct-instance field-name)
    (unless (eq? (car struct-instance) 名称)
      (error 'get-field (format "期望结构体 ~a，但得到 ~a" 名称 (car struct-instance))))
    (define field-pair (assoc field-name (cdr struct-instance)))
    (unless field-pair
      (error 'get-field (format "结构体 ~a 没有字段 ~a" 名称 field-name)))
    (cdr field-pair))
  
  (define (set-field struct-instance field-name value)
    (unless (eq? (car struct-instance) 名称)
      (error 'set-field (format "期望结构体 ~a，但得到 ~a" 名称 (car struct-instance))))
    (define new-fields 
      (map (lambda (pair)
             (if (eq? (car pair) field-name)
                 (cons field-name value)
                 pair))
           (cdr struct-instance)))
    (cons 名称 new-fields))
  
  (namespace-set-variable-value! (string->symbol (format "~a?" 名称)) 
                                 (lambda (x) (and (pair? x) (eq? (car x) 名称)))
                                 #t)
  (namespace-set-variable-value! 名称 make-struct #t)
  (for ([field 字段列表])
    (namespace-set-variable-value! (string->symbol (format "~a-~a" 名称 field))
                                   (lambda (inst) (get-field inst field))
                                   #t)
    (namespace-set-variable-value! (string->symbol (format "设置-~a-~a" 名称 field))
                                   (lambda (inst val) (set-field inst field val))
                                   #t))
  
  (void))

(define-syntax (结构 stx)
  (syntax-case stx ()
    [(_ name (field ...))
     #'(定义结构体 'name '(field ...))]))

(define (新建结构 struct-name . args)
  (define struct-info (hash-ref *结构体表* struct-name #f))
  (unless struct-info
    (error '新建结构 (format "未定义的结构体: ~a" struct-name)))
  (apply (eval struct-name) args))

(define (字段 name) name)

;; ==================== 运行时类型校验 ====================

(define *运行时类型别名表* (make-hash))

(define (展开类型类型别名 type-expr)
  (if (symbol? type-expr)
      (let ([展开的 (hash-ref *运行时类型别名表* type-expr #f)])
        (if 展开的
            (展开类型类型别名 展开的)
            type-expr))
      (if (pair? type-expr)
          (cons (展开类型类型别名 (car type-expr)) 
                (map 展开类型类型别名 (cdr type-expr)))
          type-expr)))

(define (检查类型值 value type-expr)
  (define 实际类型 (展开类型类型别名 type-expr))
  
  (define (检查值 v t)
    (cond
      [(eq? t '任意) #t]
      [(eq? t '整数) (integer? v)]
      [(eq? t '浮点数) (and (number? v) (not (integer? v)))]
      [(eq? t '字符串) (string? v)]
      [(eq? t '布尔) (boolean? v)]
      [(eq? t '空值) (null? v)]
      [(eq? t '列表) (list? v)]
      [(eq? t '字典) (hash? v)]
      [(and (pair? t) (eq? (car t) '或))
       (ormap (lambda (sub-t) (检查值 v sub-t)) (cdr t))]
      [(and (pair? t) (eq? (car t) '列表))
       (and (list? v)
            (or (null? (cdr t))
                (for/and ([item v])
                  (检查值 item (cadr t)))))]
      [(and (pair? t) (eq? (car t) '字典))
       (hash? v)]
      [else #t]))
  
  (检查值 value 实际类型))

(define (检查类型 value type-expr)
  (检查类型值 value type-expr))

(define (校验类型 value type-expr [位置信息 ""])
  (unless (检查类型值 value type-expr)
    (error '校验类型 
           (format "类型校验失败~a: 期望类型 ~a，但实际值为 ~a (类型: ~a)"
                   (if (and (string? 位置信息) (not (string=? 位置信息 ""))) (format " (位置: ~a)" 位置信息) "")
                   type-expr
                   value
                   (获取类型 value))))
  value)

;; ==================== 严格模式运行时类型校验 ====================

;; 严格模式开关
(define *strict-runtime-mode* #t)

(define (enable-strict-runtime!)
  (set! *strict-runtime-mode* #t))

(define (disable-strict-runtime!)
  (set! *strict-runtime-mode* #f))

;; 获取值的类型名称（严格模式版本）
(define (严格-获取类型 value)
  (cond
    [(exact-integer? value) '整数]
    [(flonum? value) '浮点数]
    [(string? value) '字符串]
    [(boolean? value) '布尔]
    [(null? value) '空值]
    [else '任意]))

;; 检查值是否符合预期类型（严格模式版本）
(define (严格-检查类型值 value expected-type)
  (let ([actual-type (严格-获取类型 value)])
    (cond
      [(eq? expected-type '任意) #t]
      [(eq? actual-type expected-type) #t]
      [(and (eq? expected-type '浮点数) (eq? actual-type '整数)) #t]
      [else #f])))

;; 断言类型函数
(define (断言类型 value expected-type)
  (when *strict-runtime-mode*
    (unless (严格-检查类型值 value expected-type)
      (error '断言类型
             (format "运行时类型校验失败: 期望类型 ~a，但得到 ~a (值: ~a)"
                     expected-type
                     (严格-获取类型 value)
                     value))))
  value)

;; 运行时类型检查
(define (运行时类型检查 value type-expr)
  (断言类型 value type-expr))

;; 安全类型转换
(define (安全转整数 value)
  (断言类型 value '整数)
  value)

(define (安全转浮点数 value)
  (断言类型 value '浮点数)
  value)