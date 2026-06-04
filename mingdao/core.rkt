#lang racket/base

;; 明道语言核心宏库
;; 提供基础语法转换

(require racket/list
         (rename-in racket/match (match 匹配))
         racket/control
         racket/format
         racket/string
         racket/file
         racket/generator
         racket/sequence
         racket/async-channel
         ffi/unsafe
         ffi/unsafe/define
         (for-syntax racket/base))

(provide 定义
         就是
         就是函
         如果
         那么
         否则
         否则若
         对于
         从
         到
         每个从
         返回
         跳出
         继续
         当满足
         列表
         列表修改
         消息拼接
         字典
         索引
         长度
         打印
         加
         减
         乘
         除
         模
         幂
         非
         不是
         与
         或
         拼接
         字符
         字符码
         字符串索引
         子字符串
         字符串长度
         字符串转列表
         列表转字符串
         是中文
         是数字
         是字母
         是空白
         是换行
         字符串前缀
         字符串后缀
         字符串包含
         反转
         数字转字符串
         字符串转数字
         报错
         是否相等
         任一
         追加多个
         前置
         去掉首个
         字符串转符号
         列表包含
         取前几个
         去掉前几个
         符号判断
         符号转字符串
         列表判断
         真值
         假值
         空值
         数大于
         数小于
         数大于等于
         数小于等于
         不等于
         随机整数
         绝对值
         最大值
         最小值
         整数开方
         映射
         过滤
         范围
         四舍五入
         开方
         求和
         整除
         向下取整
         向上取整
         十六进
         八进制
         二进制
         布尔值
         转字符串
         获取类型
         是整数
         是字符串
         是符号
         是字符
         是数
         是空
         排序
         全部
         枚举
         拉链
         去重
         扁平
         输入
         是浮点数
         大写
         小写
         替换
         去空格
         拆分
         连接
         查找
         计数
         重复字符串
         转整数
         转浮点数
         表示
         哈希
         标识
         是可调用
         商余
         集合
         切片
         ascii表示
         格式化
         元组
         复数
         冻结集合
         读取文件
         写入文件
         匹配
         匿名函数
         ;; 异常类型（用于 尝试/捕获）
         任意错误 类型错误 参数错误 变量错误 除零错误
         文件错误 读取错误 语法错误 用户错误
         ;; try-catch-finally
         尝试 捕获 始终
         ;; 生成器相关
         取第一个 转换列表 取前N个 生成器?
         generator yield
         ;; 接口/特质相关
         define-interface 实现 方法
         ;; Option/Maybe 类型
         无 有 是有值 取值 默认值 选项映射
         ;; 面向对象相关
         定义类 define-class 新建 自己
         ;; 异步/协程相关
         异步 等待 未来 未来? 完成未来 绑定未来)

(define classes (make-hasheq))

;; 内置运算符（直接映射到 Racket 运算符）
;; 注意：这些运算符现在支持重载，定义在文件末尾

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

;; 内置函数
(define (打印 x)
  (displayln x))

(define (索引 lst idx)
  (if (or (< idx 0) (>= idx (length lst)))
      '()
      (list-ref lst idx)))

(define-syntax 长度
  (syntax-rules ()
    [(_ lst) (length lst)]))

;; -------------------------------------------------------
;; 字符/字符串操作（为自举提供基础能力）
;; -------------------------------------------------------

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

