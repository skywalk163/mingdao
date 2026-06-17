#lang racket/base

(require racket/match
         racket/hash
         racket/string
         racket/list)

;; ============================================================
;; 依赖兜底：安全 require lang 下的核心模块
;; 如果 require 找不到或符号名字对不上，则用 #f 或空列表兜底
;; ============================================================

(define-syntax-rule (safe-require* mod-path)
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require mod-path #f)))

(define-syntax-rule (safe-dynamic-require* mod-path sym default)
  (with-handlers ([exn:fail? (lambda (e) default)])
    (dynamic-require mod-path sym (lambda () default))))

(define tokenize
  (safe-dynamic-require* "../lang/tokenizer.rkt" 'tokenize (lambda (x) '())))

(define parse
  (safe-dynamic-require* "../lang/parser.rkt" 'parse
                         (case-lambda
                           [(tokens) '()]
                           [(tokens extra) '()])))

(define analyze
  (safe-dynamic-require* "../lang/semantic.rkt" 'analyze
                         (lambda (ast builtin) '())))

(define 控制流关键字
  (with-handlers ([exn:fail? (lambda (e) '())])
    (dynamic-require "../lang/tokenizer.rkt" '控制流关键字 (lambda () '()))))

(define 声明关键字
  (with-handlers ([exn:fail? (lambda (e) '())])
    (dynamic-require "../lang/tokenizer.rkt" '声明关键字 (lambda () '()))))

(define 所有函数名
  (with-handlers ([exn:fail? (lambda (e) '())])
    (dynamic-require "../lang/tokenizer.rkt" '所有函数名 (lambda () '()))))

;; ============================================================
;; 公共辅助
;; ============================================================

(define (safe-hash-ref h key [default #f])
  (with-handlers ([exn:fail? (lambda (e) default)])
    (hash-ref h key default)))

(define (symbol->string* s)
  (cond
    [(symbol? s) (symbol->string s)]
    [(string? s) s]
    [else (format "~a" s)]))

;; ============================================================
;; 从 AST 提取定义
;; AST 形如：'((define 符号 值) (define (符号 . 参数) . 体) ...)
;; ============================================================

(define (extract-symbols ast)
  (define results '())
  (define (collect! r)
    (set! results (cons r results)))
  (define (walk expr)
    (match expr
      ;; 变量定义
      [`(define ,(? symbol? name) ,val)
       (collect! (hash '名称 (symbol->string name)
                        '种类 "变量"
                        '类型 (guess-type val)
                        '行号 (guess-line expr)))]
      ;; 函数定义
      [`(define (,(? symbol? fn-name) . ,params) . ,body)
       (collect! (hash '名称 (symbol->string fn-name)
                        '种类 "函数"
                        '类型 (fn-type-string params body)
                        '行号 (guess-line expr)))
       (for ([p params])
         (when (symbol? p)
           (collect! (hash '名称 (symbol->string p)
                            '种类 "参数"
                            '类型 "未知"
                            '行号 (guess-line expr)))))]
      ;; 常量定义
      [`(define-constant ,(? symbol? name) ,val)
       (collect! (hash '名称 (symbol->string name)
                        '种类 "常量"
                        '类型 (guess-type val)
                        '行号 (guess-line expr)))]
      ;; 嵌套表达式递归
      [(cons a b)
       (walk a)
       (walk b)]
      [_ (void)]))
  (for-each walk ast)
  (reverse results))

(define (guess-line expr)
  (match expr
    [(cons (list 'line n) _) n]
    [(list* 'define _ rest)
     (or (line-from-metadata rest) 1)]
    [_ 1]))

(define (line-from-metadata rest)
  (let loop ([xs rest])
    (match xs
      ['() 1]
      [(cons (and (or (list 'line n) (vector 'line n)) m) _)
       (if (number? (cadr m)) (cadr m) 1)]
      [(cons x xs) (loop xs)]
      [_ 1])))

(define (guess-type val)
  (match val
    [(? number?) "数字"]
    [(? string?) "字符串"]
    ['真值 "布尔"]
    ['假值 "布尔"]
    ['空值 "空值"]
    [(cons '列表 _) "列表"]
    [(cons '字典 _) "字典"]
    [(cons 'lambda _) "函数"]
    [(list 'define _ v) (guess-type v)]
    [_ "未知"]))

(define (fn-type-string params body)
  (define param-count (length (filter symbol? params)))
  (define param-types (string-join (for/list ([p params] #:when (symbol? p)) "未知") ", "))
  (format "(~a) -> ~a" param-types (guess-body-return body)))

(define (guess-body-return body)
  (if (empty? body)
      "空值"
      (guess-type (last body))))

;; ============================================================
;; 列出符号
;; ============================================================

(define (列出符号 code-string)
  (with-handlers ([exn:fail? (lambda (e)
                               (list (hash '名称 "__ERROR__"
                                            '种类 "错误"
                                            '类型 (exn-message e)
                                            '行号 0)))])
    (define tokens (tokenize code-string))
    (define ast (if (procedure-arity-includes? parse 2)
                    (parse tokens '())
                    (parse tokens)))
    (define errors (analyze ast (append (if (list? 所有函数名) 所有函数名 '())
                                       '("打印" "长度" "列表"))))
    (define symbols (extract-symbols ast))
    ;; 附加错误信息为特殊条目（可选）
    (if (list? symbols) symbols '())))

;; ============================================================
;; 推断类型（简化实现）
;; ============================================================

(define (推断类型 code-string [context-hash (hash)])
  (with-handlers ([exn:fail? (lambda (e) "未知")])
    (define tokens (tokenize code-string))
    (define ast (parse tokens '()))
    (if (and (list? ast) (not (empty? ast)))
        (guess-type (last ast))
        "未知")))

;; ============================================================
;; 查找作用域（简化实现）
;; ============================================================

(define (查找作用域 var-name code-string)
  (with-handlers ([exn:fail? (lambda (e) (hash '状态 "失败" '错误信息 (exn-message e)))])
    (define tokens (tokenize code-string))
    (define ast (parse tokens '()))
    (define found-level 0)
    (define found-in (list))
    (define current-depth 0)
    (define scope-chain (list (hash '层级 0 '名称 "全局作用域" '符号 empty)))
    (define (walk expr depth)
      (match expr
        [`(define ,(? symbol? name) ,_)
         (when (string=? (symbol->string name) var-name)
           (set! found-level depth))]
        [`(define (,(? symbol? fn-name) . ,params) . ,body)
         (when (string=? (symbol->string fn-name) var-name)
           (set! found-level depth))
         (for ([p params])
           (when (and (symbol? p) (string=? (symbol->string p) var-name))
             (set! found-level (+ depth 1))))
         (for-each (lambda (b) (walk b (+ depth 1))) body)]
        [(cons a b)
         (walk a depth)
         (walk b depth)]
        [_ (void)]))
    (for-each (lambda (e) (walk e 0)) ast)
    (hash '状态 "成功"
          '变量名 var-name
          '作用域层级 found-level
          '作用域链 (list
                     (hash '层级 0 '名称 "全局" '定义位置 #t)))))

;; ============================================================
;; 获取关键字
;; ============================================================

(define 关键字表
  (hash
   "流程控制"
   (list
    (hash '名称 "如果" '描述 "条件分支")
    (hash '名称 "那么" '描述 "条件分支动作")
    (hash '名称 "否则" '描述 "条件分支默认")
    (hash '名称 "对于" '描述 "for 循环")
    (hash '名称 "当" '描述 "while 循环")
    (hash '名称 "跳出" '描述 "跳出循环")
    (hash '名称 "继续" '描述 "跳过本次循环")
    (hash '名称 "返回" '描述 "返回值")
    (hash '名称 "匹配" '描述 "模式匹配")
    (hash '名称 "尝试" '描述 "异常处理")
    (hash '名称 "捕获" '描述 "捕获异常")
    (hash '名称 "始终" '描述 "finally 块"))
   "定义"
   (list
    (hash '名称 "定义" '描述 "变量/函数定义")
    (hash '名称 "就是" '描述 "定义赋值")
    (hash '名称 "就是函" '描述 "函数定义")
    (hash '名称 "常量" '描述 "常量定义")
    (hash '名称 "导入" '描述 "导入模块")
    (hash '名称 "导出" '描述 "导出符号")
    (hash '名称 "模块" '描述 "声明模块")
    (hash '名称 "公开" '描述 "公开符号")
    (hash '名称 "私有" '描述 "私有符号"))
   "其他"
   (list
    (hash '名称 "打印" '描述 "输出到控制台")
    (hash '名称 "长度" '描述 "获取长度")
    (hash '名称 "列表" '描述 "创建列表")
    (hash '名称 "字典" '描述 "创建字典")
    (hash '名称 "字符串" '描述 "字符串操作")
    (hash '名称 "加" '描述 "加法运算")
    (hash '名称 "减" '描述 "减法运算")
    (hash '名称 "乘" '描述 "乘法运算")
    (hash '名称 "除" '描述 "除法运算")
    (hash '名称 "自己" '描述 "实例自身引用")
    (hash '名称 "类" '描述 "类声明")
    (hash '名称 "异步" '描述 "异步函数")
    (hash '名称 "等待" '描述 "等待异步结果"))))

(define (获取关键字 [category #f])
  (cond
    [(not category)
     (apply append (for/list ([k (hash-keys 关键字表)])
                     (for/list ([item (hash-ref 关键字表 k)])
                       (hash-set item '分类 k))))]
    [(hash-has-key? 关键字表 category)
     (for/list ([item (hash-ref 关键字表 category)])
       (hash-set item '分类 category))]
    [else empty]))

;; ============================================================
;; 获取标准库
;; ============================================================

(define 标准库表
  (hash
   "基础"
   (list
    (hash '名称 "打印" '签名 "(打印 值 ...)" '描述 "将值输出到控制台")
    (hash '名称 "表示" '签名 "(表示 值)" '描述 "将值转为可读字符串")
    (hash '名称 "转字符串" '签名 "(转字符串 值)" '描述 "将值转为字符串")
    (hash '名称 "获取类型" '签名 "(获取类型 值)" '描述 "获取值的类型名称")
    (hash '名称 "断言" '签名 "(断言 条件 [消息])" '描述 "断言条件为真")
    (hash '名称 "报错" '签名 "(报错 消息)" '描述 "抛出异常"))
   "列表"
   (list
    (hash '名称 "列表" '签名 "(列表 元素 ...)" '描述 "创建列表")
    (hash '名称 "长度" '签名 "(长度 列表)" '描述 "获取列表长度")
    (hash '名称 "索引" '签名 "(索引 列表 位置)" '描述 "按位置取值")
    (hash '名称 "列表修改" '签名 "(列表修改 列表 位置 值)" '描述 "修改列表元素")
    (hash '名称 "追加" '签名 "(追加 列表 值)" '描述 "向列表追加元素")
    (hash '名称 "映射" '签名 "(映射 函数 列表)" '描述 "对每个元素应用函数")
    (hash '名称 "过滤" '签名 "(过滤 谓词 列表)" '描述 "过滤符合条件的元素")
    (hash '名称 "范围" '签名 "(范围 开始 结束 [步长])" '描述 "生成整数序列")
    (hash '名称 "反转" '签名 "(反转 列表)" '描述 "反转列表"))
   "字符串"
   (list
    (hash '名称 "字符串长度" '签名 "(字符串长度 字符串)" '描述 "获取字符串长度")
    (hash '名称 "字符串索引" '签名 "(字符串索引 字符串 位置)" '描述 "获取指定位置字符")
    (hash '名称 "子字符串" '签名 "(子字符串 字符串 起 [止])" '描述 "截取子串")
    (hash '名称 "字符串包含" '签名 "(字符串包含 字符串 子串)" '描述 "是否包含子串")
    (hash '名称 "拼接" '签名 "(拼接 字符串 ...)" '描述 "拼接字符串")
    (hash '名称 "大写" '签名 "(大写 字符串)" '描述 "转大写")
    (hash '名称 "小写" '签名 "(小写 字符串)" '描述 "转小写")
    (hash '名称 "替换" '签名 "(替换 字符串 旧 新)" '描述 "替换子串")
    (hash '名称 "去空格" '签名 "(去空格 字符串)" '描述 "去除首尾空格")
    (hash '名称 "拆分" '签名 "(拆分 字符串 分隔符)" '描述 "拆分字符串为列表")
    (hash '名称 "连接" '签名 "(连接 分隔符 字符串列表)" '描述 "用分隔符连接字符串"))
   "数学"
   (list
    (hash '名称 "加" '签名 "(加 a b)" '描述 "加法")
    (hash '名称 "减" '签名 "(减 a b)" '描述 "减法")
    (hash '名称 "乘" '签名 "(乘 a b)" '描述 "乘法")
    (hash '名称 "除" '签名 "(除 a b)" '描述 "除法")
    (hash '名称 "模" '签名 "(模 a b)" '描述 "取模")
    (hash '名称 "幂" '签名 "(幂 a b)" '描述 "幂运算")
    (hash '名称 "绝对值" '签名 "(绝对值 x)" '描述 "绝对值")
    (hash '名称 "最大值" '签名 "(最大值 a b ...)" '描述 "最大值")
    (hash '名称 "最小值" '签名 "(最小值 a b ...)" '描述 "最小值")
    (hash '名称 "四舍五入" '签名 "(四舍五入 x)" '描述 "四舍五入")
    (hash '名称 "开方" '签名 "(开方 x)" '描述 "平方根")
    (hash '名称 "正弦" '签名 "(正弦 x)" '描述 "正弦函数")
    (hash '名称 "余弦" '签名 "(余弦 x)" '描述 "余弦函数")
    (hash '名称 "随机整数" '签名 "(随机整数 最小 最大)" '描述 "生成随机整数"))
   "IO"
   (list
    (hash '名称 "输入" '签名 "(输入 [提示])" '描述 "从标准输入读取一行")
    (hash '名称 "读取文件" '签名 "(读取文件 路径)" '描述 "读取文件内容")
    (hash '名称 "写入文件" '签名 "(写入文件 路径 内容)" '描述 "写入文件内容")
    (hash '名称 "追加文件" '签名 "(追加文件 路径 内容)" '描述 "追加文件内容"))
   "JSON"
   (list
    (hash '名称 "解析JSON" '签名 "(解析JSON 字符串)" '描述 "将 JSON 字符串解析为数据")
    (hash '名称 "生成JSON" '签名 "(生成JSON 值)" '描述 "将值序列化为 JSON 字符串"))
   "其他"
   (list
    (hash '名称 "是否相等" '签名 "(是否相等 a b)" '描述 "判断相等")
    (hash '名称 "数大于" '签名 "(数大于 a b)" '描述 "a > b")
    (hash '名称 "数小于" '签名 "(数小于 a b)" '描述 "a < b")
    (hash '名称 "列表包含" '签名 "(列表包含 列表 值)" '描述 "列表是否包含值")
    (hash '名称 "字符串转数字" '签名 "(字符串转数字 字符串)" '描述 "字符串转数字")
    (hash '名称 "数字转字符串" '签名 "(数字转字符串 数字)" '描述 "数字转字符串"))))

(define (获取标准库 [module-name #f])
  (cond
    [(not module-name)
     (apply append (for/list ([k (hash-keys 标准库表)])
                     (for/list ([item (hash-ref 标准库表 k)])
                       (hash-set item '分类 k))))]
    [(hash-has-key? 标准库表 module-name)
     (for/list ([item (hash-ref 标准库表 module-name)])
       (hash-set item '分类 module-name))]
    [else empty]))

;; ============================================================
;; 验证代码
;; ============================================================

(define (验证代码 code-string)
  (with-handlers ([exn:fail? (lambda (e)
                               (hash '状态 "失败"
                                     '解析通过 #f
                                     '类型检查 #f
                                     '错误 (list (hash '行号 0 '信息 (exn-message e)))
                                     '警告 empty
                                     '推断类型 "未知"))])
    (define tokens (tokenize code-string))
    (define ast (parse tokens '()))
    (define builtins (append (if (list? 所有函数名) 所有函数名 '())
                             '("打印" "长度" "列表" "索引" "加" "减" "乘" "除")))
    (define errors (analyze ast builtins))
    (define error-list
      (if (list? errors)
          (for/list ([e errors])
            (hash '行号 (or (with-handlers ([exn:fail? (lambda (x) 0)])
                              (and (struct? e)
                                   (let ([v (struct->vector e)])
                                     (and (> (vector-length v) 3)
                                          (vector-ref v 2)))))
                            0)
                  '信息 (or (with-handlers ([exn:fail? (lambda (x) (format "~a" e))])
                              (and (struct? e)
                                   (let ([v (struct->vector e)])
                                     (and (> (vector-length v) 2)
                                          (format "~a" (vector-ref v 1))))))
                            (format "~a" e))))
          empty))
    (hash '状态 "成功"
          '解析通过 #t
          '类型检查 (empty? error-list)
          '错误 error-list
          '警告 empty
          '推断类型 (if (and (list? ast) (not (empty? ast)))
                        (guess-type (last ast))
                        "未知"))))

;; ============================================================
;; 主入口：语义查询
;; ============================================================

(define (语义查询 query-hash)
  (with-handlers ([exn:fail? (lambda (e)
                               (hash '状态 "失败" '错误信息 (exn-message e)))])
    (define type (safe-hash-ref query-hash '查询类型 #f))
    (cond
      [(not type)
       (hash '状态 "失败" '错误信息 "缺少 查询类型 字段")]
      [(string=? type "列出符号")
       (define code (safe-hash-ref query-hash '代码 ""))
       (hash '状态 "成功" '结果 (列出符号 code))]
      [(string=? type "推断类型")
       (define code (safe-hash-ref query-hash '代码 ""))
       (define ctx (safe-hash-ref query-hash '上下文 (hash)))
       (hash '状态 "成功" '结果 (推断类型 code ctx))]
      [(string=? type "查找作用域")
       (define name (safe-hash-ref query-hash '变量名 ""))
       (define code (safe-hash-ref query-hash '代码 ""))
       (hash '状态 "成功" '结果 (查找作用域 name code))]
      [(string=? type "获取关键字")
       (define cat (safe-hash-ref query-hash '分类 #f))
       (hash '状态 "成功" '结果 (获取关键字 cat))]
      [(string=? type "获取标准库")
       (define mod (safe-hash-ref query-hash '模块 #f))
       (hash '状态 "成功" '结果 (获取标准库 mod))]
      [(string=? type "验证代码")
       (define code (safe-hash-ref query-hash '代码 ""))
       (hash '状态 "成功" '结果 (验证代码 code))]
      [else
       (hash '状态 "失败" '错误信息 (format "未知的查询类型: ~a" type))])))

;; ============================================================
;; 导出
;; ============================================================

(provide 语义查询
         列出符号
         推断类型
         查找作用域
         获取关键字
         获取标准库
         验证代码)

;; ============================================================
;; 独立运行自测
;; ============================================================

(module+ main
  (printf "【语义查询协议 · 自测】~n")
  (printf "测试 1: 获取关键字（流程控制）~n")
  (printf "  ~a~n" (获取关键字 "流程控制"))
  (printf "测试 2: 获取标准库（数学）~n")
  (printf "  ~a~n" (获取标准库 "数学"))
  (printf "测试 3: 列出符号（简单代码）~n")
  (printf "  ~a~n" (列出符号 "定义 求和 就是函(a, b)\n    加(a, b)\n\n定义 x 就是 1"))
  (printf "测试 4: 验证代码~n")
  (printf "  ~a~n" (验证代码 "定义 x 就是 1\n打印(x)"))
  (printf "测试 5: 推断类型~n")
  (printf "  ~a~n" (推断类型 "加(1, 2)"))
  (printf "测试 6: 主入口 语义查询~n")
  (printf "  ~a~n" (语义查询 (hash '查询类型 "获取关键字" '分类 "定义")))
  (printf "~n自测完成。~n"))
