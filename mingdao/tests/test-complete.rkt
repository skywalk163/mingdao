#lang racket

;; 明道语言完整测试
;; 验证所有核心功能

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

(displayln "========================================")
(displayln "明道语言核心功能测试")
(displayln "========================================")

;; 测试1：变量定义和打印
(displayln "\n【测试1】变量定义和主谓宾语序")
(define test1 "定义 x 就是 5
x, 打印")

(displayln "输入:")
(displayln test1)
(displayln "\n分词结果:")
(define tokens1 (tokenize test1))
(for ([tok tokens1]) (displayln tok))
(displayln "\n解析结果:")
(define ast1 (parse tokens1))
(pretty-print ast1)

;; 测试2：函数定义和调用
(displayln "\n========================================")
(displayln "【测试2】函数定义和管道式调用")
(define test2 "定义 求和 就是函 a, b：
    返回 a 加 b
2, 3, 求和, 打印")

(displayln "输入:")
(displayln test2)
(displayln "\n分词结果:")
(define tokens2 (tokenize test2))
(for ([tok tokens2]) (displayln tok))
(displayln "\n解析结果:")
(define ast2 (parse tokens2))
(pretty-print ast2)

;; 测试3：条件判断
(displayln "\n========================================")
(displayln "【测试3】条件判断")
(define test3 "定义 分数 就是 85
如果 分数 大于等于 90 那么：
    \"优秀\", 打印
否则若 分数 大于等于 60 那么：
    \"及格\", 打印
否则：
    \"不及格\", 打印")

(displayln "输入:")
(displayln test3)
(displayln "\n分词结果:")
(define tokens3 (tokenize test3))
(for ([tok tokens3]) (displayln tok))
(displayln "\n解析结果:")
(define ast3 (parse tokens3))
(pretty-print ast3)

;; 测试4：列表操作
(displayln "\n========================================")
(displayln "【测试4】列表定义和操作")
(define test4 "定义 数据 就是 列表 1, 3, 5, 7
定义 第一个 就是 数据 索引 0
第一个, 打印")

(displayln "输入:")
(displayln test4)
(displayln "\n分词结果:")
(define tokens4 (tokenize test4))
(for ([tok tokens4]) (displayln tok))
(displayln "\n解析结果:")
(define ast4 (parse tokens4))
(pretty-print ast4)

;; 测试5：循环
(displayln "\n========================================")
(displayln "【测试5】循环结构")
(define test5 "对于 i 从 0 到 5：
    i, 打印")

(displayln "输入:")
(displayln test5)
(displayln "\n分词结果:")
(define tokens5 (tokenize test5))
(for ([tok tokens5]) (displayln tok))
(displayln "\n解析结果:")
(define ast5 (parse tokens5))
(pretty-print ast5)

(displayln "\n========================================")
(displayln "所有测试完成！")
(displayln "========================================")
