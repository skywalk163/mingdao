#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

;; Test tokenization of 退栈
(define test-cases
  '("退栈"
    "生成退栈"
    "定义新栈就是退栈"))

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