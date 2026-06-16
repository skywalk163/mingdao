#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

;; Test boundary-keyword? with different inputs
(define test-chars
  (list #\为 #\分 #\支 #\索 #\引))

(displayln "Testing boundary-keyword? for different characters:")
(for ([ch test-chars])
  (printf "  ~a: ~a\n" ch (boundary-keyword? ch)))