#lang racket

;; 测试需要多少个右括号
(define (test-tokenize)
  (define chars '())
  (define pos 0)
  (define line 1)
  (define col 1)
  (define indent-stack '(0))
  
  (define (peek [offset 0]) #f)
  (define (advance) (void))
  (define (advance-line) (void))
  (define (空白? ch) #f)
  (define (换行? ch) #f)
  (define (中文? ch) #f)
  (define (compute-indent-level) 0)
  (define (read-string q) '())
  (define (read-number c) '())
  (define (read-identifier c) '())
  (define (can-form-keyword? c) #f)
  
  (define tokens '())
  
  (let main-loop ()
    (let ([ch (peek)])
      (cond
        [(not ch) 
         (reverse tokens)]
        
        [(换行? ch)
         (main-loop)]
        
        [(空白? ch)
         (main-loop)]
        
        [else
         (let* ([字符描述 "test"]
                [建议 "msg"])
           (error 'tokenize 
                  (format "无法识别的字符: ~a" 
                          字符描述)))]))))  ; 6个右括号

(test-tokenize)
