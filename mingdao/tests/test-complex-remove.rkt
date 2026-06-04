#lang racket

(require "../lang/tokenizer.rkt")

(displayln "=== 测试复合标识符机制移除 ===")

;; 之前：列表修改会被识别为单个标识符
;; 现在：应该被拆分为"列表"和"修改"

(displayln "\n测试1: 列表修改")
(pretty-print (tokenize "列表修改"))

(displayln "\n测试2: 列表 修改")  
(pretty-print (tokenize "列表 修改"))

(displayln "\n测试3: 索引位置")
(pretty-print (tokenize "索引位置"))

(displayln "\n测试4: 消息拼接")
(pretty-print (tokenize "消息拼接"))

(displayln "\n测试5: 定义列表修改就是函x：返回x")
(pretty-print (tokenize "定义列表修改就是函x：返回x"))

;; 建议用户使用下划线
(displayln "\n=== 建议的写法（使用下划线）===")
(displayln "\n建议1: 列表_修改")
(pretty-print (tokenize "列表_修改"))

(displayln "\n建议2: 索引_位置")
(pretty-print (tokenize "索引_位置"))

(displayln "\n建议3: 消息_拼接")
(pretty-print (tokenize "消息_拼接"))
