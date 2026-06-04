#lang racket/base

;; 测试内部定义位置
(define (test input)
  (define pos 0)
  (define chars (string->list input))
  
  (define (peek)
    (if (< pos (length chars))
        (list-ref chars pos)
        #f))
  
  (define (advance)
    (set! pos (add1 pos)))
  
  ;; 问题：在表达式之前有定义
  (define tokens '())
  
  (let main-loop ()
    (define ch (peek))
    (if ch
        (begin
          (advance)
          (main-loop))
        tokens)))

(test "hello")
