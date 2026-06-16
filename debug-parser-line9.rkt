#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

(define src (file->string "mingdao/std/parser.mingdao"))
(define lines (string-split src "\n"))
(define target-line (list-ref lines 8))

(displayln "===========================================")
(displayln "Line 9:")
(displayln target-line)
(displayln "===========================================")
(displayln "Tokens:")

(define tokens (tokenize target-line))
(for ([tok tokens])
  (printf "  ~a: ~a (line ~a, col ~a)\n"
          (token-type tok)
          (token-value tok)
          (token-line tok)
          (token-col tok)))