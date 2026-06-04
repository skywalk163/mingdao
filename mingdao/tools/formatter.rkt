#lang racket/base

(require racket/string
         racket/match
         racket/path
         racket/list
         racket/file)

(provide format-code
         format-file
         format-string
         format-directory)

;; 缩进配置
(define INDENT "    ")

;; 格式化代码
(define (format-code code)
  (define lines (string-split code "\n" #:trim? #f))
  (define formatted-lines (process-lines lines 0))
  (string-join formatted-lines "\n"))

;; 处理每一行
(define (process-lines lines initial-indent)
  (let loop ([lines lines]
             [indent initial-indent]
             [result '()])
    (if (null? lines)
        (reverse result)
        (let* ([line (string-trim (car lines))]
               [new-indent (compute-indent line indent)]
               [formatted-line (format-line line new-indent)])
          (loop (cdr lines)
                new-indent
                (cons formatted-line result))))))

;; 计算缩进
(define (compute-indent line current-indent)
  (cond
    [(string-prefix? line "那么:") (+ current-indent 1)]
    [(string-prefix? line "否则:") (+ current-indent 1)]
    [(string-prefix? line "对于:") (+ current-indent 1)]
    [(string-prefix? line "类:") (+ current-indent 1)]
    [(string-prefix? line "接口:") (+ current-indent 1)]
    [(or (string-prefix? line "那么")
         (string-prefix? line "否则")
         (string-prefix? line "跳出")
         (string-prefix? line "继续")
         (string-prefix? line "返回"))
     (max 0 (- current-indent 1))]
    [else current-indent]))

;; 格式化单行
(define (format-line line indent)
  (if (string=? (string-trim line) "")
      ""
      (string-append (make-indent-string indent)
                   (string-trim line))))

;; 生成缩进字符串
(define (make-indent-string indent-level)
  (apply string-append (make-list indent-level INDENT)))

;; 格式化文件
(define (format-file file-path)
  (define content (file->string file-path))
  (define formatted (format-code content))
  (display-to-file formatted file-path #:exists 'truncate)
  (printf "格式化完成: ~a\n" file-path))

;; 格式化字符串
(define (format-string str)
  (format-code str))

;; 格式化目录
(define (format-directory dir-path)
  (for ([file (in-directory dir-path)])
    (when (string-suffix? (path->string file) ".mingdao")
      (format-file file))))
