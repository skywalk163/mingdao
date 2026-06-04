#lang racket

;; 明道语言宏系统测试
;; 测试宏定义解析和展开

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

(displayln "========================================")
(displayln "明道语言宏系统测试")
(displayln "========================================")

;; 测试1：基本宏定义（双倍）
(displayln "\n【测试1】基本宏定义 - 双倍")
(define test1 "定义宏 双倍 就是宏：
    生成 (双倍 x)
    捕获 (x 乘 2)")

(displayln "输入:")
(displayln test1)
(displayln "\n分词结果:")
(define tokens1 (tokenize test1))
(for ([tok tokens1]) (displayln tok))
(displayln "\n解析结果:")
(define ast1 (parse tokens1))
(pretty-print ast1)

;; 测试2：带任意参数的宏（求和）
(displayln "\n========================================")
(displayln "【测试2】带任意参数的宏")
(define test2 "定义宏 求和 就是宏：
    生成 (求和 任意)
    捕获 (求和-helper 任意)")

(displayln "输入:")
(displayln test2)
(displayln "\n分词结果:")
(define tokens2 (tokenize test2))
(for ([tok tokens2]) (displayln tok))
(displayln "\n解析结果:")
(define ast2 (parse tokens2))
(pretty-print ast2)

;; 测试3：多模式宏（交换）
(displayln "\n========================================")
(displayln "【测试3】多模式宏")
(define test3 "定义宏 交换 就是宏：
    生成 (交换 a b)
    捕获 (b a)
    生成 (交换 x 任意)
    捕获 (任意 x)")

(displayln "输入:")
(displayln test3)
(displayln "\n分词结果:")
(define tokens3 (tokenize test3))
(for ([tok tokens3]) (displayln tok))
(displayln "\n解析结果:")
(define ast3 (parse tokens3))
(pretty-print ast3)

;; 测试4：宏定义中的嵌套模式
(displayln "\n========================================")
(displayln "【测试4】嵌套模式宏")
(define test4 "定义宏 变换 就是宏：
    生成 (变换 (操作 x))
    捕获 (操作 x)")

(displayln "输入:")
(displayln test4)
(displayln "\n分词结果:")
(define tokens4 (tokenize test4))
(for ([tok tokens4]) (displayln tok))
(displayln "\n解析结果:")
(define ast4 (parse tokens4))
(pretty-print ast4)

(displayln "\n========================================")
(displayln "宏解析测试完成！")
(displayln "========================================")