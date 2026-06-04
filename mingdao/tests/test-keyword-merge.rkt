#lang racket

(require "../lang/tokenizer.rkt")

(displayln "测试: 打印x")
(pretty-print (tokenize "打印x"))

(displayln "\n测试: 打印 x")
(pretty-print (tokenize "打印 x"))

(displayln "\n测试: 索引数据")
(pretty-print (tokenize "索引数据"))

(displayln "\n测试: 长度列表")
(pretty-print (tokenize "长度列表"))

;; 问题：打印、索引、长度是关键字，应该被识别出来
