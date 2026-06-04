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
         错误摘要)

;; 错误结构
(struct 明道错误 (类型 消息 行 列 建议 源码) #:transparent)

;; 语法错误
(define (抛出语法错误 消息 行 列)
  (明道错误 '语法错误 消息 行 列 #f #f))

;; 期望错误（期望某个token但得到其他）
(define (期望错误 期望类型 实际token 行 列)
  (define 建议
    (cond
      [(string=? 期望类型 "KEYWORD")
       "请检查关键字拼写是否正确"]
      [(string=? 期望类型 "IDENTIFIER")
       "此处应该是一个名称（变量名或函数名）"]
      [(string=? 期望类型 "COLON")
       "请使用冒号（:或：）分隔语句头和语句体"]
      [(string=? 期望类型 "INDENT")
       "请增加缩进（使用空格）来表示代码块"]
      [(string=? 期望类型 "DEDENT")
       "请减少缩进来结束当前代码块"]
      [else
       (format "此处需要 ~a" 期望类型)]))
  (明道错误 '期望错误 
             (format "期望 ~a，但得到 ~a" 期望类型 (token类型描述 实际token))
             行 列 建议 #f))

;; 未定义错误
(define (未定义错误 名称 类型 行 列)
  (define 建议
    (format "请先定义~a '~a'" 
            (if (string=? 类型 "变量") "变量" "函数")
            名称))
  (明道错误 '未定义错误
             (format "~a '~a' 未定义" 类型 名称)
             行 列 建议 #f))

;; 参数错误
(define (抛出参数错误 函数名 期望数量 实际数量 行 列)
  (明道错误 '参数错误
             (format "函数 '~a' 期望 ~a 个参数，但得到 ~a 个" 函数名 期望数量 实际数量)
             行 列
             "请检查函数调用时的参数数量"
             #f))

;; 运行时错误
(define (抛出运行时错误 消息 行 列 [建议 #f])
  (明道错误 '运行时错误 消息 行 列 建议 #f))

;; 类型错误
(define (抛出类型错误 期望类型 实际值 行 列)
  (define 实际描述
    (cond
      [(number? 实际值) "数字"]
      [(string? 实际值) "字符串"]
      [(boolean? 实际值) "布尔值"]
      [(list? 实际值) "列表"]
      [(hash? 实际值) "字典"]
      [(procedure? 实际值) "函数"]
      [else (format "~s" 实际值)]))
  (明道错误 '类型错误
             (format "类型错误：期望 ~a，但得到 ~a" 期望类型 实际描述)
             行 列
             "请检查变量类型是否匹配" #f))

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