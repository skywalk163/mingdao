#lang racket/base
(require racket/date racket/format racket/string)

(provide 当前时间 当前日期 当前时间戳
         格式化时间 休眠
         时间戳转时间 时间转时间戳)

(define (当前时间)
  (define now (current-date))
  (format "~a-~a-~a ~a:~a:~a"
          (date-year now)
          (~r (date-month now) #:min-width 2 #:pad-string "0")
          (~r (date-day now) #:min-width 2 #:pad-string "0")
          (~r (date-hour now) #:min-width 2 #:pad-string "0")
          (~r (date-minute now) #:min-width 2 #:pad-string "0")
          (~r (date-second now) #:min-width 2 #:pad-string "0")))

(define (当前日期)
  (define now (current-date))
  (format "~a-~a-~a"
          (date-year now)
          (~r (date-month now) #:min-width 2 #:pad-string "0")
          (~r (date-day now) #:min-width 2 #:pad-string "0")))

(define (当前时间戳)
  (current-seconds))

(define (格式化时间 fmt)
  (define now (current-date))
  (define replacements
    (list
      (cons "%Y" (~r (date-year now) #:min-width 4 #:pad-string "0"))
      (cons "%m" (~r (date-month now) #:min-width 2 #:pad-string "0"))
      (cons "%d" (~r (date-day now) #:min-width 2 #:pad-string "0"))
      (cons "%H" (~r (date-hour now) #:min-width 2 #:pad-string "0"))
      (cons "%M" (~r (date-minute now) #:min-width 2 #:pad-string "0"))
      (cons "%S" (~r (date-second now) #:min-width 2 #:pad-string "0"))))
  (for/fold ([result fmt]) ([pair (in-list replacements)])
    (string-replace result (car pair) (cdr pair))))

(define (休眠 ms)
  (define sec (/ ms 1000.0))
  (sleep sec))

(define (时间戳转时间 ts)
  (define dt (seconds->date ts))
  (format "~a-~a-~a ~a:~a:~a"
          (date-year dt)
          (~r (date-month dt) #:min-width 2 #:pad-string "0")
          (~r (date-day dt) #:min-width 2 #:pad-string "0")
          (~r (date-hour dt) #:min-width 2 #:pad-string "0")
          (~r (date-minute dt) #:min-width 2 #:pad-string "0")
          (~r (date-second dt) #:min-width 2 #:pad-string "0")))

(define (时间转时间戳 time-str)
  (define parts (regexp-split #px"[ :-]" time-str))
  (when (< (length parts) 6)
    (error "时间格式错误，需要 YYYY-MM-DD HH:MM:SS"))
  (define year (string->number (list-ref parts 0)))
  (define month (string->number (list-ref parts 1)))
  (define day (string->number (list-ref parts 2)))
  (define hour (string->number (list-ref parts 3)))
  (define minute (string->number (list-ref parts 4)))
  (define second (string->number (list-ref parts 5)))
  (find-seconds second minute hour day month year #f))