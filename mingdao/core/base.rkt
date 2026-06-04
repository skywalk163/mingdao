#lang racket/base

;; 基础函数模块
;; 包含运算符、字符串操作、列表操作、数学函数等

(require racket/list
         racket/format
         racket/string
         racket/file
         (for-syntax racket/base))

(provide ;; 基本运算符
         模 幂 非 不是 与 或 拼接
         ;; 内置函数
         打印 索引 长度 列表 列表修改 消息拼接
         ;; 字符/字符串操作
         字符 字符码 字符串索引 子字符串 字符串长度
         字符串转列表 列表转字符串 是中文 是数字 是字母 是空白 是换行
         字符串前缀 字符串后缀 字符串包含 反转 数字转字符串 字符串转数字
         大写 小写 替换 去空格 拆分 连接 查找 计数 重复字符串
         ;; 列表操作
         前置 追加多个 去掉首个 字符串转符号 符号转字符串 列表包含
         取前几个 去掉前几个 符号判断 列表判断
         ;; 扩展标准库
         随机整数 绝对值 最大值 最小值 整数开方 映射 过滤 范围
         ;; Python风格数学函数
         四舍五入 开方 求和 整除 向下取整 向上取整 十六进 八进制 二进制
         ;; Python风格集合操作
         排序 全部 枚举 拉链 去重 扁平 输入
         ;; 工具函数
         表示 ascii表示 格式化 元组 复数 冻结集合 读取文件 写入文件
         商余 集合 切片
         ;; 运算符重载机制
         *运算符表* 注册运算符 查找运算符 重载运算符
         加 减 乘 除
         ;; 函数重载机制
         *重载函数表* 定义重载 调用重载
         ;; 装饰器机制
         装饰器)

;; ==================== 基本运算符 ====================

(define (模 a b)
  (define q (floor (/ a b)))
  (- a (* b q)))

(define-syntax 幂
  (syntax-rules ()
    [(_ a b) (expt a b)]))

(define-syntax 非
  (syntax-rules ()
    [(_ a) (not a)]))

(define (不是 x)
  (not x))

