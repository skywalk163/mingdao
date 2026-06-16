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

;; 检查创建Token是否存在
(printf "\n=== Test 1: Check 创建Token ===\n")
(parameterize ([current-namespace ns])
  (define func (eval '创建Token))
  (printf "创建Token exists: ~a\n" (not (eq? func #f)))
  (printf "创建Token is procedure: ~a\n" (procedure? func)))

;; 测试2: 用 Racket 方式调用函数
(printf "\n=== Test 2: Call 创建Token with Racket syntax ===\n")
(parameterize ([current-namespace ns])
  (with-handlers ([exn:fail? (λ (e) (printf "Error: ~a\n" (exn-message e)))])
    (define result (eval '(创建Token "NUMBER" "42" 1 1)))
    (printf "Result: ~a\n" result)))

;; 测试3: 查看 分词 函数
(printf "\n=== Test 3: Check 分词 ===\n")
(parameterize ([current-namespace ns])
  (define func (eval '分词))
  (printf "分词 exists: ~a\n" (not (eq? func #f)))
  (printf "分词 is procedure: ~a\n" (procedure? func)))