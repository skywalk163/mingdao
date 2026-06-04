#lang racket/base

(require racket/format
         racket/string
         racket/match)

(provide 明道错误
         抛出语法错误
         期望错误
         未定义错误
         抛出参数错误
         抛出运行时错误
         抛出类型错误
         断言失败错误
         格式化错误信息
         格式化异常
         错误->中文消息
         带源码错误
         错误摘要
         类型不匹配错误
         重复定义错误)

;; 错误结构
(struct 明道错误 (类型 消息 行 列 建议 源码) #:transparent)

;; 语法错误
(define (抛出语法错误 消息 行 列)
  (define 建议
    (cond
      [(string-contains? 消息 "未闭合")
       "请检查括号、引号或缩进是否正确闭合"]
      [(string-contains? 消息 "期望")
       "请检查语法是否正确"]
      [(string-contains? 消息 "token")
       "请检查代码格式"]
      [else #f]))
  (明道错误 '语法错误 消息 行 列 建议 #f))

;; 期望错误（期望某个token但得到其他）
(define (期望错误 期望类型 实际token 行 列)
  (define 建议
    (cond
      [(string=? 期望类型 "KEYWORD")
       "请检查关键字拼写是否正确。常见关键字包括：定义、如果、那么、否则、对于、返回、跳出、继续"]
      [(string=? 期望类型 "IDENTIFIER")
       "此处应该是一个名称（变量名或函数名）。名称只能包含字母、数字和下划线，不能以数字开头"]
      [(string=? 期望类型 "COLON")
       "请使用英文冒号(:)分隔语句头和语句体"]
      [(string=? 期望类型 "INDENT")
       "请增加缩进（使用空格）来表示代码块。建议使用4个空格作为缩进"]
      [(string=? 期望类型 "DEDENT")
       "请减少缩进来结束当前代码块"]
      [(string=? 期望类型 "LPAREN")
       "请添加左括号(来开始参数列表"]
      [(string=? 期望类型 "RPAREN")
       "请添加右括号)来结束参数列表"]
      [(string=? 期望类型 "STRING")
       "请使用双引号包裹字符串"]
      [(string=? 期望类型 "NUMBER")
       "请输入有效的数字"]
      [else
       (format "此处需要 ~a" 期望类型)]))
  (明道错误 '期望错误 
             (format "期望 ~a，但得到 ~a" 期望类型 (token类型描述 实际token))
             行 列 建议 #f))

;; 未定义错误
(define (未定义错误 名称 类型 行 列)
  (define 建议
    (cond
      [(string=? 类型 "变量")
       (format "请先定义变量 '~a'，或者检查变量名拼写是否正确" 名称)]
      [(string=? 类型 "函数")
       (format "请先定义函数 '~a'，或者检查函数名拼写是否正确。如果是标准库函数，请确保已导入相应模块" 名称)]
      [(string=? 类型 "类型")
       (format "请先使用 '定义类型' 语句定义类型 '~a'" 名称)]
      [else
       (format "请先定义~a '~a'" 
               (if (string=? 类型 "变量") "变量" "函数")
               名称)]))
  (明道错误 '未定义错误
             (format "~a '~a' 未定义" 类型 名称)
             行 列 建议 #f))

;; 参数错误
(define (抛出参数错误 函数名 期望数量 实际数量 行 列)
  (define 建议
    (cond
      [(> 实际数量 期望数量)
       (format "函数 '~a' 只需要 ~a 个参数，但提供了 ~a 个，请移除多余的参数" 
               函数名 期望数量 实际数量)]
      [(< 实际数量 期望数量)
       (format "函数 '~a' 需要 ~a 个参数，但只提供了 ~a 个，请补充缺少的参数" 
               函数名 期望数量 实际数量)]
      [else
       "请检查函数调用时的参数数量"]))
  (明道错误 '参数错误
             (format "函数 '~a' 期望 ~a 个参数，但得到 ~a 个" 函数名 期望数量 实际数量)
             行 列 建议 #f))

;; 运行时错误
(define (抛出运行时错误 消息 行 列 [建议 #f])
  (define 默认建议
    (cond
      [(string-contains? 消息 "除零")
       "请检查除数是否为零"]
      [(string-contains? 消息 "索引")
       "请检查列表索引是否在有效范围内"]
      [(string-contains? 消息 "键")
       "请检查字典中是否存在该键"]
      [(string-contains? 消息 "文件")
       "请检查文件路径是否正确，文件是否存在"]
      [else #f]))
  (明道错误 '运行时错误 消息 行 列 (or 建议 默认建议) #f))

;; 类型错误
(define (抛出类型错误 期望类型 实际值 行 列)
  (define 实际类型
    (cond
      [(number? 实际值) (if (integer? 实际值) "整数" "浮点数")]
      [(string? 实际值) "字符串"]
      [(boolean? 实际值) "布尔值"]
      [(list? 实际值) "列表"]
      [(hash? 实际值) "字典"]
      [(procedure? 实际值) "函数"]
      [(null? 实际值) "空值"]
      [else (format "~s" 实际值)]))
  (define 建议
    (cond
      [(and (string=? 期望类型 "整数") (string=? 实际类型 "浮点数"))
       "可以使用 '转整数' 函数将浮点数转换为整数"]
      [(and (string=? 期望类型 "字符串") (string=? 实际类型 "整数"))
       "可以使用 '转字符串' 函数将整数转换为字符串"]
      [(and (string=? 期望类型 "列表") (not (string=? 实际类型 "列表")))
       "请确保使用方括号[]创建列表"]
      [else
       (format "请检查变量类型是否匹配，期望 ~a 类型" 期望类型)]))
  (明道错误 '类型错误
             (format "类型错误：期望 ~a，但得到 ~a" 期望类型 实际类型)
             行 列 建议 #f))

;; 类型不匹配错误（更详细）
(define (类型不匹配错误 变量名 期望类型 实际类型 行 列)
  (define 建议
    (cond
      [(and (eq? 期望类型 '整数) (eq? 实际类型 '浮点数))
       (format "可以使用 '转整数(~a)' 将浮点数转换为整数" 变量名)]
      [(and (eq? 期望类型 '字符串) (eq? 实际类型 '整数))
       (format "可以使用 '转字符串(~a)' 将整数转换为字符串" 变量名)]
      [(and (eq? 期望类型 '浮点数) (eq? 实际类型 '整数))
       "整数可以自动转换为浮点数"]
      [(and (pair? 期望类型) (eq? (car 期望类型) '列表))
       (format "请确保 '~a' 是一个列表，使用方括号[]创建" 变量名)]
      [(and (pair? 期望类型) (eq? (car 期望类型) '或))
       (format "请确保 '~a' 的值是以下类型之一: ~a" 
               变量名 (string-join (map symbol->string (cdr 期望类型)) "、"))]
      [else
       (format "请确保变量 '~a' 的类型为 ~a" 变量名 期望类型)]))
  (明道错误 '类型错误
             (format "变量 '~a' 的类型不匹配：期望 ~a，但得到 ~a" 变量名 期望类型 实际类型)
             行 列 建议 #f))

;; 重复定义错误
(define (重复定义错误 名称 类型 行 列)
  (define 建议
    (cond
      [(string=? 类型 "变量")
       (format "变量 '~a' 已被定义。如果需要重新赋值，请使用 '赋值' 语句" 名称)]
      [(string=? 类型 "函数")
       (format "函数 '~a' 已被定义。如需重载，请使用不同的参数数量或类型" 名称)]
      [(string=? 类型 "类型")
       (format "类型 '~a' 已被定义。类型别名不能重复定义" 名称)]
      [else
       (format "~a '~a' 已被定义" 类型 名称)]))
  (明道错误 '重复定义错误
             (format "~a '~a' 重复定义" 类型 名称)
             行 列 建议 #f))

;; 断言失败错误
(define (断言失败错误 消息 表达式 行 列)
  (define 显示消息 (if (string=? 消息 "") "断言失败" 消息))
  (明道错误 '断言错误
             (format "断言失败：~a" 显示消息)
             行 列
             "请检查条件表达式是否满足预期"
             #f))

;; Token类型描述（用于错误提示）
(define (token类型描述 token-value)
  (cond
    [(string? token-value)
     (cond
       [(member token-value '("定义" "如果" "那么" "否则" "对于" "返回" "跳出" "继续"))
        (format "关键字 '~a'" token-value)]
       [(member token-value '("加" "减" "乘" "除"))
        (format "运算符 '~a'" token-value)]
       [(member token-value '("等于" "大于" "小于"))
        (format "比较符 '~a'" token-value)]
       [else (format "'~a'" token-value)])]
    [(number? token-value)
     (format "数字 ~a" token-value)]
    [(symbol? token-value)
     (format "'~a'" token-value)]
    [else (format "~a" token-value)]))

;; ============================================================
;; 错误格式化 — 三套输出：详细、标准、摘要
;; ============================================================

;; 格式化异常（将任何异常转为友好的中文消息）
(define (格式化异常 exn [源代码 #f])
  (define 消息 (exn-message exn))
  (cond
    [(明道错误? exn)
     (格式化错误信息 exn 源代码)]
    [else
     (string-join
      (list ""
            "╔══════════════════════════════════════╗"
            "║       明道语言运行时异常              ║"
            "╚══════════════════════════════════════╝"
            ""
            (format "异常类型：~a" (object-name exn))
            (format "异常消息：~a" 消息)
            (let ([stack (exn-continuation-marks exn)])
              (if stack
                  (format "堆栈信息：请使用调试模式查看详细调用堆栈")
                  ""))
            "")
      "\n")]))

;; 格式化错误信息（用于显示）
(define (格式化错误信息 错误 [源代码 #f])
  (define 类型 (明道错误-类型 错误))
  (define 消息 (明道错误-消息 错误))
  (define 行 (明道错误-行 错误))
  (define 列 (明道错误-列 错误))
  (define 建议 (明道错误-建议 错误))
  (define 带源码 (or 源代码 (明道错误-源码 错误)))
  
  (define 输出-lines
    (append
     (list ""
           "╔══════════════════════════════════════╗"
           "║          明道语言错误提示              ║"
           "╚══════════════════════════════════════╝"
           "")
     (list (format "错误类型：~a" (类型中文 类型)))
     (if (and 行 列)
         (list (format "错误位置：第 ~a 行，第 ~a 列" 行 列))
         (if 行
             (list (format "错误位置：第 ~a 行" 行))
             '()))
     (list (format "错误信息：~a" 消息))
     (if 建议
         (list (format "修复建议：~a" 建议))
         '())
     (if 带源码
         (list ""
               "相关代码："
               (显示代码行 带源码 (or 行 1) (or 列 1)))
         '())
     (list "")))
  
  (string-join 输出-lines "\n"))

;; 错误摘要（一行简洁版）
(define (错误摘要 错误)
  (define 类型 (明道错误-类型 错误))
  (define 消息 (明道错误-消息 错误))
  (define 行 (明道错误-行 错误))
  (if 行
      (format "[~a] 第~a行: ~a" (类型中文 类型) 行 消息)
      (format "[~a] ~a" (类型中文 类型) 消息)))

;; 错误->中文消息（纯文本）
(define (错误->中文消息 错误)
  (明道错误-消息 错误))

;; 带源码错误（附加源码到已有错误）
(define (带源码错误 错误 源代码)
  (明道错误 (明道错误-类型 错误)
             (明道错误-消息 错误)
             (明道错误-行 错误)
             (明道错误-列 错误)
             (明道错误-建议 错误)
             源代码))

;; 类型中文名
(define (类型中文 类型)
  (case 类型
    [(语法错误) "语法错误"]
    [(期望错误) "语法错误"]
    [(未定义错误) "命名错误"]
    [(参数错误) "参数错误"]
    [(运行时错误) "运行时错误"]
    [(类型错误) "类型错误"]
    [(断言错误) "断言错误"]
    [else "未知错误"]))

;; 显示代码行（带错误标记）
(define (显示代码行 源代码 行 列)
  (define lines (string-split 源代码 "\n"))
  (if (and (> (length lines) (sub1 行))
           (> 行 0))
      (let* ([代码行 (list-ref lines (sub1 行))]
             [箭头 (make-string (max 0 (sub1 列)) #\space)])
        (string-append
         代码行 "\n"
         箭头 "^── 这里"))
      (if (and (> (length lines) (sub1 行)) (> 行 0))
          (list-ref lines (sub1 行))
          "")))