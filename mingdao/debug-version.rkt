#lang racket/base
(require (file "tools/pkg/version.rkt"))

(displayln "Testing version-compare:")
(displayln (version-compare (make-version 1 0 0) (make-version 1 0 0)))
(displayln (version-compare (make-version 1 0 0) (make-version 2 0 0)))

(displayln "\nTesting version<=?:")
(displayln (version<=? (make-version 1 0 0) (make-version 1 0 0)))
(displayln (version>=? (make-version 1 0 0) (make-version 1 0 0)))

(displayln "\nTesting parse-version:")
(displayln (parse-version "1.2.3"))
(displayln (parse-version "1.0.0-alpha"))

(displayln "\nTesting matches-constraint?:")
(displayln (matches-constraint? (make-version 1 0 0) (parse-constraint ">=1.0.0")))
(displayln (matches-constraint? (make-version 2 0 0) (parse-constraint ">=1.0.0")))

(displayln "\nDone")