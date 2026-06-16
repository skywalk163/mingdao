#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

;; Test problematic lines around line 46
(define src (file->string "mingdao/std/tokenizer.mingdao"))
(define lines (string-split src "\n"))

(displayln "Testing lines 40-50:")
(for ([i (in-range 40 50)])
  (define line (list-ref lines i))
  (displayln "===========================================")
  (printf "~a: ~a\n" (+ i 1) line)
  (displayln "Tokens:")
  (define tokens (tokenize line))
  (for ([tok tokens])
    (printf "  ~a: ~a (col ~a)\n"
            (token-type tok)
            (token-value tok)
            (token-col tok))))