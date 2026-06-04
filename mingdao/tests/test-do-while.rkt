#lang racket/base

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

(define (make-mingdao-namespace)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (define core-path
      (path->string (build-path (current-directory) ".." "core.rkt")))
    (eval `(require (file ,core-path)))
    (void))
  ns)

(define ns (make-mingdao-namespace))

(define (mingdao-eval expr)
  (parameterize ([current-namespace ns])
    (eval expr)))

(define code "做当满足 真值 : 打印, \"hello\"")
(define tokens (tokenize code))
(printf "Tokens: ~s\n" tokens)
(define ast (parse tokens))
(printf "AST: ~s\n" ast)