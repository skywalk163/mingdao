#lang racket/base

(require racket/port racket/file racket/string racket/list)
(require "mingdao/lang/tokenizer.rkt" "mingdao/lang/parser.rkt")

;; 测试 tokenizer
(printf "=== Test: 类型 tokenization ===\n")
(define code "定义创建Token就是函类型,值,行,列：
  列表,\"token\",类型,值,行,列")

(define tokens (tokenize code))
(printf "Tokens: \n")
(for ([tok tokens])
  (printf "  ~a: ~a\n" (token-type tok) (token-value tok)))

(printf "\nAST: ~a\n" (parse tokens))