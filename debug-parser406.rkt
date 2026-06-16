#lang racket/base

(require racket/port racket/file racket/string)

(define src (file->string "mingdao/std/parser.mingdao"))
(define lines (string-split src "\n"))
(define target-line (list-ref lines 405))

(displayln "===========================================")
(displayln "Line 406:")
(displayln target-line)
(displayln "===========================================")