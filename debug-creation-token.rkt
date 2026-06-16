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

(parameterize ([current-namespace ns])
  (for ([expr ast] [i (in-naturals)])
    (with-handlers ([exn:fail? (λ (e) (printf "Error at expr #~a: ~a\n" i (exn-message e)))])
      (eval expr))))

(printf "Tokenizer loaded successfully\n")

;; 测试1: 创建一个 token
(printf "\n=== Test 1: Create a token ===\n")
(parameterize ([current-namespace ns])
  (define test-token (eval '(创建Token "NUMBER" 42 1 1)))
  (printf "Token: ~a\n" test-token)
  (printf "Token type: ~a\n" (type-of test-token))
  (printf "Is list? ~a\n" (list? test-token))
  (printf "List length: ~a\n" (length test-token)))

;; 测试2: 检查分词
(printf "\n=== Test 2: Try tokenize \"42\" ===\n")
(parameterize ([current-namespace ns])
  (with-handlers ([exn:fail? (λ (e) (printf "Error: ~a\n" (exn-message e)))])
    (define result (eval '(分词 "42")))
    (printf "Result: ~a\n" result)
    (if (list? result)
        (begin
          (printf "Is list: yes, length: ~a\n" (length result))
          (when (> (length result) 0)
            (printf "First element: ~a\n" (first result))))
        (printf "Not a list\n"))))

(define (type-of x)
  (cond
    ((list? x) "list")
    ((string? x) "string")
    ((number? x) "number")
    ((symbol? x) "symbol")
    ((procedure? x) "procedure")
    (else "unknown")))