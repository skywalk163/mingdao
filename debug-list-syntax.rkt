#lang racket/base

(require racket/port racket/file racket/string racket/list)
(require "mingdao/lang/tokenizer.rkt" "mingdao/lang/parser.rkt")

;; 测试1: 检查 `定义创建Token就是函类型,值,行,列：
(printf "=== Test 1: Check function body syntax ===\n")
(define code1 "定义创建Token就是函类型,值,行,列：
  列表,\"token\",类型,值,行,列")
(define tokens1 (tokenize code1))
(define ast1 (parse tokens1))
(printf "Tokens: ~a\n" (map (λ (t) (list (token-type t) (token-value t))) tokens1)
(printf "\nAST: ~a\n" ast1)

;; 测试2: 检查更简单的函数定义
(printf "\n=== Test 2: Simple function with list ===\n")
(define code2 "定义f就是函a：
  列表,a")
(define tokens2 (tokenize code2))
(define ast2 (parse tokens2))
(printf "Tokens: ~a\n" (map (λ (t) (list (token-type t) (token-value t))) tokens2)
(printf "\nAST: ~a\n" ast2)

;; 测试3: 显式使用list函数
(printf "\n=== Test 3: Explicit list call ===\n")
(define code3 "定义f就是函a：
  列表(a)")
(define tokens3 (tokenize code3))
(define ast3 (parse tokens3))
(printf "Tokens: ~a\n" (map (λ (t) (list (token-type t) (token-value t))) tokens3)
(printf "\nAST: ~a\n" ast3)