#lang racket/base
(require racket/port
         racket/string
         racket/file)

(provide io/打开文件 io/读取全部 io/读取行 io/读取字符
         io/写入 io/写入行 io/写入字符串
         io/关闭 io/刷新
         io/字符串输入 io/字符串输出 io/获取输出值
         io/字节输入 io/字节输出 io/获取字节输出
         io/管道 io/缓冲输入
         io/文件输入 io/文件输出 io/追加输出
         io/临时文件 io/临时目录
         io/行迭代 io/读取字节 io/写入字节
         io/复制 io/是否输入 io/是否输出 io/可读 io/可写
         io/位置 io/定位 io/截断
         io/读取行号 io/行号)

(define (io/打开文件 path mode)
  (case mode
    [(read "r") (open-input-file path)]
    [(write "w") (open-output-file path #:exists 'replace)]
    [(append "a") (open-output-file path #:exists 'append)]
    [(update "r+") (open-input-output-file path #:exists 'update)]
    [else (error (format "不支持的打开模式: ~a" mode))]))

(define (io/读取全部 port)
  (port->string port))

(define (io/读取行 port)
  (define line (read-line port))
  (if (eof-object? line) #f line))

(define (io/读取字符 port)
  (define c (read-char port))
  (if (eof-object? c) #f c))

(define (io/读取字节 port)
  (define b (read-byte port))
  (if (eof-object? b) #f b))

(define (io/写入 port val)
  (display val port))

(define (io/写入行 port [val #f])
  (if val
      (begin (display val port) (newline port))
      (newline port)))

(define (io/写入字符串 port str)
  (write-string str port))

(define (io/写入字节 port bstr)
  (write-bytes bstr port))

(define (io/关闭 port)
  (when (input-port? port) (close-input-port port))
  (when (output-port? port) (close-output-port port)))

(define (io/刷新 port)
  (flush-output port))

(define (io/字符串输入 str)
  (open-input-string str))

(define (io/字符串输出)
  (open-output-string))

(define (io/获取输出值 port)
  (get-output-string port))

(define (io/字节输入 bstr)
  (open-input-bytes bstr))

(define (io/字节输出)
  (open-output-bytes))

(define (io/获取字节输出 port)
  (get-output-bytes port))

(define (io/管道)
  (make-pipe))

(define (io/缓冲输入 port [size 4096])
  port)

(define (io/文件输入 path)
  (open-input-file path))

(define (io/文件输出 path)
  (open-output-file path #:exists 'replace))

(define (io/追加输出 path)
  (open-output-file path #:exists 'append))

(define (io/临时文件 [template "tmp"])
  (define tmpdir (find-system-path 'temp-dir))
  (define name (string-append template (number->string (random 1000000))))
  (define path (build-path tmpdir name))
  (define port (open-output-file path #:exists 'replace))
  (values port path))

(define (io/临时目录 [template "tmp"])
  (define tmpdir (find-system-path 'temp-dir))
  (define name (string-append template (number->string (random 1000000))))
  (define path (build-path tmpdir name))
  (make-directory path)
  path)

(define (io/行迭代 port)
  (in-lines port))

(define (io/复制 src dst)
  (define buf (make-bytes 4096))
  (let loop ()
    (define n (read-bytes! buf src))
    (when (not (eof-object? n))
      (write-bytes buf dst 0 n)
      (loop))))

(define (io/是否输入 port)
  (input-port? port))

(define (io/是否输出 port)
  (output-port? port))

(define (io/可读 port)
  (input-port? port))

(define (io/可写 port)
  (output-port? port))

(define (io/位置 port)
  (file-position port))

(define (io/定位 port pos)
  (file-position port pos))

(define (io/截断 port size)
  (file-truncate port size))

(define (io/读取行号 port)
  (read-line port))

(define (io/行号 port)
  (error "io/行号: 当前Racket版本不支持"))