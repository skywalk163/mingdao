#lang racket/base

(require racket/list racket/string)

(provide
 日历/月 日历/年 日历/月天数 日历/月日历
 日历/星期 日历/星期几 日历/闰年
 日历/星期名 日历/缩写星期名 日历/月名 日历/缩写月名
 日历/当月 日历/当月天数 日历/月起始星期
 日历/周天数 日历/月范围 日历/年范围
 日历/天数总计 日历/一年中的天数)

(define WEEKDAY-NAMES '("星期一" "星期二" "星期三" "星期四" "星期五" "星期六" "星期日"))
(define WEEKDAY-ABBR '("周一" "周二" "周三" "周四" "周五" "周六" "周日"))
(define MONTH-NAMES '("一月" "二月" "三月" "四月" "五月" "六月" "七月" "八月" "九月" "十月" "十一月" "十二月"))
(define MONTH-ABBR '("1月" "2月" "3月" "4月" "5月" "6月" "7月" "8月" "9月" "10月" "11月" "12月"))

(define (日历/闰年 year)
  (and (zero? (modulo year 4))
       (or (not (zero? (modulo year 100)))
           (zero? (modulo year 400)))))

(define (日历/月天数 year month)
  (define days-in-month #(31 28 31 30 31 30 31 31 30 31 30 31))
  (if (and (= month 2) (日历/闰年 year))
    29
    (vector-ref days-in-month (- month 1))))

(define (日历/月起始星期 year month)
  (define (zeller y m d)
    (define (adjust-month mm)
      (if (<= mm 2) (+ mm 12) mm))
    (define (adjust-year yy mm)
      (if (<= mm 2) (- yy 1) yy))
    (define a (adjust-year y m))
    (define b (adjust-month m))
    (modulo
      (+ d
         (quotient (* 13 (+ b 1)) 5)
         a
         (quotient a 4)
         (- (quotient a 100))
         (quotient a 400))
      7))
  (define day-of-week (zeller year month 1))
  (if (zero? day-of-week) 6 (- day-of-week 1)))

(define (日历/月 year month)
  (define days (日历/月天数 year month))
  (define start (日历/月起始星期 year month))
  (define header (string-join WEEKDAY-ABBR " "))
  (define first-line (string-join (make-list start "   ") ""))
  (define day-strings
    (let loop ((d 1) (acc '()))
      (if (> d days)
        (reverse acc)
        (loop (+ d 1) (cons (format "~2d" d) acc)))))
  (define lines
    (let loop ((ds day-strings) (line first-line) (result '()))
      (cond
        [(null? ds)
         (reverse (if (string=? line "") result (cons line result)))]
        [else
         (define new-line (string-append line " " (car ds)))
         (if (>= (string-length new-line) (* 3 7))
           (loop (cdr ds) "" (cons (string-trim new-line) result))
           (loop (cdr ds) new-line result))])))
  (string-join (cons header lines) "\n"))

(define (日历/年 year)
  (define months
    (for/list ([m (in-range 1 13)])
      (format "~a~n~a" (list-ref MONTH-NAMES (- m 1)) (日历/月 year m))))
  (string-join months "\n\n"))

(define (日历/月日历 year month)
  (日历/月 year month))

(define (日历/星期 year month day)
  (define start (日历/月起始星期 year month))
  (modulo (+ start day -1) 7))

(define (日历/星期几 year month day)
  (list-ref WEEKDAY-NAMES (日历/星期 year month day)))

(define (日历/星期名 n)
  (list-ref WEEKDAY-NAMES (modulo n 7)))

(define (日历/缩写星期名 n)
  (list-ref WEEKDAY-ABBR (modulo n 7)))

(define (日历/月名 n)
  (list-ref MONTH-NAMES (- n 1)))

(define (日历/缩写月名 n)
  (list-ref MONTH-ABBR (- n 1)))

(define (日历/当月)
  (define now (current-seconds))
  (define dt (seconds->date now))
  (list (date-year dt) (date-month dt)))

(define (日历/当月天数)
  (define ym (日历/当月))
  (日历/月天数 (car ym) (cadr ym)))

(define (日历/周天数)
  7)

(define (日历/月范围 year month)
  (list 1 (日历/月天数 year month)))

(define (日历/年范围 year)
  (list 1 (if (日历/闰年 year) 366 365)))

(define (日历/天数总计 year month day)
  (define days-in-months
    (for/list ([m (in-range 1 month)])
      (日历/月天数 year m)))
  (+ (apply + days-in-months) day))

(define (日历/一年中的天数 year month day)
  (日历/天数总计 year month day))