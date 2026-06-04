#lang racket/base
(require racket/math)

(provide 平均值 中位数 中位数低 中位数高
         众数 众数列表
         标准差总体 方差总体 标准差样本 方差样本
         分位数 协方差 相关系数 线性回归)

(define (平均值 lst)
  (when (null? lst)
    (error '平均值 "列表不能为空"))
  (/ (apply + lst) (length lst)))

(define (中位数 lst)
  (when (null? lst)
    (error '中位数 "列表不能为空"))
  (define s (sort lst <))
  (define n (length s))
  (if (odd? n)
      (list-ref s (quotient n 2))
      (/ (+ (list-ref s (sub1 (quotient n 2)))
            (list-ref s (quotient n 2)))
         2)))

(define (中位数低 lst)
  (when (null? lst)
    (error '中位数低 "列表不能为空"))
  (define s (sort lst <))
  (define n (length s))
  (list-ref s (quotient (sub1 n) 2)))

(define (中位数高 lst)
  (when (null? lst)
    (error '中位数高 "列表不能为空"))
  (define s (sort lst <))
  (define n (length s))
  (list-ref s (quotient n 2)))

(define (众数 lst)
  (when (null? lst)
    (error '众数 "列表不能为空"))
  (define freq (make-hasheq))
  (for ([x (in-list lst)])
    (hash-set! freq x (add1 (hash-ref freq x 0))))
  (define max-count (apply max (hash-values freq)))
  (define candidates (for/list ([(k v) (in-hash freq)] #:when (= v max-count)) k))
  (car candidates))

(define (众数列表 lst)
  (when (null? lst)
    (error '众数列表 "列表不能为空"))
  (define freq (make-hasheq))
  (for ([x (in-list lst)])
    (hash-set! freq x (add1 (hash-ref freq x 0))))
  (define max-count (apply max (hash-values freq)))
  (for/list ([(k v) (in-hash freq)] #:when (= v max-count)) k))

(define (方差总体 lst)
  (when (null? lst)
    (error '方差总体 "列表不能为空"))
  (define m (平均值 lst))
  (/ (apply + (map (λ (x) (sqr (- x m))) lst))
     (length lst)))

(define (标准差总体 lst)
  (sqrt (方差总体 lst)))

(define (方差样本 lst)
  (define n (length lst))
  (cond
    [(< n 2) (error '方差样本 "样本数量不足，需要至少2个数据点")]
    [else
     (let ([m (平均值 lst)])
       (/ (apply + (map (λ (x) (sqr (- x m))) lst))
          (sub1 n)))]))

(define (标准差样本 lst)
  (sqrt (方差样本 lst)))

(define (分位数 lst [n 4])
  (when (< (length lst) 2)
    (error '分位数 "数据点不足"))
  (define s (sort lst <))
  (define len (length s))
  (for/list ([i (in-range 1 n)])
    (define p (/ i n))
    (define pos (* p (sub1 len)))
    (define idx-floor (floor pos))
    (define frac (- pos idx-floor))
    (define idx (exact-floor idx-floor))
    (if (= frac 0)
        (list-ref s idx)
        (+ (* (list-ref s idx) (- 1 frac))
           (* (list-ref s (add1 idx)) frac)))))

(define (协方差 x y)
  (define n (length x))
  (cond
    [(not (= n (length y))) (error '协方差 "两个列表长度不一致")]
    [(< n 2) (error '协方差 "样本数量不足，需要至少2个数据点")]
    [else
     (let ([mx (平均值 x)]
           [my (平均值 y)])
       (/ (apply + (map (λ (xi yi) (* (- xi mx) (- yi my))) x y))
          (sub1 n)))]))

(define (相关系数 x y)
  (define n (length x))
  (cond
    [(not (= n (length y))) (error '相关系数 "两个列表长度不一致")]
    [else
     (let ([cov (协方差 x y)]
           [sx (标准差样本 x)]
           [sy (标准差样本 y)])
       (if (or (= sx 0) (= sy 0))
           (error '相关系数 "标准差为零，无法计算相关系数")
           (/ cov (* sx sy))))]))

(define (线性回归 x y)
  (define n (length x))
  (cond
    [(not (= n (length y))) (error '线性回归 "两个列表长度不一致")]
    [(< n 2) (error '线性回归 "样本数量不足")]
    [else
     (let* ([mx (平均值 x)]
            [my (平均值 y)]
            [cov (协方差 x y)]
            [vx (方差样本 x)]
            [slope (if (= vx 0)
                      (error '线性回归 "x的方差为零，无法计算斜率")
                      (/ cov vx))]
            [intercept (- my (* slope mx))])
       (values slope intercept))]))