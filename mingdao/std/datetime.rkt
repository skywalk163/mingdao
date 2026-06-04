#lang racket/base
(require racket/date racket/format racket/string racket/list)

(provide 今天 日期/创建 日期/年 日期/月 日期/日 日期/星期 日期/差 日期/加
         时间/创建 时间/时 时间/分 时间/秒
         现在 日期时间/创建 日期时间/格式化 解析日期
         时间差/天 时间差/小时 时间差/分钟 时间差/秒
         现在时间戳 时间戳转日期 星期几 天数)

;; ── 辅助 ──────────────────────────────────────────

(define (→日期 dt)
  (if (date? dt) dt (seconds->date dt)))

(define (→秒 年 月 日 时 分 秒)
  (find-seconds 秒 分 时 日 月 年 #f))

(define (解析日期串 s)
  (define parts (regexp-split #px"-" s))
  (define 年 (string->number (list-ref parts 0)))
  (define 月 (string->number (list-ref parts 1)))
  (define 日 (string->number (list-ref parts 2)))
  (values 年 月 日))

(define (补零 n w)
  (~r n #:min-width w #:pad-string "0"))

(define 星期名
  #("星期日" "星期一" "星期二" "星期三" "星期四" "星期五" "星期六"))

;; ── 日期函数 ─────────────────────────────────────

(define (今天)
  (define now (current-date))
  (format "~a-~a-~a" (date-year now) (补零 (date-month now) 2) (补零 (date-day now) 2)))

(define (日期/创建 年 月 日)
  (format "~a-~a-~a" (补零 年 4) (补零 月 2) (补零 日 2)))

(define (日期/年 日期串)
  (define-values (年 月 日) (解析日期串 日期串))
  年)

(define (日期/月 日期串)
  (define-values (年 月 日) (解析日期串 日期串))
  月)

(define (日期/日 日期串)
  (define-values (年 月 日) (解析日期串 日期串))
  日)

(define (日期/星期 日期串)
  (define-values (年 月 日) (解析日期串 日期串))
  (define dt (seconds->date (find-seconds 0 0 0 日 月 年 #f)))
  (vector-ref 星期名 (date-week-day dt)))

(define (日期/差 d1 d2)
  (define-values (y1 m1 d1n) (解析日期串 d1))
  (define-values (y2 m2 d2n) (解析日期串 d2))
  (define ts1 (find-seconds 0 0 0 d1n m1 y1 #f))
  (define ts2 (find-seconds 0 0 0 d2n m2 y2 #f))
  (inexact->exact (round (/ (- ts2 ts1) 86400))))

(define (日期/加 日期串 天数)
  (define-values (年 月 日) (解析日期串 日期串))
  (define ts (find-seconds 0 0 0 日 月 年 #f))
  (define new-ts (+ ts (* 天数 86400)))
  (define new-date (seconds->date new-ts))
  (format "~a-~a-~a" (date-year new-date) (补零 (date-month new-date) 2) (补零 (date-day new-date) 2)))

;; ── 时间函数 ─────────────────────────────────────

(define (时间/创建 时 分 秒)
  (format "~a:~a:~a" (补零 时 2) (补零 分 2) (补零 秒 2)))

(define (时间/时 时间串)
  (string->number (substring 时间串 0 2)))

(define (时间/分 时间串)
  (string->number (substring 时间串 3 5)))

(define (时间/秒 时间串)
  (string->number (substring 时间串 6 8)))

;; ── 日期时间函数 ─────────────────────────────────

(define (现在)
  (define now (current-date))
  (format "~a-~a-~a ~a:~a:~a"
          (date-year now) (补零 (date-month now) 2) (补零 (date-day now) 2)
          (补零 (date-hour now) 2) (补零 (date-minute now) 2) (补零 (date-second now) 2)))

(define (日期时间/创建 年 月 日 时 分 秒)
  (format "~a-~a-~a ~a:~a:~a"
          (补零 年 4) (补零 月 2) (补零 日 2)
          (补零 时 2) (补零 分 2) (补零 秒 2)))

(define (日期时间/格式化 dt-str fmt)
  (define-values (年 月 日 时 分 秒) (解析完整日期时间 dt-str))
  (define 映射
    (list (cons "%Y" (补零 年 4)) (cons "%y" (substring (补零 年 4) 2 4))
          (cons "%m" (补零 月 2)) (cons "%d" (补零 日 2))
          (cons "%H" (补零 时 2)) (cons "%M" (补零 分 2)) (cons "%S" (补零 秒 2))))
  (for/fold ([r fmt]) ([p 映射])
    (string-replace r (car p) (cdr p))))

(define (解析完整日期时间 dt-str)
  (define parts (regexp-split #px"[ :-]" dt-str))
  (define 年 (string->number (list-ref parts 0)))
  (define 月 (string->number (list-ref parts 1)))
  (define 日 (string->number (list-ref parts 2)))
  (define 时 (if (> (length parts) 3) (string->number (list-ref parts 3)) 0))
  (define 分 (if (> (length parts) 4) (string->number (list-ref parts 4)) 0))
  (define 秒 (if (> (length parts) 5) (string->number (list-ref parts 5)) 0))
  (values 年 月 日 时 分 秒))

(define (解析日期 str fmt)
  (define 格式符
    (list (cons "%Y" "(\\d{4})") (cons "%m" "(\\d{2})") (cons "%d" "(\\d{2})")
          (cons "%H" "(\\d{2})") (cons "%M" "(\\d{2})") (cons "%S" "(\\d{2})")))
  (define 顺序 '())
  (define 模式部件 '())
  (let loop ([i 0])
    (when (< i (string-length fmt))
      (if (and (< (add1 i) (string-length fmt))
               (char=? (string-ref fmt i) #\%)
               (assoc (substring fmt i (+ i 2)) 格式符))
        (let* ([spec (substring fmt i (+ i 2))]
               [entry (assoc spec 格式符)])
          (set! 顺序 (append 顺序 (list spec)))
          (set! 模式部件 (append 模式部件 (list (cdr entry))))
          (loop (+ i 2)))
        (begin
          (set! 模式部件 (append 模式部件 (list (regexp-quote (string (string-ref fmt i))))))
          (loop (+ i 1))))))
  (define 模式 (string-join 模式部件 ""))
  (define m (regexp-match (pregexp 模式) str))
  (unless m (error (format "无法用格式 ~a 解析日期字符串: ~a" fmt str)))
  (define 捕获 (cdr m))
  (define (取 idx 缺省)
    (if idx (list-ref 捕获 idx) 缺省))
  (define y (取 (index-of 顺序 "%Y") "0000"))
  (define mo (取 (index-of 顺序 "%m") "01"))
  (define d (取 (index-of 顺序 "%d") "01"))
  (define h (取 (index-of 顺序 "%H") "00"))
  (define mi (取 (index-of 顺序 "%M") "00"))
  (define s (取 (index-of 顺序 "%S") "00"))
  (format "~a-~a-~a ~a:~a:~a" y mo d h mi s))

;; ── 时间差 ───────────────────────────────────────

(define (时间差/天 n) (* n 86400))
(define (时间差/小时 n) (* n 3600))
(define (时间差/分钟 n) (* n 60))
(define (时间差/秒 n) n)

;; ── 实用 ─────────────────────────────────────────

(define (现在时间戳)
  (current-seconds))

(define (时间戳转日期 ts)
  (define dt (seconds->date ts))
  (format "~a-~a-~a" (date-year dt) (补零 (date-month dt) 2) (补零 (date-day dt) 2)))

(define (星期几 年 月 日)
  (define dt (seconds->date (find-seconds 0 0 0 日 月 年 #f)))
  (modulo (+ (date-week-day dt) 6) 7))

(define (天数 年 月)
  (define next-month (if (= 月 12) 1 (add1 月)))
  (define next-year (if (= 月 12) (add1 年) 年))
  (define ts (find-seconds 0 0 0 1 next-month next-year #f))
  (define last-day (seconds->date (- ts 86400)))
  (date-day last-day))