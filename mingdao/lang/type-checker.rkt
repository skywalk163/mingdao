#lang racket/base
;; 明道语言类型检查器
;; 编译时检查类型标注一致性，输出警告但不阻断执行

(require racket/match)

(provide check-types infer-type type-compatible?)

;; ============================================================
;; 类型推断
;; ============================================================

;; 推断表达式的类型，env 是 hash 表 (var → type)
(define (infer-type expr env)
  (match expr
    [(? exact-integer?) '整数]
    [(? number?) '浮点数]        ;; 浮点数字面量
    [(? string?) '字符串]
    [(? boolean?) '布尔]
    [(? null?) '空值]
    [(? list?) '列表]
    [(? hash?) '字典]
    ;; 变量引用：查环境
    [(? symbol? s)
     (hash-ref env s '任意)]
    ;; 算术运算：加 减 乘 除 模 幂
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
       [_ '任意])]  ;; 其他函数调用返回任意
    ;; 函数定义（在 Racket 中为 procedure）
    [(? procedure?) '任意]
    ;; 向量（元组）
    [(? vector?) '任意]
    ;; 默认
    [_ '任意]))

;; ============================================================
;; 类型兼容性检查
;; ============================================================

(define (type-compatible? annotated actual)
  (or (eq? annotated '任意)              ;; 标注为任意 → 接受一切
      (eq? actual '任意)                 ;; 实际为任意 → 接受
      (equal? annotated actual)           ;; 完全相等
      (and (eq? annotated '浮点数) (eq? actual '整数))  ;; 整数→浮点数
      ;; 泛型 → 基类型：列表<整数> 兼容 列表
      (and (pair? annotated) (symbol? actual)
           (eq? (car annotated) actual))
      ;; 基类型 → 泛型：列表 兼容 列表<整数>
      (and (symbol? annotated) (pair? actual)
           (eq? annotated (car actual)))
      ;; 联合类型包含检查：整数 兼容 整数|字符串
      (and (pair? annotated) (eq? (car annotated) '或)
           (member actual (cdr annotated)))
      ;; 联合子集检查：(或 整数) 兼容 (或 整数 字符串)
      (and (pair? annotated) (eq? (car annotated) '或)
           (pair? actual) (eq? (car actual) '或)
           (for/and ([a (cdr actual)])
             (member a (cdr annotated))))))

;; ============================================================
;; 类型检查入口
;; ============================================================

;; type-env: hash 表 (var → type)，包含变量/参数的显式类型标注
;; output-fn: 用于输出警告信息的函数，默认为 displayln
(define (check-types ast type-env [output-fn displayln])
  (define (check-expr expr env)
    (match expr
      ;; 变量定义: (define var value)
      [`(define ,var ,val)
       (define var-type (hash-ref env var '任意))
       (define val-type (infer-type val env))
       (unless (type-compatible? var-type val-type)
         (output-fn (format "类型警告: 变量 '~a' 标注为 ~a，但实际得到 ~a"
                            var var-type val-type)))]
      ;; 函数定义: (define (fn params ...) body)
      [`(define (,fn . ,params) . ,body)
       (void)]  ;; 第一版简化：不深入检查函数体
      [_ (void)]))
  
  (for ([expr ast])
    (check-expr expr type-env))
  (void))