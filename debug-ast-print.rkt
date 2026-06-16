#lang racket/base

(require racket/port racket/file racket/string racket/list)
(require "mingdao/lang/tokenizer.rkt" "mingdao/lang/parser.rkt")

(define project-root (build-path (current-directory) "mingdao"))

(define (read-utf8-file path)
  (define in (open-input-file path))
  (define chunks '())
  (let loop ()
    (define b (read-bytes 4096 in))
    (if (eof-object? b) (void)
        (begin (set! chunks (cons b chunks)) (loop))))
  (close-input-port in)
  (bytes->string/utf-8 (apply bytes-append (reverse chunks))))

;; 加载核心库
(define ns (make-base-namespace))
(parameterize ([current-namespace ns])
  (define core-path (build-path project-root "core.rkt"))
  (eval `(require (file ,(path->string core-path)))))

;; 加载 tokenizer.mingdao
(define tokenizer-source (read-utf8-file (build-path project-root "std/tokenizer.mingdao")))
(define tokens (tokenize tokenizer-source))
(define ast (parse tokens))

;; 打印前10个 AST 表达式
(printf "First 10 AST expressions:\n")
(for ([expr (take ast (min 10 (length ast)))]
      [i (in-naturals)])
  (printf "#~a: ~a\n" i expr))

(printf "\n---\nTotal expressions: ~a\n" (length ast))