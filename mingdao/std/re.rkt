#lang racket/base

(provide 正则搜索 正则匹配 正则替换 正则全部替换
         正则分割 正则匹配所有 正则转义 正则编译
         正则匹配位置)

(define (→正则 模式)
  (if (string? 模式) (pregexp 模式) 模式))

(define (正则搜索 模式 字符串)
  (define result (regexp-match (→正则 模式) 字符串))
  (if result result '()))

(define (正则匹配 模式 字符串)
  (regexp-match? (→正则 模式) 字符串))

(define (正则替换 模式 字符串 替换串)
  (regexp-replace (→正则 模式) 字符串 替换串))

(define (正则全部替换 模式 字符串 替换串)
  (regexp-replace* (→正则 模式) 字符串 替换串))

(define (正则分割 模式 字符串)
  (regexp-split (→正则 模式) 字符串))

(define (正则匹配所有 模式 字符串)
  (regexp-match* (→正则 模式) 字符串))

(define (正则转义 字符串)
  (regexp-quote 字符串))

(define (正则编译 模式)
  (pregexp 模式))

(define (正则匹配位置 模式 字符串)
  (regexp-match-positions (→正则 模式) 字符串))