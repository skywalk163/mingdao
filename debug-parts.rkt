#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

;; Test tokenization of individual parts
(define test-cases
  '("then分支"
    "分支为"
    "为索引"))

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