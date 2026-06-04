#lang racket/base

;; 精确模拟 tokenizer 末尾结构
(define (test input)
  (define tokens '())
  
  (let main-loop ()
    (let ([ch #f])
      (cond
        [(not ch) 'done]
        [else
         (let* ([x "test"]
                [y "msg"])
           (error 'test
                  (format "~a ~a"
                          x y)))]))))  ; 关闭: ) ] ) ) )

(test "hello")
