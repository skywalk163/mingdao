#lang racket/base
(require racket/format)

(provide 分数/创建 分数/分子 分数/分母 分数/简化
         分数/加 分数/减 分数/乘 分数/除
         分数/比较 分数/转浮点数 分数/转字符串)

(define (分数/创建 n d)
  (/ n d))

(define 分数/分子 numerator)

(define 分数/分母 denominator)

(define (分数/简化 f)
  (/ (numerator f) (denominator f)))

(define 分数/加 +)
(define 分数/减 -)
(define 分数/乘 *)
(define 分数/除 /)

(define (分数/比较 a b)
  (cond [(< a b) -1]
        [(> a b)  1]
        [else      0]))

(define 分数/转浮点数 exact->inexact)

(define (分数/转字符串 f)
  (~a f))