#lang racket/base

(require "tokenizer.rkt"
         "parser.rkt"
         "error.rkt"
         racket/port
         racket/pretty)

(provide read read-syntax)

(define (read in)
  (define content (port->string in))
  (if (string=? content "")
      eof
      (with-handlers ([exn:fail?
                       (λ (e)
                         (parameterize ([current-error-port (current-output-port)])
                           (displayln "=== 明道语言解析错误 ===")
                           (displayln (格式化异常 e content))
                           (raise e)))])
        (let ([ast (parse (tokenize content))])
          `(module 明道 racket/base
             (require (lib "core.rkt" "mingdao"))
             ,@ast)))))

(define (read-syntax src in)
  (define content (port->string in))
  (if (string=? content "")
      eof
      (with-handlers ([exn:fail?
                       (λ (e)
                         (displayln "=== 明道语言解析错误 ===" (current-error-port))
                         (displayln (格式化异常 e content) (current-error-port))
                         (raise e))])
        (let ([ast (parse (tokenize content))])
          (datum->syntax #f
            `(module ,(string->symbol
                        (string-append "明道-"
                          (path->string src)))
               racket/base
               (require (lib "core.rkt" "mingdao"))
               ,@ast))))))