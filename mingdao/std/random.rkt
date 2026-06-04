#lang racket/base
(require racket/random racket/list)

(provide 随机整数范围 随机浮点数 随机种子 随机选择 随机打乱 随机样本 随机布尔)

(define (随机整数范围 [最小值 0] [最大值 100])
  (define min-val (if (integer? 最小值) 最小值 0))
  (define max-val (if (integer? 最大值) 最大值 100))
  (when (> min-val max-val)
    (error "最小值不能大于最大值"))
  (+ min-val (random (- max-val min-val -1))))

(define (随机浮点数 [最小值 0.0] [最大值 1.0])
  (+ 最小值 (* (random) (- 最大值 最小值))))

(define (随机种子 seed)
  (random-seed seed))

(define (随机选择 lst)
  (when (null? lst)
    (error "列表不能为空"))
  (list-ref lst (random (length lst))))

(define (随机打乱 lst)
  (define result (append lst '()))
  (define n (length result))
  (for ([i (in-range n)])
    (define j (+ i (random (- n i))))
    (define tmp (list-ref result i))
    (set! result (list-set result i (list-ref result j)))
    (set! result (list-set result j tmp)))
  result)

(define (随机样本 lst k)
  (when (> k (length lst))
    (error "样本数量不能大于列表长度"))
  (take (随机打乱 lst) k))

(define (随机布尔)
  (= (random 2) 0))