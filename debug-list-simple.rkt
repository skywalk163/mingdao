#lang racket/base

(require racket/port racket/file racket/string racket/list)
(require "mingdao/lang/tokenizer.rkt" "mingdao/lang/parser.rkt")

;; 测试
(printf "=== Test: Function body syntax ===\n")
(define code "定义f就是函a：
  列表,a")

(define tokens (tokenize code))
(define ast (parse tokens))
(printf "Tokens: ~a\n" (map (lambda (t) (list (token-type t) (token-value t))) tokens))
(printf "\nAST: ~a\n" ast)