#lang racket/base
(require racket/match)
(define e (with-handlers ([exn:fail? values]) (error "test")))
(printf "exn:fail:user? = ~a\n" (exn:fail:user? e))
(printf "exn:fail? = ~a\n" (exn:fail? e))