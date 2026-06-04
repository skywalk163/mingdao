#lang racket/base

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         racket/port
         racket/string)

(define (make-mingdao-namespace)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (define core-path
      (path->string (build-path (current-directory) ".." "core.rkt")))
    (printf "Loading core from: ~a\n" core-path)
    (eval `(require (file ,core-path)))
    (void))
  ns)

(define ns (make-mingdao-namespace))

(define (mingdao-eval expr)
  (printf "Evaluating: ~s\n" expr)
  (parameterize ([current-namespace ns])
    (define result (eval expr))
    (printf "Result: ~s\n" result)
    result))

(define code "定义 人 类:
  属性 姓名: \"张三\"
  属性 年龄: 25")

(define tokens (tokenize code))
(define ast (parse tokens))

(printf "=== Tokens ===\n")
(for ([tok tokens])
  (printf "  ~s\n" tok))

(printf "\n=== AST ===\n")
(for ([expr ast])
  (printf "  ~s\n" expr))

(printf "\n=== Evaluating ===\n")
(for ([expr ast])
  (mingdao-eval expr))

(printf "\n=== Testing 新建 ===\n")
(mingdao-eval '(新建 '人))