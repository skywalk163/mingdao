#lang racket/base

(require racket/port racket/file racket/string racket/list)
(require "mingdao/lang/tokenizer.rkt" "mingdao/lang/parser.rkt")

;; 读取 tokenizer.mingdao
(define (read-utf8-file path)
  (define in (open-input-file path))
  (define chunks '())
  (let loop ()
    (define b (read-bytes 4096 in))
    (if (eof-object? b) (void)
        (begin (set! chunks (cons b chunks)) (loop))))
  (close-input-port in)
  (bytes->string/utf-8 (apply bytes-append (reverse chunks))))

(define tokenizer-source (read-utf8-file "mingdao/std/tokenizer.mingdao"))

;; 测试完整解析
(printf "Testing full tokenizer.mingdao parsing...\n")
(with-handlers ([exn:fail? (λ (e) (printf "Error: ~a\n" (exn-message e)))])
  (define tokens (tokenize tokenizer-source))
  (printf "Tokenization succeeded, ~a tokens\n" (length tokens))
  (define ast (parse tokens))
  (printf "Parsing succeeded, ~a top-level expressions\n" (length ast))
  (printf "First 3 AST expressions:\n")
  (for ([expr (take ast (min 3 (length ast)))])
    (printf "  ~a\n" expr)))