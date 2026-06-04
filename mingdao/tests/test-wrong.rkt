#lang racket

;; 错误示例：在表达式后面有定义
(define (wrong-function x)
  (define y 1)
  ;; 这是一个表达式
  (let loop ()
    #f)
  ;; 错误！在表达式后面有定义
  (define z 2)  
  z)

;; 正确示例：所有定义都在表达式前面
(define (correct-function x)
  (define y 1)
  (define z 2)  
  (let loop ()
    #f))
