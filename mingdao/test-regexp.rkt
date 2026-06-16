#lang racket/base
(require racket/string)
(define re #rx"^([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:-([a-zA-Z0-9.-]+))?(?:\\+([a-zA-Z0-9.-]+))?$")
(define m (regexp-match re "1.2.3"))
(displayln m)
(define re2 #rx"^([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
(define m2 (regexp-match re2 "1.2.3"))
(displayln m2)