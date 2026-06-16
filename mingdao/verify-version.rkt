#lang racket/base
(require (file "tools/pkg/version.rkt"))
(displayln (parse-version "1.2.3"))
(displayln (version->string (version 1 2 3 #f #f)))
(displayln (version-compare (version 1 0 0 #f #f) (version 2 0 0 #f #f)))
(displayln (matches-constraint? (version 1 9 9 #f #f) (parse-constraint "^1.0.0")))
(displayln "OK")