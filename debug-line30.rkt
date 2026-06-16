#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

(define test-code "否则：(是否相等,(令牌类型,令牌),类型)")
(displayln "Testing code:")
(displayln test-code)
(displayln "Tokens:")

(define tokens (tokenize test-code))
(for ([tok tokens])
  (printf "  ~a: ~a (col ~a)\n"
          (token-type tok)
          (token-value tok)
          (token-col tok)))