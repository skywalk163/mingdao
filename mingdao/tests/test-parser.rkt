#lang racket

;; 明道语言解析器测试
;; 测试变量定义和基本表达式

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

;; 测试1：变量定义
(define test1 "定义 x 就是 5")

(displayln "=== 测试1：变量定义 ===")
(displayln "输入:")
(displayln test1)
(displayln "\n分词结果:")
(define tokens1 (tokenize test1))
(for ([tok tokens1]) (displayln tok))
(displayln "\n解析结果:")
(define ast1 (parse tokens1))
(pretty-print ast1)

;; 测试2：简单主谓宾语序
(define test2 "x, 打印")

(displayln "\n=== 测试2：主谓宾语序 ===")
(displayln "输入:")
(displayln test2)
(displayln "\n分词结果:")
(define tokens2 (tokenize test2))
(for ([tok tokens2]) (displayln tok))
(displayln "\n解析结果:")
(define ast2 (parse tokens2))
(pretty-print ast2)

(displayln "\n=== 所有测试完成 ===")
