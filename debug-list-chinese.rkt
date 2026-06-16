#lang racket/base

(require racket/port racket/file racket/string racket/list)
(require "mingdao/lang/tokenizer.rkt" "mingdao/lang/parser.rkt")

;; 测试: 使用中文参数名
(printf "=== Test: Chinese variable names ===\n")
(define code "定义f就是函类型,值,行,列：
  列表,类型,值,行,列")

(define tokens (tokenize code))
(define ast (parse tokens))
(printf "Tokens: ~a\n" (map (lambda (t) (list (token-type t) (token-value t))) tokens))
(printf "\nAST: ~a\n" ast)