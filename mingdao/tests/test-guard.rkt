#lang racket/base

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

(define code "匹配 x :\n  [a, b] 如果 a 大于 b 那么: 打印, \"第一个更大\"\n  否则: 打印, \"其他\"")
(define tokens (tokenize code))
(printf "Tokens: ~s\n" tokens)
(define ast (parse tokens))
(printf "AST: ~s\n" ast)