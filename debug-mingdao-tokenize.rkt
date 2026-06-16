#lang racket/base

(require racket/port racket/file racket/string racket/list racket/class)

(define project-root (build-path (current-directory) "mingdao"))

;; 加载核心库
(define ns (make-base-namespace))
(parameterize ([current-namespace ns])
  (define core-path (build-path project-root "core.rkt"))
  (eval `(require (file ,(path->string core-path)))))

;; 读取并加载 tokenizer.mingdao
(define (read-utf8-file path)
  (define in (open-input-file path))
  (define chunks '())
  (let loop ()
    (define b (read-bytes 4096 in))
    (if (eof-object? b) (void)
        (begin (set! chunks (cons b chunks)) (loop))))
  (close-input-port in)
  (bytes->string/utf-8 (apply bytes-append (reverse chunks))))

(define tokenizer-source (read-utf8-file (build-path project-root "std/tokenizer.mingdao")))

;; 加载 Racket 版 tokenizer 和 parser
(require "mingdao/lang/tokenizer.rkt" "mingdao/lang/parser.rkt")

;; 加载明道版源码
(printf "Loading tokenizer.mingdao...\n")
(define tokens (tokenize tokenizer-source))
(define ast (parse tokens))

(parameterize ([current-namespace ns])
  (for ([expr ast] [i (in-naturals)])
    (with-handlers ([exn:fail? (λ (e)
                                 (printf "Error at expr #~a: ~a\n" i (exn-message e)))])
      (eval expr))))

(printf "Tokenizer loaded successfully\n")

;; 测试分词
(printf "\nTesting tokenize function:\n")
(define test-code "42")
(printf "Code: ~a\n" test-code)

(parameterize ([current-namespace ns])
  (define result (eval `(分词 ,test-code)))
  (printf "Result type: ~a\n" (type-of result))
  (printf "Result: ~a\n" result))

(define (type-of x)
  (cond
    [(list? x) "list"]
    [(string? x) "string"]
    [(number? x) "number"]
    [(symbol? x) "symbol"]
    [(procedure? x) "procedure"]
    [else (format "~a" x)]))