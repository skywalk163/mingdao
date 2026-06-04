#lang racket

;; 明道语言简化测试
;; 测试分词器和解析器

(require "../lang/tokenizer.rkt")

;; 测试1：变量定义
(define test1 "定义 x 就是 5")

(displayln "=== 测试1：变量定义 ===")
(displayln "输入:")
(displayln test1)
(displayln "\n分词结果:")
(define tokens1 (tokenize test1))
(for ([tok tokens1])
  (displayln tok))

;; 测试2：关键字识别
(define test2 "如果 分数 大于等于 90")

(displayln "\n=== 测试2：关键字识别 ===")
(displayln "输入:")
(displayln test2)
(displayln "\n分词结果:")
(define tokens2 (tokenize test2))
(for ([tok tokens2])
  (displayln tok))

;; 测试3：主谓宾语序
(define test3 "2, 3, 求和, 打印")

(displayln "\n=== 测试3：主谓宾语序 ===")
(displayln "输入:")
(displayln test3)
(displayln "\n分词结果:")
(define tokens3 (tokenize test3))
(for ([tok tokens3])
  (displayln tok))

(displayln "\n=== 所有测试完成 ===")
