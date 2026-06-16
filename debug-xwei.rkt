#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

;; Test tokenization step by step
(define test-cases
  '("x为"
    "x为5"
    "x为索引"))

(displayln "Testing tokenization:")
(for ([code test-cases])
  (displayln "===========================================")
  (displayln code)
  (displayln "Tokens:")
  (define tokens (tokenize code))
  (for ([tok tokens])
    (printf "  ~a: ~a (col ~a)\n"
            (token-type tok)
            (token-value tok)
            (token-col tok))))