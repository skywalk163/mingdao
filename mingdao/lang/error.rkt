#lang racket/base

(require racket/format
         racket/string
         racket/match)

(provide mingdao-error
         raise-syntax-error
         expected-error
         undefined-error
         raise-argument-error
         raise-runtime-error
         raise-type-error
         assertion-failed-error
         format-error-message
         format-exception
         error->chinese-message
         error-with-source
         error-summary
         type-mismatch-error
         duplicate-definition-error)

;; Error structure
(struct mingdao-error (type message line col suggestion source) #:transparent)

;; Syntax error
(define (raise-syntax-error msg line col)
  (define suggestion
    (cond
      [(string-contains? msg "未闭合")
       "请检查括号、引号或缩进是否正确闭合"]
      [(string-contains? msg "期望")
       "请检查语法是否正确"]
      [(string-contains? msg "token")
       "请检查代码格式"]
      [else #f]))
  (mingdao-error '语法错误 msg line col suggestion #f))

;; Expected error (expected token but got something else)
(define (expected-error expected-type actual-token line col)
  (define suggestion
    (cond
      [(string=? expected-type "KEYWORD")
       "请检查关键字拼写是否正确。常见关键字包括：定义、如果、那么、否则、对于、返回、跳出、继续"]
      [(string=? expected-type "IDENTIFIER")
       "此处应该是一个名称（变量名或函数名）。名称只能包含字母、数字和下划线，不能以数字开头"]
      [(string=? expected-type "COLON")
       "请使用英文冒号(:)分隔语句头和语句体"]
      [(string=? expected-type "INDENT")
       "请增加缩进（使用空格）来表示代码块。建议使用4个空格作为缩进"]
      [(string=? expected-type "DEDENT")
       "请减少缩进来结束当前代码块"]
      [(string=? expected-type "LPAREN")
       "请添加左括号(来开始参数列表"]
      [(string=? expected-type "RPAREN")
       "请添加右括号)来结束参数列表"]
      [(string=? expected-type "STRING")
       "请使用双引号包裹字符串"]
      [(string=? expected-type "NUMBER")
       "请输入有效的数字"]
      [else
       (format "此处需要 ~a" expected-type)]))
  (mingdao-error '期望错误
                 (format "期望 ~a，但得到 ~a" expected-type (token-type-description actual-token))
                 line col suggestion #f))

;; Undefined error
(define (undefined-error name kind line col)
  (define suggestion
    (cond
      [(string=? kind "变量")
       (format "请先定义变量 '~a'，或者检查变量名拼写是否正确" name)]
      [(string=? kind "函数")
       (format "请先定义函数 '~a'，或者检查函数名拼写是否正确。如果是标准库函数，请确保已导入相应模块" name)]
      [(string=? kind "类型")
       (format "请先使用 '定义类型' 语句定义类型 '~a'" name)]
      [else
       (format "请先定义~a '~a'"
               (if (string=? kind "变量") "变量" "函数")
               name)]))
  (mingdao-error '未定义错误
                 (format "~a '~a' 未定义" kind name)
                 line col suggestion #f))

;; Argument error
(define (raise-argument-error fn expected-count actual-count line col)
  (define suggestion
    (cond
      [(> actual-count expected-count)
       (format "函数 '~a' 只需要 ~a 个参数，但提供了 ~a 个，请移除多余的参数"
               fn expected-count actual-count)]
      [(< actual-count expected-count)
       (format "函数 '~a' 需要 ~a 个参数，但只提供了 ~a 个，请补充缺少的参数"
               fn expected-count actual-count)]
      [else
       "请检查函数调用时的参数数量"]))
  (mingdao-error '参数错误
                 (format "函数 '~a' 期望 ~a 个参数，但得到 ~a 个" fn expected-count actual-count)
                 line col suggestion #f))

;; Runtime error
(define (raise-runtime-error msg line col [suggestion #f])
  (define default-suggestion
    (cond
      [(string-contains? msg "除零")
       "请检查除数是否为零"]
      [(string-contains? msg "索引")
       "请检查列表索引是否在有效范围内"]
      [(string-contains? msg "键")
       "请检查字典中是否存在该键"]
      [(string-contains? msg "文件")
       "请检查文件路径是否正确，文件是否存在"]
      [else #f]))
  (mingdao-error '运行时错误 msg line col (or suggestion default-suggestion) #f))

;; Type error
(define (raise-type-error expected-type actual-value line col)
  (define actual-type
    (cond
      [(number? actual-value) (if (integer? actual-value) "整数" "浮点数")]
      [(string? actual-value) "字符串"]
      [(boolean? actual-value) "布尔值"]
      [(list? actual-value) "列表"]
      [(hash? actual-value) "字典"]
      [(procedure? actual-value) "函数"]
      [(null? actual-value) "空值"]
      [else (format "~s" actual-value)]))
  (define suggestion
    (cond
      [(and (string=? expected-type "整数") (string=? actual-type "浮点数"))
       "可以使用 '转整数' 函数将浮点数转换为整数"]
      [(and (string=? expected-type "字符串") (string=? actual-type "整数"))
       "可以使用 '转字符串' 函数将整数转换为字符串"]
      [(and (string=? expected-type "列表") (not (string=? actual-type "列表")))
       "请确保使用方括号[]创建列表"]
      [else
       (format "请检查变量类型是否匹配，期望 ~a 类型" expected-type)]))
  (mingdao-error '类型错误
                 (format "类型错误：期望 ~a，但得到 ~a" expected-type actual-type)
                 line col suggestion #f))

;; Type mismatch error (more detailed)
(define (type-mismatch-error var-name expected-type actual-type line col)
  (define suggestion
    (cond
      [(and (eq? expected-type '整数) (eq? actual-type '浮点数))
       (format "可以使用 '转整数(~a)' 将浮点数转换为整数" var-name)]
      [(and (eq? expected-type '字符串) (eq? actual-type '整数))
       (format "可以使用 '转字符串(~a)' 将整数转换为字符串" var-name)]
      [(and (eq? expected-type '浮点数) (eq? actual-type '整数))
       "整数可以自动转换为浮点数"]
      [(and (pair? expected-type) (eq? (car expected-type) '列表))
       (format "请确保 '~a' 是一个列表，使用方括号[]创建" var-name)]
      [(and (pair? expected-type) (eq? (car expected-type) '或))
       (format "请确保 '~a' 的值是以下类型之一: ~a"
               var-name (string-join (map symbol->string (cdr expected-type)) "、"))]
      [else
       (format "请确保变量 '~a' 的类型为 ~a" var-name expected-type)]))
  (mingdao-error '类型错误
                 (format "变量 '~a' 的类型不匹配：期望 ~a，但得到 ~a" var-name expected-type actual-type)
                 line col suggestion #f))

;; Duplicate definition error
(define (duplicate-definition-error name kind line col)
  (define suggestion
    (cond
      [(string=? kind "变量")
       (format "变量 '~a' 已被定义。如果需要重新赋值，请使用 '赋值' 语句" name)]
      [(string=? kind "函数")
       (format "函数 '~a' 已被定义。如需重载，请使用不同的参数数量或类型" name)]
      [(string=? kind "类型")
       (format "类型 '~a' 已被定义。类型别名不能重复定义" name)]
      [else
       (format "~a '~a' 已被定义" kind name)]))
  (mingdao-error '重复定义错误
                 (format "~a '~a' 重复定义" kind name)
                 line col suggestion #f))

;; Assertion failed error
(define (assertion-failed-error msg expression line col)
  (define display-msg (if (string=? msg "") "断言失败" msg))
  (mingdao-error '断言错误
                 (format "断言失败：~a" display-msg)
                 line col
                 "请检查条件表达式是否满足预期"
                 #f))

;; Token type description (for error hints)
(define (token-type-description token-value)
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
;; Error formatting — three output modes: detailed, standard, summary
;; ============================================================

;; Format any exception as friendly Chinese message
(define (format-exception exn [source-code #f])
  (define msg (exn-message exn))
  (cond
    [(mingdao-error? exn)
     (format-error-message exn source-code)]
    [else
     (string-join
      (list ""
            "╔══════════════════════════════════════╗"
            "║       明道语言运行时异常              ║"
            "╚══════════════════════════════════════╝"
            ""
            (format "异常类型：~a" (object-name exn))
            (format "异常消息：~a" msg))
      "\n")]))

;; Format error message for display
(define (format-error-message err [source-code #f])
  (define err-type (mingdao-error-type err))
  (define err-msg (mingdao-error-message err))
  (define err-line (mingdao-error-line err))
  (define err-col (mingdao-error-col err))
  (define err-suggestion (mingdao-error-suggestion err))
  (define err-with-source (or source-code (mingdao-error-source err)))
  
  (define output-lines
    (append
     (list ""
           "╔══════════════════════════════════════╗"
           "║          明道语言错误提示              ║"
           "╚══════════════════════════════════════╝"
           "")
     (list (format "错误类型：~a" (type->chinese err-type)))
     (if (and err-line err-col)
         (list (format "错误位置：第 ~a 行，第 ~a 列" err-line err-col))
         (if err-line
             (list (format "错误位置：第 ~a 行" err-line))
             '()))
     (list (format "错误信息：~a" err-msg))
     (if err-suggestion
         (list (format "修复建议：~a" err-suggestion))
         '())
     (if err-with-source
         (list ""
               "相关代码："
               (show-code-line err-with-source (or err-line 1) (or err-col 1)))
         '())
     (list "")))
  
  (string-join output-lines "\n"))

;; Error summary (one-line version)
(define (error-summary err)
  (define err-type (mingdao-error-type err))
  (define err-msg (mingdao-error-message err))
  (define err-line (mingdao-error-line err))
  (if err-line
      (format "[~a] 第~a行: ~a" (type->chinese err-type) err-line err-msg)
      (format "[~a] ~a" (type->chinese err-type) err-msg)))

;; Error to Chinese message (plain text)
(define (error->chinese-message err)
  (mingdao-error-message err))

;; Error with source attached
(define (error-with-source err source-code)
  (mingdao-error (mingdao-error-type err)
                 (mingdao-error-message err)
                 (mingdao-error-line err)
                 (mingdao-error-col err)
                 (mingdao-error-suggestion err)
                 source-code))

;; Type to Chinese name
(define (type->chinese err-type)
  (case err-type
    [(语法错误) "语法错误"]
    [(期望错误) "语法错误"]
    [(未定义错误) "命名错误"]
    [(参数错误) "参数错误"]
    [(运行时错误) "运行时错误"]
    [(类型错误) "类型错误"]
    [(断言错误) "断言错误"]
    [else "未知错误"]))

;; Show code line with error marker
(define (show-code-line source-code line col)
  (define lines (string-split source-code "\n"))
  (if (and (> (length lines) (sub1 line))
           (> line 0))
      (let* ([code-line (list-ref lines (sub1 line))]
             [arrow (make-string (max 0 (sub1 col)) #\space)])
        (string-append
         code-line "\n"
         arrow "^── 这里"))
      (if (and (> (length lines) (sub1 line)) (> line 0))
          (list-ref lines (sub1 line))
          "")))
