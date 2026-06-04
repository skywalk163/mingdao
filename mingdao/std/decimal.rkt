#lang racket/base

(provide 十进制/创建 十进制/加 十进制/减 十进制/乘 十进制/除
         十进制/四舍五入 十进制/转字符串 十进制/比较)

(define (找小数点 s)
  (let ([len (string-length s)])
    (let loop ([i 0])
      (cond [(>= i len) #f]
            [(char=? (string-ref s i) #\.) i]
            [else (loop (add1 i))]))))

(define (十进制/创建 s)
  (define dot-pos (找小数点 s))
  (if (not dot-pos)
      (string->number s)
      (let* ([sign (if (char=? (string-ref s 0) #\-) -1 1)]
             [int-end dot-pos]
             [frac-start (add1 dot-pos)]
             [int-str (substring s (if (= sign -1) 1 0) int-end)]
             [frac-str (substring s frac-start)]
             [int-part (string->number int-str)]
             [frac-len (string-length frac-str)]
             [frac-val (string->number frac-str)])
        (* sign (+ int-part (/ frac-val (expt 10 frac-len)))))))

(define 十进制/加 +)
(define 十进制/减 -)
(define 十进制/乘 *)
(define 十进制/除 /)

(define (十进制/四舍五入 d 位数)
  (define factor (expt 10 位数))
  (/ (round (* d factor)) factor))

(define (十进制/比较 a b)
  (cond [(< a b) -1]
        [(> a b)  1]
        [else      0]))

(define 数字符 "0123456789")

(define (十进制/转字符串 d)
  (define num (abs (numerator d)))
  (define den (denominator d))
  (define neg? (< d 0))
  (define int-part (quotient num den))
  (define rem (remainder num den))
  (define prefix (if neg? "-" ""))
  (if (zero? rem)
      (format "~a~a" prefix int-part)
      (let loop ([r rem] [digits '()])
        (if (or (zero? r) (> (length digits) 50))
            (let* ([digits-str (list->string (map (λ (d) (string-ref 数字符 d)) (reverse digits)))])
              (format "~a~a.~a" prefix int-part digits-str))
            (let* ([r*10 (* r 10)]
                   [digit (quotient r*10 den)]
                   [new-r (remainder r*10 den)])
              (loop new-r (cons digit digits)))))))