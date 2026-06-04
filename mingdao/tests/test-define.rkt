#lang racket/base

;; 测试内部定义位置
(define (test-define-position)
  (define x 1)
  (define y 2)
  
  (define (helper1)
    (displayln "helper1"))
  
  (define (helper2)
    (displayln "helper2"))
  
  (define (inner-func arg)
    (define a 10)
    (define b 20)
    (+ arg a b))
  
  (helper1)
  (inner-func x))

(test-define-position)
