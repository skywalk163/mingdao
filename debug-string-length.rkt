#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

(define test-code "字符串长度")
(displayln "Testing code:")
(displayln test-code)
(displayln "Tokens:")

(define tokens (tokenize test-code))
(for ([tok tokens])
  (printf "  ~a: ~a (col ~a)\n"
          (token-type tok)
          (token-value tok)
          (token-col tok)))