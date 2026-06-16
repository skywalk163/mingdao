#lang racket/base

(require racket/port racket/file racket/string racket/list)

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

;; 测试1: 检查打印函数是否工作
(printf "\n=== Test 1: Basic function call ===\n")
(parameterize ([current-namespace ns])
  (with-handlers ([exn:fail? (λ (e) (printf "Error: ~a\n" (exn-message e)))])
    (eval '(打印,"hello"))))

;; 测试2: 检查创建Token函数是否存在
(printf "\n=== Test 2: Check 创建Token ===\n")
(define create-token-func #f)
(parameterize ([current-namespace ns])
  (set! create-token-func (eval '创建Token))
  (printf "创建Token exists: ~a\n" (not (eq? create-token-func #f)))
  (printf "创建Token is procedure: ~a\n" (procedure? create-token-func)))

;; 测试3: 检查分词函数是否存在
(printf "\n=== Test 3: Check 分词 ===\n")
(define tokenize-func #f)
(parameterize ([current-namespace ns])
  (set! tokenize-func (eval '分词))
  (printf "分词 exists: ~a\n" (not (eq? tokenize-func #f)))
  (printf "分词 is procedure: ~a\n" (procedure? tokenize-func)))

;; 测试4: 尝试调用分词
(printf "\n=== Test 4: Try tokenize ===\n")
(parameterize ([current-namespace ns])
  (with-handlers ([exn:fail? (λ (e) (printf "Error: ~a\n" (exn-message e)))])
    (define result (eval '(分词,"42")))
    (printf "Result: ~a\n" result)))