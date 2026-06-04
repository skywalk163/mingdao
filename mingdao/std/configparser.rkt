#lang racket/base
(require racket/list
         racket/string
         racket/hash
         racket/port)

(provide 配置/创建 配置/读取文件 配置/读取字符串 配置/获取 配置/获取整数
         配置/获取浮点 配置/获取布尔 配置/设置 配置/删除
         配置/有节 配置/有选项 配置/节列表 配置/选项列表
         配置/添加节 配置/移除节 配置/写入 配置/节转字典
         配置/默认节)

(struct 配置/配置器 (data default-section) #:transparent)

(define (配置/创建 [default-section "DEFAULT"])
  (配置/配置器 (make-hash) default-section))

(define (配置/读取文件 config path)
  (define content (with-input-from-file path (lambda () (port->string))))
  (配置/读取字符串 config content))

(define (配置/读取字符串 config content)
  (define data (配置/配置器-data config))
  (define default-section (配置/配置器-default-section config))
  (define lines (string-split content "\n"))
  (define current-section default-section)
  (for-each (lambda (line)
              (define trimmed (string-trim line))
              (when (and (> (string-length trimmed) 0)
                        (not (char=? (string-ref trimmed 0) #\;))
                        (not (char=? (string-ref trimmed 0) #\#)))
                (define section-match (regexp-match #rx"^\\[([^]]+)\\]" trimmed))
                (define kv-match (regexp-match #rx"^([^=]+)=(.*)" trimmed))
                (cond
                  [section-match
                   (set! current-section (cadr section-match))
                   (unless (hash-has-key? data current-section)
                     (hash-set! data current-section (make-hash)))]
                  [kv-match
                   (define key (string-trim (cadr kv-match)))
                   (define val (string-trim (caddr kv-match)))
                   (unless (hash-has-key? data current-section)
                     (hash-set! data current-section (make-hash)))
                   (define section-hash (hash-ref data current-section))
                   (hash-set! section-hash key val)])))
            lines)
  config)

(define (配置/获取 config section option)
  (define data (配置/配置器-data config))
  (define default-section (配置/配置器-default-section config))
  (define section-hash (hash-ref data section #f))
  (define default-hash (hash-ref data default-section #f))
  (cond
    [section-hash
     (hash-ref section-hash option
               (lambda ()
                 (if default-hash
                     (hash-ref default-hash option (lambda () #f))
                     #f)))]
    [default-hash
     (hash-ref default-hash option (lambda () #f))]
    [else #f]))

(define (配置/获取整数 config section option)
  (define val (配置/获取 config section option))
  (if val (string->number val) #f))

(define (配置/获取浮点 config section option)
  (define val (配置/获取 config section option))
  (if val (string->number val) #f))

(define (配置/获取布尔 config section option)
  (define val (配置/获取 config section option))
  (if val
      (member (string-downcase val) '("1" "yes" "true" "on"))
      #f))

(define (配置/设置 config section option value)
  (define data (配置/配置器-data config))
  (unless (hash-has-key? data section)
    (hash-set! data section (make-hash)))
  (define section-hash (hash-ref data section))
  (hash-set! section-hash option value))

(define (配置/删除 config section option)
  (define data (配置/配置器-data config))
  (define section-hash (hash-ref data section #f))
  (when section-hash
    (hash-remove! section-hash option)))

(define (配置/有节 config section)
  (define data (配置/配置器-data config))
  (hash-has-key? data section))

(define (配置/有选项 config section option)
  (define data (配置/配置器-data config))
  (define section-hash (hash-ref data section #f))
  (if section-hash
      (hash-has-key? section-hash option)
      #f))

(define (配置/节列表 config)
  (define data (配置/配置器-data config))
  (hash-keys data))

(define (配置/选项列表 config section)
  (define data (配置/配置器-data config))
  (define section-hash (hash-ref data section #f))
  (if section-hash (hash-keys section-hash) '()))

(define (配置/添加节 config section)
  (define data (配置/配置器-data config))
  (unless (hash-has-key? data section)
    (hash-set! data section (make-hash))))

(define (配置/移除节 config section)
  (define data (配置/配置器-data config))
  (hash-remove! data section))

(define (配置/写入 config [port (current-output-port)])
  (define data (配置/配置器-data config))
  (for-each (lambda (section)
              (when (not (equal? section (配置/配置器-default-section config)))
                (fprintf port "[~a]\n" section))
              (define section-hash (hash-ref data section))
              (for-each (lambda (key)
                          (fprintf port "~a = ~a\n" key (hash-ref section-hash key)))
                        (hash-keys section-hash))
              (newline port))
            (hash-keys data)))

(define (配置/节转字典 config [section #f])
  (define data (配置/配置器-data config))
  (if section
      (hash-ref data section (lambda () #hash()))
      data))

(define (配置/默认节 config)
  (配置/配置器-default-section config))