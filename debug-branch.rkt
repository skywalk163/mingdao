#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

;; Test tokenization of 分支为
(define test-code "分支为")
(displayln "Testing code:")
(displayln test-code)
(displayln "Tokens:")

(define tokens (tokenize test-code))
(for ([tok tokens])
  (printf "  ~a: ~a (col ~a)\n"
          (token-type tok)
          (token-value tok)
          (token-col tok)))

;; Also test the full line
(displayln "\n===========================================")
(define test-code2 "赋值then分支为索引(体结果,0)")
(displayln "Testing full line:")
(displayln test-code2)
(displayln "Tokens:")

(define tokens2 (tokenize test-code2))
(for ([tok tokens2])
  (printf "  ~a: ~a (col ~a)\n"
          (token-type tok)
          (token-value tok)
          (token-col tok)))