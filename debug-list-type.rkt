#lang racket/base

(require racket/port racket/file racket/string racket/list)
(require "mingdao/lang/tokenizer.rkt" "mingdao/lang/parser.rkt")

;; 测试: 检查单个中文字符"类型"
(printf "=== Test 1: Check 单个字符 ===\n")
(define tokens1 (tokenize "类型"))
(printf "Tokens for 类型: ~a\n" (map (lambda (t) (list (token-type t) (token-value t))) tokens1))

;; 测试: 检查表达式中的"类型"
(printf "\n=== Test 2: 列表,类型 ===\n")
(define tokens2 (tokenize "列表,类型"))
(printf "Tokens for 列表,类型: ~a\n" (map (lambda (t) (list (token-type t) (token-value t))) tokens2))
(define ast2 (parse tokens2))
(printf "AST: ~a\n" ast2)

;; 测试: 检查其他中文参数名
(printf "\n=== Test 3: 列表,值 ===\n")
(define tokens3 (tokenize "列表,值"))
(printf "Tokens for 列表,值: ~a\n" (map (lambda (t) (list (token-type t) (token-value t))) tokens3))
(define ast3 (parse tokens3))
(printf "AST: ~a\n" ast3)

;; 测试: 检查其他中文参数名
(printf "\n=== Test 4: 列表,a ===\n")
(define tokens4 (tokenize "列表,a"))
(printf "Tokens for 列表,a: ~a\n" (map (lambda (t) (list (token-type t) (token-value t))) tokens4))
(define ast4 (parse tokens4))
(printf "AST: ~a\n" ast4)