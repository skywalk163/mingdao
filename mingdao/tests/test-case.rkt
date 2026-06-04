#lang racket

(define escaped #\\)

(case escaped
  [(#\n) #\newline]
  [(#\t) #\tab]
  [(#\\) #\\]
  [(#\") #\"]
  [(#\') #\']
  [else escaped])
