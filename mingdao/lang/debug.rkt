#lang racket/base

(require racket/list
         racket/string
         racket/format
         racket/match
         racket/pretty)

(provide 断言
         跟踪
         检查
         检查列表
         断点
         调试输出
         记录
         断点条件
         断点列表
         清除断点
         调用堆栈
         调试模式
         断言错误?)

;; ============================================================
;; 调试状态
;; ============================================================

(define debug-mode-param (make-parameter #f))
(define (调试模式 [new-val #f])
  (if new-val
      (debug-mode-param new-val)
      (debug-mode-param)))
(define breakpoints (make-parameter '()))
(define trace-depth (make-parameter 0))

;; ============================================================
;; 断言 — 运行时条件检查
;; ============================================================

(define (断言错误? obj)
  (and (exn:fail? obj)
       (string-prefix? (exn-message obj) "断言失败")))

(define (断言 condition [message ""])
  (unless condition
    (error (string-append
             "断言失败"
             (if (string=? message "") "" (string-append ": " message)))))
  condition)

;; ============================================================
;; 跟踪 — 函数调用跟踪
;; ============================================================

(define (跟踪 fn)
  (define name (object-name fn))
  (λ args
    (define depth (trace-depth))
    (trace-depth (add1 depth))
    (define indent (make-string (* depth 2) #\space))
    (printf "~a┌─ 进入 ~a 参数: ~a\n" indent name (map (λ (x) (if (procedure? x) '<procedure> x)) args))
    (flush-output)
    (define result
      (with-handlers ([exn:fail?
                       (λ (e)
                         (printf "~a└─ ✗ ~a 错误: ~a\n" indent name (exn-message e))
                         (flush-output)
                         (trace-depth depth)
                         (raise e))])
        (define val (apply fn args))
        (printf "~a└─ ✓ ~a 返回: ~a\n" indent name (if (procedure? val) '<procedure> val))
        (flush-output)
        (trace-depth depth)
        val))
    result))

;; ============================================================
;; 检查 — 变量/值输出
;; ============================================================

(define (检查 label val)
  (printf "╔══ 检查: ~a ══╗\n" label)
  (cond
    [(list? val)
     (printf "║ 类型: 列表 (长度 ~a)\n" (length val))
     (for ([i (in-range (length val))])
       (printf "║   [~a] ~a\n" i (list-ref val i)))]
    [(hash? val)
     (printf "║ 类型: 字典\n")
     (hash-for-each val (λ (k v) (printf "║   ~a => ~a\n" k v)))]
    [(procedure? val)
     (printf "║ 类型: 函数 (~a)\n" (object-name val))]
    [(boolean? val)
     (printf "║ 类型: 布尔值 → ~a\n" (if val "真值" "假值"))]
    [(number? val)
     (printf "║ 类型: 数字 → ~a\n" val)]
    [(string? val)
     (printf "║ 类型: 字符串 (长度 ~a) → \"~a\"\n" (string-length val) val)]
    [(void? val)
     (printf "║ 类型: 空值\n")]
    [else
     (printf "║ 类型: ~a → ~a\n" (类型名称 val) val)])
  (printf "╚══════════════════╝\n")
  (flush-output)
  val)

(define (类型名称 val)
  (cond [(list? val) "列表"]
        [(hash? val) "字典"]
        [(procedure? val) "函数"]
        [(boolean? val) "布尔值"]
        [(number? val) "数字"]
        [(string? val) "字符串"]
        [(void? val) "空值"]
        [(symbol? val) "符号"]
        [(char? val) "字符"]
        [(byte? val) "字节"]
        [else (format "~s" val)]))

(define (检查列表 label lst)
  (printf "╔══ 检查列表: ~a (共 ~a 项) ══╗\n" label (length lst))
  (for ([i (in-range (length lst))])
    (define item (list-ref lst i))
    (printf "║ [~a] " i)
    (cond
      [(list? item)
       (printf "列表 (长度 ~a): ~a\n" (length item) (take item (min 5 (length item))))]
      [(procedure? item) (printf "函数: ~a\n" (object-name item))]
      [else (printf "~a\n" item)]))
  (printf "╚══════════════════════════════╝\n")
  (flush-output))

;; ============================================================
;; 断点 — 执行暂停和交互式检查
;; ============================================================

(define (断点 [label "断点"])
  (printf "\n⚠ 断点: ~a\n" label)
  (printf "  输入 继续 恢复执行，输入 检查 <名> 检查变量\n")
  (printf "  输入 退出 终止程序\n")
  (flush-output)
  (let loop ()
    (printf "  ⚠ ")
    (flush-output)
    (define line (read-line))
    (cond
      [(eof-object? line) (void)]
      [(or (string-ci=? (string-trim line) "继续")
           (string-ci=? (string-trim line) "c"))
       (printf "  → 恢复执行\n") (flush-output)]
      [(string-prefix? (string-trim line) "检查 ")
       (printf "  警告: 断点内检查功能需要 REPL 支持\n")
       (flush-output)
       (loop)]
      [(or (string-ci=? (string-trim line) "退出")
           (string-ci=? (string-trim line) "q"))
       (error "用户终止程序")]
      [else
       (printf "  未知命令: ~a\n" (string-trim line))
       (loop)])))

(define (断点条件 condition label)
  (when condition
    (断点 label)))

(define (断点列表)
  (breakpoints))

(define (清除断点)
  (breakpoints '()))

;; ============================================================
;; 调试输出 — 条件化日志
;; ============================================================

(define (调试输出 label val)
  (when (调试模式)
    (printf "🐞 [~a] ~a\n" label val)
    (flush-output))
  val)

;; 结构化日志
(define 日志级别 (make-parameter 'info))

(define (记录 level label 消息)
  (define 级别列表 '(debug info warn error))
  (define 级别图标 '(("debug" . "🐛") ("info" . "ℹ") ("warn" . "⚠") ("error" . "✗")))
  (define level-sym (if (string? level) (string->symbol level) level))
  (when (>= (index-of 级别列表 level-sym) (index-of 级别列表 (日志级别)))
    (define icon (cdr (assoc (format "~a" level-sym) 级别图标)))
    (printf "~a [~a] ~a: ~a\n" icon (string-upcase (format "~a" level-sym)) label 消息)
    (flush-output)))

;; ============================================================
;; 调用堆栈 — 运行时调用信息
;; ============================================================

(define (调用堆栈)
  (printf "╔══ 调用堆栈 ══╗\n")
  (with-handlers ([exn:fail? (λ (e) (void))])
    (raise (error "stack-trace")))
  (printf "╚══════════════╝\n")
  (flush-output))