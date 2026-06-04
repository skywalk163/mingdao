#lang racket/base
(require racket/math)

(provide 正弦 余弦 正切 反正弦 反余弦 反正切
         自然对数 常用对数 指数
         角度转弧度 弧度转角度
         圆周率 自然常数
         阶乘 组合数 排列数
         最大公约数 最小公倍数
         取符号 取小数部分 取整数部分
         度转弧度 弧度转度)

(define 正弦 sin)
(define 余弦 cos)
(define 正切 tan)
(define 反正弦 asin)
(define 反余弦 acos)
(define 反正切 atan)

(define (自然对数 x)
  (log x))

(define (常用对数 x)
  (/ (log x) (log 10)))

(define 指数 exp)

(define (角度转弧度 deg)
  (* deg (/ pi 180.0)))

(define (弧度转角度 rad)
  (* rad (/ 180.0 pi)))

(define 圆周率 pi)

(define 自然常数 (exp 1))

(define (阶乘 n)
  (if (< n 2)
      1
      (* n (阶乘 (sub1 n)))))

(define (组合数 n k)
  (cond
    [(> k n) 0]
    [(= k 0) 1]
    [(= k n) 1]
    [else (/ (阶乘 n) (* (阶乘 k) (阶乘 (- n k))))]))

(define (排列数 n k)
  (cond
    [(< n k) 0]
    [else (/ (阶乘 n) (阶乘 (- n k)))]))

(define 最大公约数 gcd)

(define 最小公倍数 lcm)

(define (取符号 x)
  (cond [(> x 0) 1] [(< x 0) -1] [else 0]))

(define (取小数部分 x)
  (- x (truncate x)))

(define (取整数部分 x)
  (truncate x))

(define 度转弧度 角度转弧度)
(define 弧度转度 弧度转角度)