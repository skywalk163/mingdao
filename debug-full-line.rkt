#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

(define test-code "赋值then分支为索引(体结果,0)")
(displayln "Testing code:")
(displayln test-code)
(displayln "Tokens:")

(define tokens (tokenize test-code))
(for ([tok tokens])
  (printf "  ~a: ~a (col ~a)\n"
          (token-type tok)
          (token-value tok)
          (token-col tok)))