(define (字符串包含 s substr)
  (if (string-contains? s substr) #t #f))

(define (反转 lst)
  (reverse lst))

(define (数字转字符串 n)
  (number->string n))

(define (字符串转数字 s)
  (string->number s))

(define (报错 msg)
  (raise-user-error msg))

(define (是否相等 a b)
  (equal? a b))

(define (符号判断 x)
  (symbol? x))

(define (列表判断 x)
  (list? x))

(define (数大于 a b)
  (> a b))

(define (数小于 a b)
  (< a b))

(define (数大于等于 a b)
  (>= a b))

(define (数小于等于 a b)
  (<= a b))

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

(define (不等于 a b)
  (not (equal? a b)))

(define (任一 . args)
  (ormap values args))

(define 真值 #t)
(define 假值 #f)
(define 空值 '())

(define (列表包含 lst elem)
  (if (member elem lst) #t #f))

(define (取前几个 lst n)
  (take lst n))

(define (去掉前几个 lst n)
  (drop lst n))

;; 这些关键字主要由 parser 处理
;; 这里提供占位符以便模块能正常加载
(define-syntax (定义 stx)
  (raise-syntax-error '定义 "此关键字应由解析器处理" stx))

(define-syntax (就是 stx)
  (raise-syntax-error '就是 "此关键字应由解析器处理" stx))

(define-syntax (就是函 stx)
  (raise-syntax-error '就是函 "此关键字应由解析器处理" stx))

(define-syntax (如果 stx)
  (raise-syntax-error '如果 "此关键字应由解析器处理" stx))

(define-syntax (那么 stx)
  (raise-syntax-error '那么 "此关键字应由解析器处理" stx))

(define-syntax (否则 stx)
  (raise-syntax-error '否则 "此关键字应由解析器处理" stx))

(define-syntax (否则若 stx)
  (raise-syntax-error '否则若 "此关键字应由解析器处理" stx))

(define-syntax (对于 stx)
  (raise-syntax-error '对于 "此关键字应由解析器处理" stx))

(define-syntax (从 stx)
  (raise-syntax-error '从 "此关键字应由解析器处理" stx))

(define-syntax (到 stx)
  (raise-syntax-error '到 "此关键字应由解析器处理" stx))

(define-syntax (每个从 stx)
  (raise-syntax-error '每个从 "此关键字应由解析器处理" stx))

(define-syntax (返回 stx)
  (raise-syntax-error '返回 "此关键字应由解析器处理" stx))

(define-syntax (匿名函数 stx)
  (raise-syntax-error '匿名函数 "此关键字应由解析器处理" stx))

(define-syntax (跳出 stx)
  (raise-syntax-error '跳出 "此关键字应由解析器处理" stx))

(define-syntax (继续 stx)
  (raise-syntax-error '继续 "此关键字应由解析器处理" stx))

(define-syntax (当满足 stx)
  (raise-syntax-error '当满足 "此关键字应由解析器处理" stx))

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

;; 可变参数拼接，用于多段字符串组合
(define (消息拼接 . args)
  (apply string-append (map (lambda (x) (if (string? x) x (format "~a" x))) args)))

(define-syntax 列表
  (syntax-rules ()
    [(_ . args) (list . args)]))

(define-syntax (字典 stx)
  (raise-syntax-error '字典 "此关键字应由解析器处理" stx))

;; ============================================================
;; 扩展标准库函数
;; ============================================================

;; 随机整数（闭区间）
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

;; ============================================================
;; Python 3.12 风格基础库 - 数学函数
;; ============================================================

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

;; ============================================================
;; Python 3.12 风格基础库 - 类型与转换
;; ============================================================

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

;; ============================================================
;; Python 3.12 风格基础库 - 集合操作
;; ============================================================

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

;; ============================================================
;; Python 3.12 风格基础库 - 输入输出
;; ============================================================

(define (输入 [提示 ""])
  (display 提示)
  (read-line))

;; ============================================================
;; Python 3.12 风格基础库 - 字符串方法
;; ============================================================

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

(define (字符串后缀 s suffix)
  (string-suffix? s suffix))

;; ============================================================
;; Python 3.12 风格基础库 - 类型转换
;; ============================================================

(define (转整数 x)
  (cond [(integer? x) x]
        [(number? x) (inexact->exact (floor x))]
        [(string? x) (string->number x)]
        [else (error 转整数 "无法转换为整数: ~a" x)]))

(define (转浮点数 x)
  (cond [(number? x) (exact->inexact x)]
        [(string? x) (string->number x)]
        [else (error 转浮点数 "无法转换为浮点数: ~a" x)]))

;; ============================================================
;; Python 3.12 风格基础库 - 工具函数
;; ============================================================

(define (表示 x)
  (~v x))

(define (哈希 x)
  (equal-hash-code x))

(define (标识 x)
  (equal-hash-code x))

(define (是可调用 x)
  (procedure? x))

(define (商余 a b)
  (list (quotient a b) (remainder a b)))

(define (集合 . args)
  (remove-duplicates args))

(define (切片 start end [step 1])
  (range start end step))

;; ============================================================
;; Python 3.12 风格基础库 - 新增内置函数
;; ============================================================

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

;; ============================================================
;; 异常类型谓词（用于 尝试/捕获）
;; ============================================================
(define (任意错误 e) (exn:fail? e))
(define (类型错误 e) (exn:fail:contract? e))
(define (参数错误 e) (exn:fail:contract:arity? e))
(define (变量错误 e) (exn:fail:contract:variable? e))
(define (除零错误 e) (exn:fail:contract:divide-by-zero? e))
(define (文件错误 e) (exn:fail:filesystem? e))
(define (读取错误 e) (exn:fail:read? e))
(define (语法错误 e) (exn:fail:syntax? e))
(define (用户错误 e) (exn:fail:user? e))

;; ============================================================
;; 尝试/捕获/始终 - 运行时宏
;; ============================================================
(define-syntax (尝试 stx)
  (syntax-case stx (捕获 始终)
    ;; 有 始终 分支
    [(_ body (捕获 type var hbody) ... (始终 fbody))
     #'(let/ec return
         (with-handlers
           ([type (λ (var) (let ([v hbody]) fbody (return v)))] ...
            [exn:fail? (λ (e) fbody (raise e))])
           (let ([v body])
             fbody
             (return v))))]
    ;; 无 始终 分支
    [(_ body (捕获 type var hbody) ...)
     #'(with-handlers
         ([type (λ (var) hbody)] ...)
         body)]))

(define-syntax (捕获 stx)
  (raise-syntax-error '捕获 "此关键字应由解析器处理" stx))

(define-syntax (始终 stx)
  (raise-syntax-error '始终 "此关键字应由解析器处理" stx))

;; ============================================================
;; 生成器相关函数
;; ============================================================

(define (取第一个 gen)
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (define v (gen))
    (if (void? v) #f v)))

(define (转换列表 gen)
  (let loop ()
    (with-handlers ([exn:fail? (lambda (e) '())])
      (define v (gen))
      (if (void? v)
          '()
          (cons v (loop))))))

(define (取前N个 n gen)
  (let loop ([i 0])
    (if (= i n)
        '()
        (with-handlers ([exn:fail? (lambda (e) '())])
          (let ([v (gen)])
            (if (void? v)
                '()
                (cons v (loop (add1 i)))))))))

(define (生成器? x)
  (procedure? x))

;; ============================================================
;; 接口/特质相关宏
;; ============================================================

(define interfaces (make-hash))

(define-syntax (define-interface stx)
  (syntax-case stx ()
    [(_ name methods)
     #'(hash-set! interfaces 'name (map car 'methods))]))

(define-syntax (实现 stx)
  (raise-syntax-error '实现 "此关键字应由解析器处理" stx))

(define-syntax (方法 stx)
  (raise-syntax-error '方法 "此关键字应由解析器处理" stx))

;; ============================================================
;; Option/Maybe 类型
;; ============================================================

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

;; ============================================================
;; 面向对象 - 类和对象
;; ============================================================

(define (定义类 name fields methods)
  (hash-set! classes name (list fields methods))
  (void))

(define-syntax (define-class stx)
  (syntax-case stx ()
    [(_ name fields methods)
     (let ([name-stx #'name])
       (with-syntax ([class-symbol (datum->syntax name-stx (string->symbol (format "'~a" (syntax-e name-stx))))])
         #'(hash-set! classes class-symbol (list fields methods))))]))

(define (新建 class-name . args)
  (define actual-class-name class-name)
  (define class-info (hash-ref classes actual-class-name #f))
  (unless class-info
    (error '新建 (format "类 '~a' 未定义" actual-class-name)))
  (define fields (first class-info))
  (define methods (second class-info))
  (define obj (make-hasheq))
  (for ([field fields])
    (hash-set! obj (first field) (eval (second field))))
  obj)

(define 自己 #f)

;; ============================================================
;; 异步/协程 - Future/Promise 实现
;; ============================================================

(struct 未来 (channel result done? mutex) #:mutable)

(define (是未来? obj)
  (未来? obj))

(define (创建未来)
  (未来 (make-async-channel) #f #f (make-semaphore 1)))

(define (完成未来 fut value)
  (call-with-semaphore (未来-mutex fut)
    (lambda ()
      (unless (未来-done? fut)
        (async-channel-put (未来-channel fut) value)
        (set-未来-result! fut value)
        (set-未来-done?! fut #t)))))

(define (绑定未来 fut callback)
  (thread
    (lambda ()
      (define result (async-channel-get (未来-channel fut)))
      (callback result))))

(define-syntax 异步
  (syntax-rules ()
    [(_ body ...)
     (let ([fut (创建未来)])
       (thread
         (lambda ()
           (define result (begin body ...))
           (完成未来 fut result)))
       fut)]))

(define (等待 fut)
  (if (未来-done? fut)
      (未来-result fut)
      (async-channel-get (未来-channel fut))))

(define-syntax-rule (等待* expr)
  (等待 expr))

;; ============================================================
;; 运算符重载机制
;; ============================================================

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

(provide 重载运算符
         结构 新建结构 字段
         定义重载 调用重载
         装饰器)

;; ============================================================
;; 命名结构体机制
;; ============================================================

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

;; ============================================================
;; 函数重载机制
;; ============================================================

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

(define-syntax (定义重载宏 stx)
  (syntax-case stx ()
    [(_ name (arg ...) body)
     (let ([arg-count (length (syntax->list #'(arg ...)))])
       #'(定义重载 'name arg-count (lambda (arg ...) body)))]))

;; ============================================================
;; 装饰器机制
;; ============================================================

(define-syntax (装饰器 stx)
  (syntax-case stx ()
    [(_ decorator-fn target-fn)
     #'(decorator-fn target-fn)]))
