#lang racket

(require "../lang/tokenizer.rkt")

;; 测试复合标识符的问题
(displayln "=== 复合标识符测试 ===")

(displayln "\n测试1: 索引位置")
(pretty-print (tokenize "索引位置"))

(displayln "\n测试2: 列表修改")
(pretty-print (tokenize "列表修改"))

(displayln "\n测试3: 消息拼接")
(pretty-print (tokenize "消息拼接"))

;; 问题：这些被当作单个标识符，而不是两个关键字
;; 建议：移除复合标识符机制，让用户用下划线或空格分隔

;; 测试解决方案
(displayln "\n=== 建议的写法 ===")

(displayln "\n建议1: 使用下划线")
(pretty-print (tokenize "索引_位置"))

(displayln "\n建议2: 空格分隔")
(pretty-print (tokenize "索引 位置"))

;; 实际使用场景
(displayln "\n=== 实际使用场景 ===")

(displayln "\n场景1: 索引位置 作为变量名")
(pretty-print (tokenize "定义 索引位置 就是 0"))

(displayln "\n场景2: 索引 位置 作为两个关键字")
(pretty-print (tokenize "索引 数据 位置"))
