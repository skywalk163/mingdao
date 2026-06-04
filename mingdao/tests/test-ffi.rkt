#lang racket/base

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

;; 测试带参数的外部函数声明（参数之间用逗号分隔）
(define code "外部函数 printf \"msvcrt.dll\" _int (_string, _int)")
(define tokens (tokenize code))
(printf "Tokens: ~s\n" tokens)

(define ast (parse tokens))
(printf "AST: ~s\n" ast)