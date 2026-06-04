#lang racket/base
(require "lang/tokenizer.rkt")
(define tokens (tokenize "定义 人 类:
  属性 姓名: \"张三\"
  属性 年龄: 25
定义 p 就是 新建, 人
p"))
(printf "Tokens:\n")
(for ([tok tokens])
  (printf "  ~s\n" tok))