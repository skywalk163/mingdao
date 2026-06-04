#lang racket/base
;; 测试斐波那契

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         racket/port)

(define code #<<CODE
定义 斐波那契 就是函 n:
    如果 n 小于等于 1 那么:
        返回 n
    否则:
        返回 (斐波那契, n 减 1) 加 (斐波那契, n 减 2)

对于 i 从 0 到 10:
    打印, 斐波那契, i
CODE
)

(define ns (make-base-namespace))
(parameterize ([current-namespace ns])
  (define core-path (path->string (build-path (current-directory) ".." "core.rkt")))
  (eval `(require (file ,core-path)))
  (void))

(define (eval-and-capture expr)
  (define output-port (open-output-string))
  (parameterize ([current-output-port output-port]
                 [current-error-port output-port]
                 [current-namespace ns])
    (with-handlers ([exn:fail? (λ (e) (displayln (format "错误: ~a" (exn-message e))))])
      (define result (eval expr))
      (unless (void? result)
        (displayln result))))
  (define output (get-output-string output-port))
  (close-output-port output-port)
  output)

(define tokens (tokenize code))
(define ast (parse tokens))
(displayln "AST:")
(for ([expr ast])
  (displayln expr))
(newline)
(displayln "输出:")
(for ([expr ast])
  (eval-and-capture expr))
(flush-output)