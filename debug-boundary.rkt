#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

(define (test-boundary-keyword?)
  (displayln "Testing boundary-keyword? function:")
  (displayln "=====================================")
  
  (define test-chars '(#\为 #\从 #\到 #\x #\5))
  
  (for ([ch test-chars])
    (printf "char: ~a, boundary-keyword?: ~a\n" ch (boundary-keyword? ch))))

(test-boundary-keyword?)