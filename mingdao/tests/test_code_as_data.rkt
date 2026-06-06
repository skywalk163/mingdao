#lang racket

;; 代码即数据功能测试

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         racket/pretty)

(displayln "========================================")
(displayln "明道语言代码即数据功能测试")
(displayln "========================================")

;; 测试1：基本引用
(displayln "\n【测试1】基本引用")
(define test1 "引用 (2 加 3)")
(displayln (format "输入: ~a" test1))
(define tokens1 (tokenize test1))
(displayln (format "分词结果: ~a" tokens1))
(define ast1 (parse tokens1))
(displayln "解析结果:")
(pretty-print ast1)

;; 测试2：执行
(displayln "\n【测试2】执行")
(define test2 "执行 (2 加 3)")
(displayln (format "输入: ~a" test2))
(define tokens2 (tokenize test2))
(displayln (format "分词结果: ~a" tokens2))
(define ast2 (parse tokens2))
(displayln "解析结果:")
(pretty-print ast2)

;; 测试3：引用块语法
(displayln "\n【测试3】引用块语法")
(define test3 "引用:
    定义 x 就是 10
    打印 x")
(displayln "输入:")
(displayln test3)
(define tokens3 (tokenize test3))
(displayln (format "分词结果: ~a" tokens3))
(define ast3 (parse tokens3))
(displayln "解析结果:")
(pretty-print ast3)

(displayln "\n========================================")
(displayln "测试完成！")
(displayln "========================================")
