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

;; 测试解析第64行
(define test-code "列表,创建Token,\"STRING\",列表转字符串(反转(收集)),行,列,(加,位置,1),行,(加,列,1)")
(printf "Testing code: ~a\n" test-code)

(define tokens (tokenize test-code))
(printf "Tokens:\n")
(for ([tok tokens])
  (printf "  ~a: ~a\n" (token-type tok) (token-value tok)))

(define ast (parse tokens))
(printf "AST: ~a\n" ast)