#lang racket/base

(define (test)
  (define x 1)
  
  (let main-loop ()
    (let ([ch #\a])
      (cond
        [(char=? ch #\b)
         (displayln "b")]
        [else
         (let* ([desc "test"]
                [msg "message"])
           (error 'test "~a ~a" desc msg))]))))

(test)
