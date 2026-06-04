#lang racket/base

(require racket/port racket/format racket/file racket/string)

(provide
 日志/调试 日志/信息 日志/警告 日志/错误 日志/严重
 日志/基本配置 日志/获取日志器 日志/设置级别
 日志/添加处理器 日志/移除处理器
 日志/DEBUG 日志/INFO 日志/WARNING 日志/ERROR 日志/CRITICAL
 日志/流处理器 日志/文件处理器 日志/格式器 日志/设置格式)

(define 日志/DEBUG 0)
(define 日志/INFO 1)
(define 日志/WARNING 2)
(define 日志/ERROR 3)
(define 日志/CRITICAL 4)

(define LEVEL-NAMES
  (hash 0 "DEBUG" 1 "INFO" 2 "WARNING" 3 "ERROR" 4 "CRITICAL"))

(struct 日志器 (name level handlers) #:mutable)
(struct 处理器 (name level formatter output-port) #:mutable)
(struct 格式器 (fmt) #:mutable)

(define (日志/获取日志器 name)
  (日志器 name 日志/DEBUG null))

(define (日志/设置级别 logger level)
  (set-日志器-level! logger level))

(define (日志/添加处理器 logger handler)
  (set-日志器-handlers! logger (cons handler (日志器-handlers logger))))

(define (日志/移除处理器 logger handler)
  (set-日志器-handlers! logger
    (filter (lambda (h) (not (eq? h handler))) (日志器-handlers logger))))

(define (日志/格式器 fmt)
  (格式器 fmt))

(define (日志/设置格式 handler fmt)
  (set-格式器-fmt! (处理器-formatter handler) fmt))

(define (日志/流处理器 name level fmt port)
  (处理器 name level fmt port))

(define (日志/文件处理器 name level fmt path)
  (处理器 name level fmt (open-output-file path #:exists 'append)))

(define (日志/基本配置 #:level [level 日志/DEBUG]
                       #:format [fmt "[~a] ~a: ~a~n"])
  (define default-logger (日志/获取日志器 "root"))
  (日志/设置级别 default-logger level)
  (define formatter (日志/格式器 fmt))
  (define handler (日志/流处理器 "console" level formatter (current-output-port)))
  (日志/添加处理器 default-logger handler)
  default-logger)

(define (format-message logger handler msg)
  (define fmt (格式器-fmt (处理器-formatter handler)))
  (define level-name (hash-ref LEVEL-NAMES (日志器-level logger) "UNKNOWN"))
  (define timestamp "2026-06-02")
  (define formatted
    (string-replace
      (string-replace
        (string-replace fmt "~a" level-name)
        "~s" (~a msg))
      "~n" (string #\newline)))
  formatted)

(define (日志/调试 logger msg)
  (when (<= 日志/DEBUG (日志器-level logger))
    (for-each (lambda (h)
                (when (<= 日志/DEBUG (处理器-level h))
                  (fprintf (处理器-output-port h) "~a" (format-message logger h msg))))
              (日志器-handlers logger))))

(define (日志/信息 logger msg)
  (when (<= 日志/INFO (日志器-level logger))
    (for-each (lambda (h)
                (when (<= 日志/INFO (处理器-level h))
                  (fprintf (处理器-output-port h) "~a" (format-message logger h msg))))
              (日志器-handlers logger))))

(define (日志/警告 logger msg)
  (when (<= 日志/WARNING (日志器-level logger))
    (for-each (lambda (h)
                (when (<= 日志/WARNING (处理器-level h))
                  (fprintf (处理器-output-port h) "~a" (format-message logger h msg))))
              (日志器-handlers logger))))

(define (日志/错误 logger msg)
  (when (<= 日志/ERROR (日志器-level logger))
    (for-each (lambda (h)
                (when (<= 日志/ERROR (处理器-level h))
                  (fprintf (处理器-output-port h) "~a" (format-message logger h msg))))
              (日志器-handlers logger))))

(define (日志/严重 logger msg)
  (when (<= 日志/CRITICAL (日志器-level logger))
    (for-each (lambda (h)
                (when (<= 日志/CRITICAL (处理器-level h))
                  (fprintf (处理器-output-port h) "~a" (format-message logger h msg))))
              (日志器-handlers logger))))