(define-syntax 与
  (syntax-rules ()
    [(_) #t]
    [(_ a) a]
    [(_ a b) (and a b)]
    [(_ a b c ...) (and a (与 b c ...))]))

(define-syntax 或
  (syntax-rules ()
    [(_ a b) (or a b)]))

(define (拼接 . items)
  (apply string-append
    (map (lambda (x) (if (string? x) x (~v x))) items)))

;; ==================== 内置函数 ====================

(define (打印 x)
  (displayln x))

(define (索引 lst idx)
  (if (or (< idx 0) (>= idx (length lst)))
      '()
      (list-ref lst idx)))

(define-syntax 长度
  (syntax-rules ()
    [(_ lst) (length lst)]))

(define (列表修改 lst pos val)
  (cond
    [(< pos 0)
     (let ([prefix (append (make-list (- (abs pos) 1) 0) (list val))])
       (append prefix lst))]
    [(>= pos (length lst))
     (let ([diff (- pos (length lst))])
       (append lst (make-list diff 0) (list val)))]
    [else
     (list-set lst pos val)]))

(define (消息拼接 . args)
  (apply string-append (map (lambda (x) (if (string? x) x (format "~a" x))) args)))

(define-syntax 列表
  (syntax-rules ()
    [(_ . args) (list . args)]))

;; ==================== 字符/字符串操作 ====================

(define (字符 n)
  (integer->char n))

(define (字符码 ch)
  (char->integer (if (char? ch) ch (string-ref ch 0))))

(define (字符串索引 s n)
  (string-ref s n))

(define (子字符串 s start [end #f])
  (if end
      (substring s start end)
      (substring s start)))

(define (字符串长度 s)
  (string-length s))

(define (字符串转列表 s)
  (string->list s))

(define (列表转字符串 lst)
  (list->string lst))

(define (是中文 ch)
  (let ([c (char->integer (if (char? ch) ch (string-ref ch 0)))])
    (or (and (>= c #x4E00) (<= c #x9FFF))
        (and (>= c #x3400) (<= c #x4DBF))
        (and (>= c #x20000) (<= c #x2A6DF))
        (and (>= c #x2A700) (<= c #x2B73F))
        (and (>= c #x2B740) (<= c #x2B81F))
        (and (>= c #x2B820) (<= c #x2CEAF))
        (and (>= c #x2F800) (<= c #x2FA1F))
        (and (>= c #x3000) (<= c #x303F)))))

(define (是数字 ch)
  (char-numeric? (if (char? ch) ch (string-ref ch 0))))

(define (是字母 ch)
  (char-alphabetic? (if (char? ch) ch (string-ref ch 0))))

(define (是空白 ch)
  (char-whitespace? (if (char? ch) ch (string-ref ch 0))))

(define (是换行 ch)
  (char=? (if (char? ch) ch (string-ref ch 0)) #\newline))

(define (字符串前缀 s prefix)
  (string-prefix? s prefix))

(define (字符串后缀 s suffix)
  (string-suffix? s suffix))

(define (字符串包含 s substr)
  (if (string-contains? s substr) #t #f))

(define (反转 lst)
  (reverse lst))

(define (数字转字符串 n)
  (number->string n))

(define (字符串转数字 s)
  (string->number s))

(define (大写 s)
  (string-upcase s))

(define (小写 s)
  (string-downcase s))

(define (替换 s old new)
  (string-replace s old new))

(define (去空格 s)
  (string-trim s))

(define (拆分 s sep)
  (string-split s sep))

(define (连接 sep lst)
  (string-join lst sep))

(define (查找 s sub)
  (define m (regexp-match-positions (regexp-quote sub) s))
  (if m (car (car m)) -1))

(define (计数 s sub)
  (define len (string-length sub))
  (if (= len 0)
      0
      (let loop ([pos 0] [count 0])
        (define m (regexp-match-positions (regexp-quote sub) s pos))
        (if m
            (loop (+ (car (car m)) len) (+ count 1))
            count))))

(define (重复字符串 s n)
  (string-append* (make-list n s)))

;; ==================== 列表操作 ====================

(define (前置 元素 列表)
  (cons 元素 列表))

(define (追加多个 列表1 列表2)
  (append 列表1 列表2))

(define (去掉首个 lst)
  (if (null? lst) '() (cdr lst)))

(define (字符串转符号 s)
  (string->symbol s))

(define (符号转字符串 s)
  (symbol->string s))

(define (列表包含 lst elem)
  (if (member elem lst) #t #f))

(define (取前几个 lst n)
  (take lst n))

(define (去掉前几个 lst n)
  (drop lst n))

(define (符号判断 x)
  (symbol? x))

(define (列表判断 x)
  (list? x))

;; ==================== 扩展标准库函数 ====================

(define (随机整数 min max)
  (+ min (random (- max min -1))))

(define (绝对值 x)
  (abs x))

(define (最大值 . args)
  (apply max args))

(define (最小值 . args)
  (apply min args))

(define (整数开方 n)
  (integer-sqrt n))

(define (映射 fn lst)
  (map fn lst))

(define (过滤 pred lst)
  (filter pred lst))

(define (范围 start end)
  (range start end))

;; ==================== Python风格数学函数 ====================

(define (四舍五入 n [位数 0])
  (cond [(= 位数 0) (round n)]
        [else (let ([factor (expt 10 位数)])
                (/ (round (* n factor)) factor))]))

(define (开方 n)
  (sqrt n))

(define (求和 lst)
  (apply + lst))

(define (整除 a b)
  (quotient a b))

(define (向下取整 n)
  (floor n))

(define (向上取整 n)
  (ceiling n))

(define (十六进 n)
  (number->string n 16))

(define (八进制 n)
  (number->string n 8))

(define (二进制 n)
  (number->string n 2))

;; ==================== Python风格集合操作 ====================

(define (排序 lst)
  (sort lst <))

(define (全部 lst)
  (andmap (lambda (x) x) lst))

(define (枚举 lst)
  (for/list ([i (in-naturals)] [x lst])
    (list i x)))

(define (拉链 . lsts)
  (apply map list lsts))

(define (去重 lst)
  (remove-duplicates lst))

(define (扁平 lst)
  (flatten lst))

(define (输入 [提示 ""])
  (display 提示)
  (read-line))

;; ==================== 工具函数 ====================

(define (表示 x)
  (~v x))

(define (ascii表示 x)
  (~v x))

(define (格式化 value [spec #f])
  (cond
    [(not spec) (~v value)]
    [(equal? spec "b") (number->string value 2)]
    [(equal? spec "o") (number->string value 8)]
    [(equal? spec "x") (number->string value 16)]
    [(equal? spec "d") (number->string value 10)]
    [(equal? spec "f") (format "~a" (exact->inexact value))]
    [else (~v value)]))

(define (元组 . args)
  (list->vector args))

(define (复数 real [imag 0])
  (make-rectangular real imag))

(define (冻结集合 . args)
  (remove-duplicates args))

(define (读取文件 path)
  (file->string path))

(define (写入文件 path content)
  (call-with-output-file path #:exists 'replace
    (λ (p) (display content p))))

(define (商余 a b)
  (list (quotient a b) (remainder a b)))

(define (集合 . args)
  (remove-duplicates args))

(define (切片 start end [step 1])
  (range start end step))

;; ==================== 运算符重载机制 ====================

(define *运算符表* (make-hash))

(define (注册运算符 运算符名 类型谓词 实现)
  (hash-set! *运算符表* (list 运算符名 类型谓词) 实现))

(define (查找运算符 运算符名 参数)
  (define type-preds (hash-keys *运算符表*))
  (for/or ([key (in-list type-preds)])
    (when (and (equal? (car key) 运算符名)
               ((cadr key) 参数))
      (hash-ref *运算符表* key))))

(define-syntax-rule (重载运算符 运算符名 类型谓词 实现)
  (注册运算符 '运算符名 类型谓词 实现))

(define-syntax (加 stx)
  (syntax-case stx ()
    [(_ a b)
     #'(let ([a-val a] [b-val b])
         (cond
           [(查找运算符 '加 a-val) => (λ (proc) (proc a-val b-val))]
           [(查找运算符 '加 b-val) => (λ (proc) (proc a-val b-val))]
           [else (+ a-val b-val)]))]))

(define-syntax (减 stx)
  (syntax-case stx ()
    [(_ a b)
     #'(let ([a-val a] [b-val b])
         (cond
           [(查找运算符 '减 a-val) => (λ (proc) (proc a-val b-val))]
           [(查找运算符 '减 b-val) => (λ (proc) (proc a-val b-val))]
           [else (- a-val b-val)]))]))

(define-syntax (乘 stx)
  (syntax-case stx ()
    [(_ a b)
     #'(let ([a-val a] [b-val b])
         (cond
           [(查找运算符 '乘 a-val) => (λ (proc) (proc a-val b-val))]
           [(查找运算符 '乘 b-val) => (λ (proc) (proc a-val b-val))]
           [else (* a-val b-val)]))]))

(define-syntax (除 stx)
  (syntax-case stx ()
    [(_ a b)
     #'(let ([a-val a] [b-val b])
         (cond
           [(查找运算符 '除 a-val) => (λ (proc) (proc a-val b-val))]
           [(查找运算符 '除 b-val) => (λ (proc) (proc a-val b-val))]
           [else (/ a-val b-val)]))]))

;; ==================== 函数重载机制 ====================

(define *重载函数表* (make-hash))

(define (定义重载 函数名 参数数量 实现)
  (define key (list 函数名 参数数量))
  (hash-set! *重载函数表* key 实现))

(define (调用重载 函数名 . 参数)
  (define arg-count (length 参数))
  (define key (list 函数名 arg-count))
  (define impl (hash-ref *重载函数表* key #f))
  (if impl
      (apply impl 参数)
      (error '调用重载 (format "未找到函数 ~a 的 ~a 个参数的实现" 函数名 arg-count))))

;; ==================== 装饰器机制 ====================

(define-syntax (装饰器 stx)
  (syntax-case stx ()
    [(_ decorator-fn target-fn)
     #'(decorator-fn target-fn)]))