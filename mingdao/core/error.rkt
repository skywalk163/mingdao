#lang racket/base

;; 错误处理模块
;; 提供统一的错误消息格式和异常处理机制

(require racket/list
         racket/format
         racket/control
         (for-syntax racket/base))

(provide ;; 异常类型谓词
         任意错误 类型错误 参数错误 变量错误 除零错误
         文件错误 读取错误 语法错误 用户错误
         ;; 错误处理宏
         尝试 捕获 始终
         ;; 统一错误抛出
         报错 报错-with-location 报错-with-suggestion
         ;; 错误消息构建器
         构建错误消息 错误类型中文)

;; ==================== 异常类型谓词 ====================

(define (任意错误 e) (exn:fail? e))
(define (类型错误 e) (exn:fail:contract? e))
(define (参数错误 e) (exn:fail:contract:arity? e))
(define (变量错误 e) (exn:fail:contract:variable? e))
(define (除零错误 e) (exn:fail:contract:divide-by-zero? e))
(define (文件错误 e) (exn:fail:filesystem? e))
(define (读取错误 e) (exn:fail:read? e))
(define (语法错误 e) (exn:fail:syntax? e))
(define (用户错误 e) (exn:fail:user? e))

;; ==================== 错误消息构建器 ====================

(define (错误类型中文 type)
  (case type
    [(KEYWORD) "关键字"]
    [(IDENTIFIER) "名称"]
    [(NUMBER) "数字"]
    [(STRING) "字符串"]
    [(COLON) "冒号"]
    [(COMMA) "逗号"]
    [(INDENT) "缩进"]
    [(DEDENT) "取消缩进"]
    [(PIPE) "管道符"]
    [(NEWLINE) "换行"]
    [(LBRACKET) "左方括号"]
    [(RBRACKET) "右方括号"]
    [(FSTRING) "插值字符串"]
    [else (symbol->string type)]))

(define (构建错误消息 type message [line #f] [col #f] [suggestion #f])
  (define location 
    (if (and line col)
        (format "（第 ~a 行，第 ~a 列）" line col)
        (if line
            (format "（第 ~a 行）" line)
            "")))
  (define suggest 
    (if suggestion
        (format "\n💡 建议：~a" suggestion)
        ""))
  (format "[~a] ~a~a~a" (错误类型中文 type) message location suggest))

;; ==================== 统一错误抛出函数 ====================

(define (报错 msg)
  (raise-user-error msg))

(define (报错-with-location msg line [col #f])
  (define location
    (if col
        (format "~a（第 ~a 行，第 ~a 列）" msg line col)
        (format "~a（第 ~a 行）" msg line)))
  (raise-user-error location))

(define (报错-with-suggestion msg suggestion [line #f] [col #f])
  (define location
    (cond
      [(and line col) (format "（第 ~a 行，第 ~a 列）" line col)]
      [line (format "（第 ~a 行）" line)]
      [else ""]))
  (raise-user-error (format "~a~a\n💡 建议：~a" msg location suggestion)))

;; ==================== 尝试/捕获/始终 - 运行时宏 ====================

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