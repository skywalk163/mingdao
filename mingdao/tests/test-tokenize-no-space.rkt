#lang racket
(require "../lang/tokenizer.rkt")

(define (show-tokens input)
  (printf "> 输入: ~a\n" input)
  (for ([t (tokenize input)])
    (printf "  ~a: ~a\n" (token-type t) (token-value t)))
  (newline))

(show-tokens "定义x就是42")
(show-tokens "定义x就是函f")
(show-tokens "加x乘y")
(show-tokens "当满足i小于10")
(show-tokens "定义宏双倍就是宏")
(displayln "Done!")