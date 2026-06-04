#lang racket/base

;; 模拟 tokenize 内部结构
(define (tokenize input)
  (define chars (string->list input))
  (define pos 0)
  
  (define (peek [offset 0])
    (if (< (+ pos offset) (length chars))
        (list-ref chars (+ pos offset))
        #f))
  
  (define (advance)
    (set! pos (add1 pos)))
  
  ;; 测试：在表达式之后定义函数
  (displayln "before func definition")
  
  (define (can-form-keyword? first-ch)
    (and (char? first-ch)
         (let ([next1 (peek)]
               [next2 (peek 1)])
           (cond
             [(and next1 next2 (member (string first-ch next1 next2) '("定义")))
              2]
             [else #f]))))
  
  (displayln "after func definition")
  (can-form-keyword? (peek)))

(tokenize "定义x")
