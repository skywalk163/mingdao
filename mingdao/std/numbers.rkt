#lang racket/base

(require racket/math racket/format)

(provide
 数字/是整数 数字/是浮点 数字/是有理数 数字/是实数 数字/是复数
 数字/是数字 数字/整数转罗马 数字/罗马转整数 数字/进制转换
 数字/数字转中文 数字/约等于 数字/限制范围 数字/标准化角度
 数字/等比缩放 数字/百分比)

(define (数字/是整数 x) (integer? x))
(define (数字/是浮点 x) (flonum? x))
(define (数字/是有理数 x) (rational? x))
(define (数字/是实数 x) (real? x))
(define (数字/是复数 x) (complex? x))
(define (数字/是数字 x) (number? x))

(define (数字/整数转罗马 n)
  (define values '(1000 900 500 400 100 90 50 40 10 9 5 4 1))
  (define numerals '("M" "CM" "D" "CD" "C" "XC" "L" "XL" "X" "IX" "V" "IV" "I"))
  (let loop ((num n) (idx 0) (result ""))
    (if (>= idx (length values))
      result
      (let ((v (list-ref values idx))
            (r (list-ref numerals idx)))
        (if (>= num v)
          (loop (- num v) idx (string-append result r))
          (loop num (+ idx 1) result))))))

(define (数字/罗马转整数 s)
  (define roman-map (hash #\I 1 #\V 5 #\X 10 #\L 50 #\C 100 #\D 500 #\M 1000))
  (define chars (string->list s))
  (let loop ((cs chars) (prev 0) (total 0))
    (if (null? cs)
      total
      (let ((cur (hash-ref roman-map (car cs) 0)))
        (if (> cur prev)
          (loop (cdr cs) cur (- total prev (- cur prev)))
          (loop (cdr cs) cur (+ total cur)))))))

(define (数字/进制转换 n from-base to-base)
  (define decimal (string->number (number->string n) from-base))
  (if decimal
    (let ((digits "0123456789ABCDEF"))
      (let loop ((num decimal) (result ""))
        (if (< num to-base)
          (string (string-ref digits num))
          (string-append (loop (quotient num to-base) result)
                         (string (string-ref digits (remainder num to-base)))))))
    "0"))

(define (数字/数字转中文 n)
  (define cn-digits '("零" "一" "二" "三" "四" "五" "六" "七" "八" "九"))
  (define cn-units '("" "十" "百" "千" "万" "十" "百" "千" "亿"))
  (let* ((num-str (number->string n))
         (len (string-length num-str)))
    (let loop ((i 0) (result ""))
      (if (>= i len)
        (if (string=? result "") "零" result)
        (let ((digit (string->number (substring num-str i (+ i 1)))))
          (loop (+ i 1)
                (string-append result
                               (list-ref cn-digits digit)
                               (list-ref cn-units (- len i 1)))))))))

(define (数字/约等于 a b #:tolerance [tol 1e-10])
  (< (abs (- a b)) tol))

(define (数字/限制范围 x min max)
  (max min (min max x)))

(define (数字/标准化角度 angle #:unit [unit 'degree])
  (define full (if (eq? unit 'radian) (* 2 pi) 360))
  (define norm (modulo angle full))
  (if (negative? norm) (+ norm full) norm))

(define (数字/等比缩放 value from-min from-max to-min to-max)
  (let ((ratio (/ (- value from-min) (- from-max from-min))))
    (+ to-min (* ratio (- to-max to-min)))))

(define (数字/百分比 value #:total [total 100] #:decimal-places [places 2])
  (let ((pct (* (/ value total) 100)))
    (string-append (~r pct #:precision places) "%")))