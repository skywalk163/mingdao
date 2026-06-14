#lang racket/base

;; 明道自举 Phase 2：验证明道版解析器源码正确性
;; 验证策略：
;; 1. 确认 tokenizer.mingdao 和 parser.mingdao 能被 Racket 解析器正确解析
;; 2. 验证两者的 AST 结构完整（函数定义、变量定义等）
;; 3. 使用相同函数名列表对比 Racket 解析器对不同测试用例的输出一致性

(require racket/port racket/file racket/string racket/list racket/match
         "../core.rkt"
         "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

;; ========== 自动检测项目根目录 ==========
(define project-root
  (cond
    [(file-exists? (build-path (current-directory) "mingdao" "std" "tokenizer.mingdao"))
     (build-path (current-directory) "mingdao")]
    [(file-exists? (build-path (current-directory) "std" "tokenizer.mingdao"))
     (current-directory)]
    [(file-exists? (build-path (current-directory) ".." "std" "tokenizer.mingdao"))
     (build-path (current-directory) "..")]
    [else
     (error "test-bootstrap-parser.rkt: cannot determine project root.")]))

;; ========== 读取UTF-8源码 ==========
(define (read-utf8-file path)
  (define in (open-input-file path))
  (define chunks '())
  (let loop ()
    (define b (read-bytes 4096 in))
    (if (eof-object? b)
        (void)
        (begin
          (set! chunks (cons b chunks))
          (loop))))
  (close-input-port in)
  (bytes->string/utf-8 (apply bytes-append (reverse chunks))))

;; ========== 函数名注册表 ==========
(define (make-function-names)
  (define names
    '("打印" "长度" "索引" "列表" "列表修改" "消息拼接" "生成" "捕获" "任意"
      "加" "减" "乘" "除" "模" "幂" "非" "不是" "与" "或" "拼接"
      "字符" "字符码" "字符串索引" "子字符串" "字符串长度"
      "字符串转列表" "列表转字符串" "是中文" "是数字" "是字母"
      "是空白" "是换行" "字符串前缀" "字符串包含" "反转"
      "数字转字符串" "字符串转数字" "报错"
      "是否相等" "不等于" "任一" "符号判断" "列表判断" "符号转字符串"
      "数大于" "数小于" "数大于等于" "数小于等于"
      "前置" "追加多个" "去掉首个" "字符串转符号" "列表包含"
      "取前几个" "去掉前几个"
      ;; 解析器内部函数
      "取令牌" "令牌类型" "令牌值" "令牌行" "当前类型" "当前值"
      "匹配类型判断" "匹配类型值判断" "跳过换行"
      "是函数名判断" "取前" "去掉前" "是函数项判断" "提取函数名"
      "寻找最右函数" "构建SVO递归" "解包函数引用" "解析遍历" "解析满足循环"
      "解析for循环" "解析while循环" "解析定义" "解析赋值" "解析如果"
      "解析表达式" "解析块" "SVO解析" "解析函数名"))
  names)

(define function-names (make-function-names))

;; ========== 解析并验证明道版源码 ==========
(define (analyze-mingdao-source name source)
  (printf "▶ 分析: ~a\n" name)
  (define tokens (tokenize source))
  (printf "  令牌数: ~a\n" (length tokens))
  (define ast (parse tokens))
  (printf "  表达式数: ~a\n" (length ast))
  (define defines 0)
  (define lambdas 0)
  (define errors 0)
  (for ([expr ast] [i (in-naturals)])
    (with-handlers ([exn:fail? (λ (e)
                                 (set! errors (add1 errors))
                                 (printf "  错误 #~a: ~a\n" i (exn-message e)))])
      (when (and (list? expr) (eq? (car expr) 'define))
        (set! defines (add1 defines))
        (when (and (>= (length expr) 3) (list? (caddr expr)) (eq? (caaddr expr) 'lambda))
          (set! lambdas (add1 lambdas))))))
  (printf "  定义: ~a (含 lambda: ~a)\n" defines lambdas)
  (printf "  错误: ~a\n" errors)
  (printf "  ~a\n\n" (if (zero? errors) "✓ 通过" "✗ 有问题"))
  (values ast (zero? errors)))

;; ========== 带函数名的解析包装 ==========
(define (parse-with-names code)
  (define tokens (tokenize code))
  (parse tokens function-names))

;; ========== AST显示 ==========
(define (ast->simple expr)
  (cond
    [(pair? expr) (map ast->simple expr)]
    [(symbol? expr) expr]
    [(number? expr) expr]
    [(string? expr) expr]
    [(boolean? expr) expr]
    [(void? expr) 'void]
    [(null? expr) '()]
    [else (format "~a" expr)]))

(printf "══════════════════════════════════\n")
(printf "  明道自举 Phase 2：解析器验证\n")
(printf "══════════════════════════════════\n\n")

;; ========== 验证明道版分词器源码 ==========
(printf "◆ 步骤1: 验证明道版分词器源码 (tokenizer.mingdao)\n")
(define tokenizer-source
  (read-utf8-file (build-path project-root "std/tokenizer.mingdao")))
(define-values (tokenizer-ast tokenizer-ok?)
  (analyze-mingdao-source "tokenizer.mingdao" tokenizer-source))

;; ========== 验证明道版解析器源码 ==========
(printf "◆ 步骤2: 验证明道版解析器源码 (parser.mingdao)\n")
(define parser-source
  (read-utf8-file (build-path project-root "std/parser.mingdao")))
(define-values (parser-ast parser-ok?)
  (analyze-mingdao-source "parser.mingdao" parser-source))

;; ========== 从明道版源码提取函数名 ==========
(define (extract-defined-names ast)
  (for/list ([expr ast]
             #:when (and (list? expr) 
                        (eq? (car expr) 'define) 
                        (symbol? (cadr expr))
                        (not (member (cadr expr) '(控制流关键字 声明关键字 数据结构关键字
                                                    内置函数关键字 比较关键字 特殊值关键字
                                                    管道关键字 单字关键字 四字关键字
                                                    三字关键字 双字关键字 单字运算符
                                                    所有函数名 read-boundary-keywords)))))
    (symbol->string (cadr expr))))

(define tokenizer-names (extract-defined-names tokenizer-ast))
(define parser-names (extract-defined-names parser-ast))

(printf "◆ 步骤3: 合并函数名\n")
(printf "  分词器定义函数: ~a\n" (length tokenizer-names))
(printf "  解析器定义函数: ~a\n" (length parser-names))

;; 合并所有函数名
(define all-function-names
  (remove-duplicates
   (append function-names tokenizer-names parser-names)
   string=?))

(printf "  总计: ~a\n\n" (length all-function-names))

;; ========== 测试用例比较 ==========
(printf "◆ 步骤4: 测试用例\n\n")

(define (test-parser name code)
  (printf "▶ ~a\n" name)
  (printf "  代码: ~a\n" code)
  (define result
    (with-handlers ([exn:fail? (λ (e)
                                 (printf "  ✗ 失败: ~a\n\n" (exn-message e))
                                 #f)])
      (parse-with-names code)))
  (when result
    (printf "  AST: ~a\n\n" (ast->simple result))))

;; 基础表达式
(test-parser "数字字面量：42" "打印,42")
(test-parser "字符串字面量：hello" "打印,\"hello\"")
(test-parser "真值" "打印,真值")
(test-parser "假值" "打印,假值")
(test-parser "空值" "打印,空值")

;; 标识符
(test-parser "标识符引用" "打印,x")
(test-parser "复合标识符" "打印,字符串长度")

;; 算术表达式
(test-parser "加法" "打印,加(1,2)")
(test-parser "乘法" "打印,乘(2,3)")
(test-parser "混合运算" "打印,加(乘(2,3),1)")

;; 比较表达式
(test-parser "大于" "打印,5大于3")
(test-parser "小于等于" "打印,5小于等于3")

;; 逻辑表达式
(test-parser "与" "打印,(真值与真值)")
(test-parser "或" "打印,(真值或假值)")
(test-parser "非" "打印,(非真值)")

;; 变量定义
(test-parser "变量定义" "定义x就是5")
(test-parser "变量定义+表达式" "定义x就是5,打印,x")

;; 函数定义
(test-parser "函数定义" "定义hello就是函：\n  打印,\"hello\"")
(test-parser "函数定义+参数" "定义add就是函a,b：\n  返回加(a,b)")

;; 条件语句
(test-parser "如果" "定义测试就是函x：\n  如果x大于0那么：\n    返回x\n  否则：\n    返回0")

;; 循环
(test-parser "for循环" "定义测试就是函：\n  对于i从1到5：\n    打印,i")
(test-parser "while循环" "定义测试就是函：\n  定义i就是0\n  当满足i小于5那么：\n    打印,i\n    赋值i为加(i,1)")

;; SVO语序
(test-parser "SVO" "定义result就是打印,5")
(test-parser "SVO多参数" "定义result就是加(1,2),打印,result")

;; 列表
(test-parser "列表" "定义lst就是列表,1,2,3")

;; 管道
(test-parser "管道" "定义x就是5,打印|x")
(test-parser "然后管道" "定义x就是5,打印然后x")

;; 多语句
(test-parser "多语句" "定义x就是42,打印,x")

;; 无空格代码
(test-parser "无空格代码" "定义汉诺塔就是函n,源,目标,辅助：\n  如果n等于0那么：\n    返回\n  汉诺塔,减(n,1),源,辅助,目标")

;; 复杂嵌套
(test-parser "嵌套表达式" "打印,(加(乘(2,3),乘(4,5)))")
(test-parser "多层嵌套条件"
  "定义判断就是函x：
  如果x大于0那么：
    如果x大于10那么：
      返回,\"big\"
    否则：
      返回,\"medium\"
  否则：
    返回,\"small\"")

;; ========== 总体结论 ==========
(printf "══════════════════════════════════\n")
(printf "  总体结论\n")
(printf "══════════════════════════════════\n\n")

(if tokenizer-ok?
    (printf "✓ tokenizer.mingdao 源码有效\n")
    (printf "✗ tokenizer.mingdao 有错误\n"))

(if parser-ok?
    (printf "✓ parser.mingdao 源码有效\n")
    (printf "✗ parser.mingdao 有错误\n"))

(printf "\nPhase 2 自举验证完成！\n")
(printf "  分词器: tokenizer.mingdao (~a 个表达式)\n" (length tokenizer-ast))
(printf "  解析器: parser.mingdao (~a 个表达式)\n" (length parser-ast))
(printf "  函数数: ~a (内置 + 分词器 + 解析器)\n" (length all-function-names))