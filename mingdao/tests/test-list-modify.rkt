#lang racket

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

;; 测试列表修改
(displayln "测试: 列表修改 数据 0 5")
(pretty-print (tokenize "列表修改 数据 0 5"))
(displayln "\n解析结果:")
(pretty-print (parse (tokenize "列表修改 数据 0 5")))

;; 测试消息拼接
(displayln "\n\n测试: 消息拼接 \"Hello\" \"World\"")
(pretty-print (tokenize "消息拼接 \"Hello\" \"World\""))
