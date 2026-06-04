#lang racket

(require "../lang/tokenizer.rkt")

(displayln "测试分词: 定义 玩家生命 就是 3")
(pretty-print (tokenize "定义 玩家生命 就是 3"))

(displayln "\n测试分词: 玩家生命")
(pretty-print (tokenize "玩家生命"))

(displayln "\n测试分词: 定义武器等级就是1")
(pretty-print (tokenize "定义武器等级就是1"))
