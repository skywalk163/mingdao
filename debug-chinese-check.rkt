#lang racket/base

(require racket/port racket/file racket/string)
(require "mingdao/lang/tokenizer.rkt")

;; Test chinese-char?
(define test-chars
  (list #\为 #\分 #\支 #\索 #\引 #\t #\h #\e #\n))

(displayln "Testing chinese-char?:")
(for ([ch test-chars])
  (printf "  ~a: ~a\n" ch (chinese-char? ch)))

;; Test member
(displayln "\nTesting member for 为:")
(define chars '("从" "到" "为"))
(printf "  \"为\" in chars: ~a\n" (member "为" chars))