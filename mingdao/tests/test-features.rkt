#lang racket

;; 明道语言完整测试（谓宾语序版）
;; 验证核心功能

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

(displayln "========================================")
(displayln "明道语言核心功能测试")
(displayln "谓宾语序 + 管道式调用")
(displayln "========================================")

;; 测试1：变量定义和函数调用
(displayln "\n【测试1】变量定义和函数调用")
(define test1 "定义 x 就是 5
打印 x")

(displayln "输入:")
(displayln test1)
(displayln "\n解析结果:")
(pretty-print (parse (tokenize test1)))

;; 测试2：函数定义
(displayln "\n========================================")
(displayln "【测试2】函数定义")
(define test2 "定义 求和 就是函 a, b：
    返回 a 加 b")

(displayln "输入:")
(displayln test2)
(displayln "\n解析结果:")
(pretty-print (parse (tokenize test2)))

;; 测试3：条件判断
(displayln "\n========================================")
(displayln "【测试3】条件判断")
(define test3 "定义 分数 就是 85
如果 分数 大于等于 90 那么：
    打印 \"优秀\"
否则：
    打印 \"良好\"")

(displayln "输入:")
(displayln test3)
(displayln "\n解析结果:")
(pretty-print (parse (tokenize test3)))

;; 测试4：循环
(displayln "\n========================================")
(displayln "【测试4】循环结构")
(define test4 "对于 i 从 0 到 5：
    打印 i")

(displayln "输入:")
(displayln test4)
(displayln "\n解析结果:")
(pretty-print (parse (tokenize test4)))

;; 测试5：列表定义
(displayln "\n========================================")
(displayln "【测试5】列表定义")
(define test5 "定义 数据 就是 列表 1, 3, 5, 7")

(displayln "输入:")
(displayln test5)
(displayln "\n解析结果:")
(pretty-print (parse (tokenize test5)))

;; 测试6：管道式调用
(displayln "\n========================================")
(displayln "【测试6】管道式调用")
(define test6 "列表 1, 2, 3, 4, 5 然后 长度 然后 打印")

(displayln "输入:")
(displayln test6)
(displayln "\n解析结果:")
(pretty-print (parse (tokenize test6)))

;; 测试7：带参数的管道
(displayln "\n========================================")
(displayln "【测试7】带参数的管道")
(define test7 "定义 数据 就是 列表 10, 20, 30
数据 | 长度 | 打印
数据 | 索引 1 | 打印")

(displayln "输入:")
(displayln test7)
(displayln "\n解析结果:")
(pretty-print (parse (tokenize test7)))

(displayln "\n========================================")
(displayln "所有测试完成！")
(displayln "========================================")
