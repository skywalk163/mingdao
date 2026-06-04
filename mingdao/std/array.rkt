#lang racket/base

(provide 数组/创建 数组/长度 数组/索引 数组/修改 数组/转列表 列表/转数组
         数组/追加 数组/拼接 数组/切片 数组/复制
         数组/填充 数组/映射 数组/过滤 数组/反转
         数组/排序 数组/迭代 数组/转字符串
         数组/类型 数组/字节 数组/整数 数组/浮点
         数组/创建/字节 数组/创建/整数 数组/创建/浮点)

(define (数组/创建 . items)
  (list->vector items))

(define (数组/长度 arr)
  (vector-length arr))

(define (数组/索引 arr idx)
  (vector-ref arr idx))

(define (数组/修改 arr idx val)
  (vector-set! arr idx val))

(define (数组/转列表 arr)
  (vector->list arr))

(define (列表/转数组 lst)
  (list->vector lst))

(define (数组/追加 arr1 arr2)
  (list->vector (append (vector->list arr1) (vector->list arr2))))

(define (数组/拼接 . arrays)
  (list->vector (apply append (map vector->list arrays))))

(define (数组/切片 arr start [end #f])
  (define len (vector-length arr))
  (define end-idx (or end len))
  (define size (- end-idx start))
  (define result (make-vector size))
  (for ([i (in-range size)])
    (vector-set! result i (vector-ref arr (+ start i))))
  result)

(define (数组/复制 arr)
  (define len (vector-length arr))
  (define result (make-vector len))
  (for ([i (in-range len)])
    (vector-set! result i (vector-ref arr i)))
  result)

(define (数组/填充 arr val)
  (define len (vector-length arr))
  (define result (make-vector len))
  (for ([i (in-range len)])
    (vector-set! result i val))
  result)

(define (数组/映射 f arr)
  (define len (vector-length arr))
  (define result (make-vector len))
  (for ([i (in-range len)])
    (vector-set! result i (f (vector-ref arr i))))
  result)

(define (数组/过滤 f arr)
  (list->vector (filter f (vector->list arr))))

(define (数组/反转 arr)
  (list->vector (reverse (vector->list arr))))

(define (数组/排序 arr [less? #f])
  (define cmp (or less? <))
  (list->vector (sort (vector->list arr) cmp)))

(define (数组/迭代 f arr)
  (for ([i (in-range (vector-length arr))])
    (f (vector-ref arr i))))

(define (数组/转字符串 arr)
  (format "~a" arr))

(define (数组/类型 arr)
  'vector)

(define (数组/字节 . items)
  (list->vector items))

(define (数组/整数 . items)
  (list->vector items))

(define (数组/浮点 . items)
  (list->vector items))

(define (数组/创建/字节 len [init 0])
  (make-vector len init))

(define (数组/创建/整数 len [init 0])
  (make-vector len init))

(define (数组/创建/浮点 len [init 0.0])
  (make-vector len init))