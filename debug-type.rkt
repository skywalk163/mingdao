#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

;; Test cases
(define test-cases
  '("类型"
    "类型值"
    "令牌类型"
    "令牌类型就是函"))

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