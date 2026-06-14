#lang racket/base

;; 明道语言分词器
;; 实现零 NLP 依赖的纯规则分词

(require racket/list
         racket/string
         racket/match)

(provide tokenize
         token-type
         token-value
         token-line
         token-col
         ;; 导出关键字分类供其他模块使用
         控制流关键字
         声明关键字
         数据结构关键字
         内置函数关键字
         比较关键字
         特殊值关键字
         管道关键字
         单字关键字
         四字关键字
         三字关键字
         双字关键字
         单字运算符
         所有函数名)

;; Token 结构
(struct token (type value line col) #:transparent)

;; ============================================================
;; 明道语言关键字统一管理
;; ============================================================

;; 控制流关键字（用于语句控制）
(define 控制流关键字
  '("定义" "常量" "如果" "那么" "否则" "对于" "跳出" "继续" "返回"
    "导入" "导出" "模块" "赋值" "尝试" "捕获" "匹配" "始终"
    "或" "开始" "结束" "产出" "接口" "实现" "方法" "类" "自己" "属性" "异步" "等待" "未来"
    "引用" "执行"))

;; 声明关键字（双字）
(define 声明关键字
  '("就是" "类型"))

;; 循环关键字
(define 循环关键字
  '("对于" "从" "到" "经过" "做" "当"))

;; 条件关键字
(define 条件关键字
  '("如果" "那么" "否则"))

;; 数据结构关键字（用于创建数据）
(define 数据结构关键字
  '("列表" "元组" "字典"))

;; 内置函数关键字（函数名，可用于表达式）
(define 内置函数关键字
  '("打印" "索引" "长度" "生成" "捕获" "任意" "新建" "结构"))

;; 比较运算符关键字
(define 比较关键字
  '("等于" "不等" "大于" "小于"))

;; 特殊值关键字
(define 特殊值关键字
  '("真值" "假值" "空值"))

;; 管道分隔符
(define 管道关键字
  '("然后"))

;; 单字关键字
(define 单字关键字
  '("从" "到" "为" "类"))

;; ============================================================
;; 派生关键字列表（用于分词器匹配）
;; ============================================================

;; 四字关键字
(define 四字关键字
  '("大于等于" "小于等于" "对于每个" "匿名函数" "做当满足" "外部函数"))

;; 三字关键字
(define 三字关键字
  '("就是函" "就是宏" "否则若" "当满足" "定义宏" "不等于" "重载运算符" "定义重载"))

;; 强制拆分的双字关键字（永远不会作为复合标识符的一部分）
(define 强制拆分关键字
  (append 控制流关键字 声明关键字))
(define 双字关键字
  (remove-duplicates
   (append 控制流关键字
           声明关键字
           数据结构关键字
           内置函数关键字
           比较关键字
           特殊值关键字
           管道关键字)))

;; 算术运算符
(define 算术运算符
  '("加" "减" "乘" "除" "模" "幂"))

;; 逻辑运算符
(define 逻辑运算符
  '("非" "与" "或"))

;; 所有运算符（用于分词）
(define 单字运算符
  (append 算术运算符 逻辑运算符))

;; 所有函数名（用于解析器判断）
(define 所有函数名
  (append 内置函数关键字
          算术运算符
          逻辑运算符
          '("列表修改" "消息拼接" "断言" "跟踪" "检查" "检查列表" "断点"
            "调试输出" "记录" "调用堆栈"
            "测试" "测试组" "断言测试" "断言相等"
            "断言不等" "断言异常" "运行测试"
            "引用" "执行")))

;; 判断是否为中文字符
(define (chinese-char? ch)
  (and (char? ch)
       (let ([cp (char->integer ch)])
         (or (and (>= cp #x4E00) (<= cp #x9FFF))     ;; CJK 统一汉字
             (and (>= cp #x3400) (<= cp #x4DBF))     ;; CJK 扩展A
             (and (>= cp #x20000) (<= cp #x2A6DF))   ;; CJK 扩展B
             (and (>= cp #x2A700) (<= cp #x2B73F))   ;; CJK 扩展C
             (and (>= cp #x2B740) (<= cp #x2B81F))   ;; CJK 扩展D
             (and (>= cp #x2B820) (<= cp #x2CEAF)))))) ;; CJK 扩展E

;; 判断是否为空白字符
(define (空白? ch)
  (or (char=? ch #\space)
      (char=? ch #\tab)))

;; 判断是否为换行符
(define (newline-char? ch)
  (char=? ch #\newline))

;; 分词主函数
(define (tokenize input)
  (define chars (string->list input))
  (define pos 0)
  (define line 1)
  (define col 1)
  (define indent-stack '(0))  ;; 缩进栈，初始为0
  
  (define (peek [offset 0])
    (if (< (+ pos offset) (length chars))
        (list-ref chars (+ pos offset))
        #f))
  
  (define (advance)
    (set! pos (add1 pos))
    (set! col (add1 col)))
  
  (define (advance-line)
    (set! pos (add1 pos))
    (set! line (add1 line))
    (set! col 1)
    ;; 跳过 \r\n 中的 \n (Windows CRLF)
    (when (and (peek) (char=? (peek) #\newline) (char=? (list-ref chars (sub1 pos)) #\return))
      (set! pos (add1 pos))))
  
  (define (skip-whitespace)
    (when (and (peek) (空白? (peek)))
      (advance)
      (skip-whitespace)))
  
  (define (read-string quote-char)
    ;; 读取字符串字面量
    (define start-line line)
    (define start-col col)
    (define chars '())
    (advance)  ;; 跳过起始引号
    (let loop ()
      (let ([ch (peek)])
        (cond
          [(not ch) (error "未闭合的字符串")]
          [(char=? ch quote-char)
           (advance)
           (token 'STRING (list->string (reverse chars)) start-line start-col)]
          [(char=? ch #\\)
           (advance)
           (let ([escaped (peek)])
             (advance)
             (set! chars (cons (case escaped
                                 [(#\n) #\newline]
                                 [(#\t) #\tab]
                                 [(#\\) #\\]
                                 [(#\") #\"]
                                 [(#\') #\']
                                 [else escaped])
                               chars))
             (loop))]
          [else
           (set! chars (cons ch chars))
           (advance)
           (loop)]))))
  
  ;; 读取 f-string（字符串插值）
  ;; f"text {expr} text" → 有插值时返回 FSTRING，段格式始终为 字面/表达式/字面/表达式/字面
  ;; 无插值时返回普通 STRING token
  (define (read-fstring quote-char)
    (define start-line line)
    (define start-col (sub1 col))
    (define segments '())  ;; 始终以字面量开头和结尾
    (define current-chars '())
    (define brace-depth 0)
    (define has-interpolation? #f)
    (advance)  ;; 跳过起始引号
    
    (define (flush-current-chars)
      (set! segments (cons (list->string (reverse current-chars)) segments))
      (set! current-chars '()))
    
    (let loop ()
      (let ([ch (peek)])
        (cond
          [(not ch) (error 'tokenize "未闭合的 f-string")]
          [(and (char=? ch quote-char) (= brace-depth 0))
           (advance)
           (flush-current-chars)
           (if has-interpolation?
               ;; 有插值：返回 FSTRING，段格式为 字面/表达式/字面/.../字面
               (token 'FSTRING (reverse segments) start-line start-col)
               ;; 无插值：段列表只有一个元素，提取为普通字符串
               (let ([content (car (reverse segments))])
                 (token 'STRING content start-line start-col)))]
          ;; 转义大括号 {{ → 字面 {
          [(and (char=? ch #\{) (peek 1) (char=? (peek 1) #\{) (= brace-depth 0))
           (advance)  ;; 跳过第一个 {
           (advance)  ;; 跳过第二个 {
           (set! current-chars (cons #\{ current-chars))
           (loop)]
          ;; 转义大括号 }} → 字面 }
          [(and (char=? ch #\}) (peek 1) (char=? (peek 1) #\}) (= brace-depth 0))
           (advance)
           (advance)
           (set! current-chars (cons #\} current-chars))
           (loop)]
          ;; 进入插值表达式 { ... }
          [(and (char=? ch #\{) (= brace-depth 0))
           (flush-current-chars)
           (set! has-interpolation? #t)
           (set! brace-depth 1)
           (advance)
           (define expr-chars '())
           (let expr-loop ()
             (let ([expr-ch (peek)])
               (cond
                 [(not expr-ch) (error 'tokenize "f-string 中未闭合的 {")]
                 [(char=? expr-ch #\})
                  (set! brace-depth 0)
                  (advance)
                  (set! segments (cons (list->string (reverse expr-chars)) segments))
                  (loop)]
                 [else
                  (set! expr-chars (cons expr-ch expr-chars))
                  (advance)
                  (expr-loop)])))]
          ;; 嵌套大括号计数（{ 在表达式中）
          [(char=? ch #\{)
           (set! brace-depth (add1 brace-depth))
           (set! current-chars (cons ch current-chars))
           (advance)
           (loop)]
          [(char=? ch #\})
           (set! brace-depth (sub1 brace-depth))
           (set! current-chars (cons ch current-chars))
           (advance)
           (loop)]
          ;; 转义字符
          [(char=? ch #\\)
           (advance)
           (let ([escaped (peek)])
             (advance)
             (set! current-chars (cons (case escaped
                                         [(#\n) #\newline]
                                         [(#\t) #\tab]
                                         [(#\\) #\\]
                                         [(#\") #\"]
                                         [(#\{) #\{]
                                         [else escaped])
                                       current-chars))
             (loop))]
          [else
           (set! current-chars (cons ch current-chars))
           (advance)
           (loop)]))))
  
  (define (read-number first-char)
    ;; 读取数字
    (define start-line line)
    (define start-col (sub1 col))
    (define chars (list first-char))
    (let loop ()
      (let ([ch (peek)])
        (cond
          [(and ch (or (char-numeric? ch) (char=? ch #\.)))
           (set! chars (cons ch chars))
           (advance)
           (loop)]
          [else
           (token 'NUMBER (string->number (list->string (reverse chars))) start-line start-col)]))))
  
  ;; 辅助函数：检查字符是否可能是关键字/运算符的开头
  (define (could-start-keyword? ch)
    (and (char? ch)
         (ormap (λ (kw) (char=? (string-ref kw 0) ch))
                (append 双字关键字 三字关键字 四字关键字 单字关键字 单字运算符))))
  
  ;; 辅助函数：检查从当前位置能否构成完整关键字
  ;; 返回关键字长度，如果不能构成则返回 #f
  (define (can-form-keyword? first-ch [peek-offset 0])
    (and (char? first-ch)
         (let ([next1 (peek (+ 1 peek-offset))]
               [next2 (peek (+ 2 peek-offset))]
               [next3 (peek (+ 3 peek-offset))])
           ;; 尝试匹配四字关键字
           (cond
             [(and next1 next2 next3
                   (member (string first-ch next1 next2 next3) 四字关键字))
              4]
             ;; 尝试匹配三字关键字
             [(and next1 next2
                   (member (string first-ch next1 next2) 三字关键字))
              3]
             ;; 尝试匹配双字关键字
             [(and next1
                   (member (string first-ch next1) 双字关键字))
              2]
             ;; 尝试匹配单字关键字
             [(member (string first-ch) 单字关键字)
              1]
             ;; 尝试匹配运算符
             [(and next1
                   (member (string first-ch next1) 单字运算符))
              2]
             [(member (string first-ch) 单字运算符)
              1]
             [else #f]))))
  
  ;; boundary-keywords（到达这些关键字时标识符停止，让主循环处理）
;; 包括控制流、声明、循环、条件、比较、管道等结构性关键字
;; 不包括内置函数名关键字（如"索引""长度"）和数据结构关键字（如"列表"）
;; 这些函数名关键字可以作为复合标识符的组成部分（如"字符串索引""列表转字符串"）
(define boundary-keywords
  (remove-duplicates
   (append 控制流关键字 声明关键字 单字关键字
           循环关键字 条件关键字 比较关键字
           管道关键字 单字运算符)))

;; 标识符内部读取时使用的边界关键字（更小集合）
;; 仅包含在标识符中间出现时需要拆分的关键字
;; 控制流关键字（定义、如果等）由主循环处理，不作为内部边界
(define 标识符读边界关键字
  '("就是" "从" "到" "为" "然后" "经过" "大于" "小于" "等于" "不等" "那么"))

;; 检查从当前位置能否构成boundary-keywords
(define (boundary-keyword? first-ch)
  (and (char? first-ch)
       (let ([next1 (peek 1)]
             [next2 (peek 2)]
             [next3 (peek 3)])
         (or
           ;; 单字关键字/运算符（"从""到""为""加""减"等）
           (member (string first-ch) (append 单字关键字 单字运算符))
           ;; 四字关键字
           (and next1 next2 next3
                (member (string first-ch next1 next2 next3) 四字关键字))
           ;; 三字关键字
           (and next1 next2
                (member (string first-ch next1 next2) 三字关键字))
           ;; 双字关键字（仅读boundary-keywords，不包含主循环处理的控制流关键字）
           (and next1
                (member (string first-ch next1) 标识符读边界关键字))))))

(define (read-identifier first-char)
    ;; 读取标识符（可能包含多个中文字符）
    ;; 贪心读取所有连续的中文字符和字母数字字符
    ;; 单字运算符（加、减、乘、除等）在标识符中间时作为标识符一部分继续读入，
    ;; 避免复合函数名（如"追加多个""取前几个"等）被错误拆分。
    ;; 主循环已经处理了关键字/运算符的边界检测。
    (define start-line line)
    (define start-col (sub1 col))
    (define chars (list first-char))
    
    (let loop ()
      (let ([ch (peek)])
        (cond
          ;; 单字运算符和单字关键字（加、减、乘、除、非、与、或、从、到、为等）作为标识符一部分继续读入
          ;; 因为read-identifier只在首字符不是运算符/关键字时被调用，
          ;; 后续遇到的运算符/关键字字符属于复合函数名的一部分
          [(and ch (chinese-char? ch) (or (member (string ch) 单字运算符)
                                  (member (string ch) 单字关键字)))
           (set! chars (cons ch chars))
           (advance)
           (loop)]
          ;; 普通中文字符，继续读入（先于边界关键字检查，避免单字运算符如"为"被误判为边界）
          [(and ch (chinese-char? ch) (not (boundary-keyword? ch)))
           (set! chars (cons ch chars))
           (advance)
           (loop)]
          ;; boundary-keywords（如"就是""从""到"）→ 停止，留给主循环处理
          [(and ch (chinese-char? ch) (boundary-keyword? ch))
           (token 'IDENTIFIER (list->string (reverse chars)) start-line start-col)]
          ;; 英文/数字/下划线/连字符/斜杠
          [(and ch (or (char-alphabetic? ch) (char-numeric? ch) (char=? ch #\_) (char=? ch #\-) (char=? ch #\/)))
           (set! chars (cons ch chars))
           (advance)
           (loop)]
          [else
           (token 'IDENTIFIER (list->string (reverse chars)) start-line start-col)]))))
  
  (define (compute-indent-level)
    ;; 计算当前行的缩进级别（空格数）
    (define saved-pos pos)
    (define saved-col col)
    (define spaces 0)
    (set! col 1)
    (let loop ()
      (let ([ch (peek)])
        (cond
          [(and ch (空白? ch))
           (set! spaces (add1 spaces))
           (advance)
           (loop)]
          [else
           (set! pos saved-pos)
           (set! col saved-col)
           spaces]))))
  
  (define tokens '())
  
  (let main-loop ()
    (let ([ch (peek)])
      (cond
        ;; 文件结束
        [(not ch) 
         ;; 生成剩余的 DEDENT token
         (for ([_ (in-range (sub1 (length indent-stack)))])
           (set! tokens (cons (token 'DEDENT #f line col) tokens)))
         (reverse tokens)]
        
        ;; 换行符
        [(newline-char? ch)
         (advance-line)
         ;; 生成 NEWLINE token 来分隔语句
         (set! tokens (cons (token 'NEWLINE #f line col) tokens))
         ;; 检查缩进变化
         (let ([new-indent (compute-indent-level)]
               [current-indent (car indent-stack)])
           (cond
             [(> new-indent current-indent)
              ;; 缩进增加，生成 INDENT token
              (set! indent-stack (cons new-indent indent-stack))
              (set! tokens (cons (token 'INDENT #f line col) tokens))]
             [(< new-indent current-indent)
              ;; 缩进减少，生成 DEDENT token
              (let dedent-loop ()
                (when (< new-indent (car indent-stack))
                  (set! indent-stack (cdr indent-stack))
                  (set! tokens (cons (token 'DEDENT #f line col) tokens))
                  (dedent-loop)))]))
         (main-loop)]
        
        ;; 空白字符
        [(空白? ch)
         (advance)
         (main-loop)]
        
        ;; 回车符（Windows CRLF 的 \r）
        [(char=? ch #\return)
         (advance)
         (main-loop)]
        
        ;; 注释（# 和 ;）
        [(or (char=? ch #\#) (char=? ch #\;))
         ;; 跳过到行尾
         (let comment-loop ()
           (let ([next (peek)])
             (when (and next (not (newline-char? next)))
               (advance)
               (comment-loop))))
         (main-loop)]
        
        ;; f-string（插值字符串）：f"..."
        [(and (char=? ch #\f) (peek 1) (char=? (peek 1) #\"))
         (advance)  ;; 跳过 f
         (set! tokens (cons (read-fstring #\") tokens))
         (main-loop)]
        
        ;; F-string（大写版本）：F"..."
        [(and (char=? ch #\F) (peek 1) (char=? (peek 1) #\"))
         (advance)
         (set! tokens (cons (read-fstring #\") tokens))
         (main-loop)]
        
        ;; 字符串
        [(char=? ch #\")
         (set! tokens (cons (read-string ch) tokens))
         (main-loop)]
        
        ;; 单引号（quote）用于创建符号
        [(char=? ch #\')
         (advance)
         (set! tokens (cons (token 'QUOTE #\' line col) tokens))
         (main-loop)]
        
        ;; 装饰器符号 @
        [(char=? ch #\@)
         (advance)
         (set! tokens (cons (token 'AT #\@ line col) tokens))
         (main-loop)]
        
        ;; 数字
        [(char-numeric? ch)
         (advance)
         (set! tokens (cons (read-number ch) tokens))
         (main-loop)]
        
        ;; 中文（可能是关键字或标识符）
        [(chinese-char? ch)
         (advance)
         ;; 尝试匹配四字关键字
         (let* ([potential-four-char (string ch (or (peek) #\space) (or (peek 1) #\space) (or (peek 2) #\space))]
                [potential-three-char (string ch (or (peek) #\space) (or (peek 1) #\space))]
                [potential-two-char (string ch (or (peek) #\space))])
           (cond
             ;; 四字关键字（如"大于等于"）
             [(member potential-four-char 四字关键字)
              (advance)  ;; 消耗第二个字符
              (advance)  ;; 消耗第三个字符
              (advance)  ;; 消耗第四个字符
              (set! tokens (cons (token 'KEYWORD potential-four-char line (- col 3)) tokens))]
             
             ;; 三字关键字（如"就是函"）
             [(member potential-three-char 三字关键字)
              (advance)  ;; 消耗第二个字符
              (advance)  ;; 消耗第三个字符
              (set! tokens (cons (token 'KEYWORD potential-three-char line (- col 2)) tokens))]
             
             ;; 双字关键字
             ;; boundary-keywords（控制流、声明、比较、管道、运算符等）无条件拆分
             ;; 非边界双字关键字（索引、长度、列表等）检查第三个字符是否中文且不能构成关键字，若是则合并为标识符
             [(member potential-two-char 双字关键字)
              (if (member potential-two-char boundary-keywords)
                  ;; 边界关键字：无条件拆分
                  (begin
                    (advance)
                    (set! tokens (cons (token 'KEYWORD potential-two-char line (- col 1)) tokens)))
                  ;; 非边界双字关键字（索引、长度、列表等）：检查是否需要合并
                  (let ([third-char (peek 1)])
                    (if (and third-char (chinese-char? third-char)
                             (not (can-form-keyword? third-char 1)))
                        (set! tokens (cons (read-identifier ch) tokens))
                        (begin
                          (advance)
                          (set! tokens (cons (token 'KEYWORD potential-two-char line (- col 1)) tokens))))))]
             
             ;; 单字关键字（边界由read-identifier处理）
             [(member (string ch) 单字关键字)
              (set! tokens (cons (token 'KEYWORD (string ch) line col) tokens))]
             
             ;; 双字运算符（无条件匹配，边界由read-identifier处理）
             [(member potential-two-char 单字运算符)
              (advance)
              (set! tokens (cons (token 'OPERATOR potential-two-char line (- col 1)) tokens))]
             
             ;; 单字运算符
             ;; 算术运算符后跟中文且不构成关键字，可能是复合标识符（如"追加多个"）
             [(member (string ch) 单字运算符)
              (let ([next (peek)])
                (if (and next (chinese-char? next) (not (can-form-keyword? next))
                         (member (string ch) 算术运算符))  ;; 仅算术运算符参与复合
                    (set! tokens (cons (read-identifier ch) tokens))
                    (set! tokens (cons (token 'OPERATOR (string ch) line col) tokens))))]
             
             ;; 普通标识符
             [else
              (set! tokens (cons (read-identifier ch) tokens))]))
         (main-loop)]
        
        ;; 标点符号（英文和中文）
        [(char=? ch #\:)
         (advance)
         (set! tokens (cons (token 'COLON #\: line col) tokens))
         (main-loop)]
        
        [(char=? ch #\：)
         (advance)
         (set! tokens (cons (token 'COLON #\: line col) tokens))
         (main-loop)]
        
        [(or (char=? ch #\,) (char=? ch #\，))
         (advance)
         (set! tokens (cons (token 'COMMA ch line col) tokens))
         (main-loop)]
        
        ;; 三元表达式运算符
        [(char=? ch #\?)
         (advance)
         (set! tokens (cons (token 'OPERATOR "?" line col) tokens))
         (main-loop)]
        
        ;; 赋值运算符 =
        [(char=? ch #\=)
         (advance)
         (set! tokens (cons (token 'OPERATOR "=" line col) tokens))
         (main-loop)]
        
        ;; 管道符号 |
        [(char=? ch #\|)
         (advance)
         (set! tokens (cons (token 'PIPE #\| line col) tokens))
         (main-loop)]
        
        ;; 泛型尖括号 < >
        [(char=? ch #\<)
         (advance)
         (set! tokens (cons (token 'LEFT_ANGLE #\< line col) tokens))
         (main-loop)]
        
        [(char=? ch #\>)
         (advance)
         (set! tokens (cons (token 'RIGHT_ANGLE #\> line col) tokens))
         (main-loop)]
        
        [(char=? ch #\。)
         (advance)
         (set! tokens (cons (token 'DOT #\。 line col) tokens))
         (main-loop)]
        
        ;; 括号支持（半角和全角）
        [(or (char=? ch #\() (char=? ch #\（))
         (advance)
         (set! tokens (cons (token 'LPAREN '() line col) tokens))
         (main-loop)]
        [(or (char=? ch #\)) (char=? ch #\）))
         (advance)
         (set! tokens (cons (token 'RPAREN '() line col) tokens))
         (main-loop)]
        [(char=? ch #\[)
         (advance)
         (set! tokens (cons (token 'LBRACKET #\[ line col) tokens))
         (main-loop)]
        [(char=? ch #\])
         (advance)
         (set! tokens (cons (token 'RBRACKET #\] line col) tokens))
         (main-loop)]
        
        ;; 其他字符（英文标识符等，包含中英文混合）
        [(or (char-alphabetic? ch) (char=? ch #\_))
         (advance)
         (let* ([start-col col]
                [chars (list ch)])
           (let ident-loop ()
             (let ([next (peek)])
               (cond
                 ;; 单字运算符和单字关键字（加、减、从、到、为等）作为标识符一部分继续读入
                 ;; 允许复合函数名（如"追加多个"）包含运算符
                 [(and next (chinese-char? next) (or (member (string next) 单字运算符)
                                              (member (string next) 单字关键字)))
                  (set! chars (cons next chars))
                  (advance)
                  (ident-loop)]
                 ;; boundary-keywords（单字/多字关键字）→ 停止，留给主循环处理
                 [(and next (chinese-char? next) (boundary-keyword? next))
                  (void)]
                 ;; 普通中文字符，继续读入
                 [(and next (chinese-char? next))
                  (set! chars (cons next chars))
                  (advance)
                  (ident-loop)]
                 ;; 英文/数字/下划线/连字符/斜杠 → 继续读入
                 [(and next (not (chinese-char? next)) (or (char-alphabetic? next) (char-numeric? next) (char=? next #\_) (char=? next #\-) (char=? next #\/)))
                  (set! chars (cons next chars))
                  (advance)
                  (ident-loop)]
                 [else (void)])))
           (set! tokens (cons (token 'IDENTIFIER (list->string (reverse chars)) line start-col) tokens)))
          (main-loop)]
        
        [else
         (let* ([字符描述 (cond
                            [(and (char>=? ch #\space) (char<=? ch #\~))
                             (format "'~a'（ASCII码: ~a）" ch (char->integer ch))]
                            [(chinese-char? ch)
                             (format "'~a'（中文字符）" ch)]
                            [else
                             (format "'~a'（Unicode码点: ~a）" ch (char->integer ch))])]
                [建议 (cond
                        [(or (char=? ch #\") (char=? ch #\'))
                         "\n提示：请检查字符串引号是否成对出现"]
                        [(char=? ch #\()
                         "\n提示：请检查括号是否成对"]
                        [else
                         (format "\n提示：明道语言暂不支持此字符，请检查拼写或使用中文关键字")])])
           (error 'tokenize
                  (format "无法识别的字符: ~a（第 ~a 行，第 ~a 列）~a"
                          字符描述 line col 建议)))]))))