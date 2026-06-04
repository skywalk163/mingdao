#lang racket

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

;; 简化的测试
(displayln "测试1: 打印x")
(pretty-print (parse (tokenize "打印x")))

(displayln "\n测试2: 打印 x")
(pretty-print (parse (tokenize "打印 x")))

(displayln "\n测试3: 如果x大于0那么：打印x")
(define tokens (tokenize "如果x大于0那么：打印x"))
(displayln "tokens:")
(for ([t tokens]) (displayln t))
(displayln "\n解析:")
(pretty-print (parse tokens))
