#lang racket/base
(require "mingdao/lang/tokenizer.rkt"
         "mingdao/lang/parser.rkt"
         "mingdao/lang/semantic.rkt"
         "mingdao/lang/module.rkt")

(printf "=== 快速功能测试 ===\n")

;; 测试1：简单代码解析 + 语义分析
(define code1 "定义 x 就是 42\n打印, x")
(define tokens1 (tokenize code1))
(define ast1 (parse tokens1))
(printf "测试1 AST: ~a\n" ast1)
(define errors1 (analyze ast1 builtin-names))
(printf "测试1 语义错误: ~a\n" (map semantic-error-type errors1))

;; 测试2：带函数定义
(define code2 "定义 翻倍 就是函 x：\n    返回 x 乘 2\n打印, (翻倍, 5)")
(define tokens2 (tokenize code2))
(define ast2 (parse tokens2))
(printf "测试2 AST: ~a\n" ast2)
(define errors2 (analyze ast2 builtin-names))
(printf "测试2 语义错误: ~a\n" (map semantic-error-type errors2))

;; 测试3：导入语句解析
(define code3 "导入 \"utils.mingdao\"\n导出 交换")
(define tokens3 (tokenize code3))
(define ast3 (parse tokens3))
(printf "测试3 AST: ~a\n" ast3)

(printf "\n=== 测试完成 ===\n")
