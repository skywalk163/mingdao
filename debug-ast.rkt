#lang racket/base

(require racket/port racket/file racket/string racket/list)
(require "mingdao/lang/tokenizer.rkt" "mingdao/lang/parser.rkt")

;; 检查 parser 生成的 AST
(define code "打印,\"hello\"")
(printf "Code: ~a\n" code)

(define tokens (tokenize code))
(printf "Tokens: ~a\n" (map (λ (t) (list (token-type t) (token-value t))) tokens))

(define ast (parse tokens))
(printf "AST: ~a\n" ast)