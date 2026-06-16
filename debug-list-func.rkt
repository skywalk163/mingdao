#lang racket/base

(require racket/port racket/file racket/string racket/list)
(require "mingdao/lang/tokenizer.rkt" "mingdao/lang/parser.rkt")

;; 测试不同的情况
(printf "=== Test 1: 类型 作为第一个参数 ===\n")
(define code1 "列表,类型,值,行,列")
(define tokens1 (tokenize code1))
(define ast1 (parse tokens1))
(printf "AST: ~a\n" ast1)

(printf "\n=== Test 2: 其他关键字作为第一个参数 ===\n")
(define code2 "列表,就是,a")
(define tokens2 (tokenize code2))
(define ast2 (parse tokens2))
(printf "AST: ~a\n" ast2)

(printf "\n=== Test 3: 打印 ===\n")
(define code3 "列表,打印,a")
(define tokens3 (tokenize code3))
(define ast3 (parse tokens3))
(printf "AST: ~a\n" ast3)

(printf "\n=== Test 4: 不是函数名关键字的普通标识符 ===\n")
(define code4 "列表,a,类型")
(define tokens4 (tokenize code4))
(define ast4 (parse tokens4))
(printf "AST: ~a\n" ast4)