#lang racket/base

(define (test input)
  (define pos 0)
  (define chars (string->list input))
  
  (define (peek [offset 0])
    (if (< (+ pos offset) (length chars))
        (list-ref chars (+ pos offset))
        #f))
  
  (define (advance)
    (set! pos (add1 pos)))
  
  (define (中文? ch) #f)
  
  ;; 定义1：辅助函数
  (define (can-form-keyword? ch) #f)
  
  ;; 定义2：读取标识符
  (define (read-identifier first-char)
    (define start-col 0)
    (define id-chars (list first-char))
    (let loop ()
      (let ([ch (peek)])
        (if (and ch (中文? ch) (can-form-keyword? ch))
            (list->string (reverse id-chars))
            (begin
              (when ch
                (set! id-chars (cons ch id-chars))
                (advance)
                (loop)))
            ))))
  
  ;; 定义3：tokens
  (define tokens '())
  
  ;; 表达式：main-loop
  (let main-loop ()
    (define ch (peek))
    (if ch
        (begin
          (advance)
          (main-loop))
        tokens)))

(test "hello")
