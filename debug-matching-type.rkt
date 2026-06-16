#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

(define test-code "定义匹配类型判断就是函令牌列表,位置：")
(displayln "Testing code:")
(displayln test-code)
(displayln "Tokens:")

(define tokens (tokenize test-code))
(for ([tok tokens])
  (printf "  ~a: ~a (col ~a)\n"
          (token-type tok)
          (token-value tok)
          (token-col tok)))