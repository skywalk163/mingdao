#lang racket/base

;; 测试 tokenize 函数的结构

(define (test-tokenize input)
  (define pos 0)
  
  (define (peek)
    #f)
  
  (define tokens '())
  
  ;; 问题：let main-loop 是最后一个表达式，它返回什么？
  (let main-loop ()
    (define ch (peek))
    (cond
      [(not ch) (reverse tokens)]  ;; 这个返回值
      [else
       (error 'test "error")])))

;; 这个结构是正确的，因为 let main-loop 会返回 cond 的结果
;; 当 cond 的某个分支返回值时，let 表达式就返回那个值

(test-tokenize "test")
