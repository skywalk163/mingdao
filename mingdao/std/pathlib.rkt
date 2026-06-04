#lang racket/base
(require racket/path)

(provide 路径/创建 路径/父目录 路径/名称 路径/主干 路径/后缀
         路径/存在 路径/是文件 路径/是目录
         路径/绝对 路径/解析
         路径/家目录 路径/临时目录)

(define (路径/创建 . parts)
  (apply build-path parts))

(define (路径/父目录 p)
  (define base (path->directory-path p))
  (if base base (string->path ".")))

(define (路径/名称 p)
  (path->string (file-name-from-path p)))

(define (路径/主干 p)
  (define name (路径/名称 p))
  (define ext (filename-extension p))
  (if ext
      (substring name 0 (- (string-length name)
                           (string-length (bytes->string/utf-8 ext))
                           1))
      name))

(define (路径/后缀 p)
  (define ext (filename-extension p))
  (if ext (bytes->string/utf-8 ext) ""))

(define (路径/存在 p)
  (or (file-exists? p) (directory-exists? p)))

(define (路径/是文件 p)
  (file-exists? p))

(define (路径/是目录 p)
  (directory-exists? p))

(define (路径/绝对 p)
  (path->complete-path p))

(define 路径/解析 resolve-path)

(define (路径/家目录)
  (find-system-path 'home-dir))

(define (路径/临时目录)
  (find-system-path 'temp-dir))