#lang racket

(require "../lang/tokenizer.rkt")

;; 测试无空格场景
(displayln "测试1: x等于y")
(pretty-print (tokenize "x等于y"))

(displayln "\n测试2: 定义x就是5")
(pretty-print (tokenize "定义x就是5"))

(displayln "\n测试3: 如果x大于0")
(pretty-print (tokenize "如果x大于0"))

(displayln "\n测试4: 对于i从0到5")
(pretty-print (tokenize "对于i从0到5"))

(displayln "\n测试5: a加b")
(pretty-print (tokenize "a加b"))

(displayln "\n测试6: 分数大于等于90")
(pretty-print (tokenize "分数大于等于90"))

;; 测试可能存在的歧义场景
(displayln "\n=== 歧义测试 ===")

(displayln "\n测试7: 列表长度")  ;; 这是"列表 长度"还是"列表长度"?
(pretty-print (tokenize "列表长度"))

(displayln "\n测试8: 索引位置")  ;; 这是关键字吗?
(pretty-print (tokenize "索引位置"))

(displayln "\n测试9: 列表修改")  ;; 这是关键字吗?
(pretty-print (tokenize "列表修改"))

(displayln "\n测试10: 返回x")  ;; 返回和x会被分开吗?
(pretty-print (tokenize "返回x"))

(displayln "\n测试11: 跳出循环")  ;; 
(pretty-print (tokenize "跳出循环"))

(displayln "\n测试12: 定义定义x")  ;; 连续关键字
(pretty-print (tokenize "定义定义x"))

;; 测试解析
(displayln "\n=== 解析测试 ===")
(require "../lang/parser.rkt")

(displayln "\n测试13: x加y乘z")
(define code13 "x加y乘z")
(displayln (format "输入: ~a" code13))
(pretty-print (parse (tokenize code13)))

(displayln "\n测试14: a加b乘c")  ;; 注意运算优先级
(define code14 "a加b乘c")
(displayln (format "输入: ~a" code14))
(pretty-print (parse (tokenize code14)))
