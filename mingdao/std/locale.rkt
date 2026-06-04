#lang racket/base
(require racket/list
         racket/string
         racket/format)

(provide 本地化/默认 本地化/设置 本地化/获取 本地化/货币 本地化/语言
         本地化/编码 本地化/数字格式 本地化/日期格式 本地化/时间格式
         本地化/可用列表)

(define *当前本地化设置* (make-parameter "C"))
(define *可用本地化列表* '("C" "en_US" "zh_CN" "ja_JP" "ko_KR" "fr_FR" "de_DE" "es_ES"))

(define (本地化/默认)
  "C")

(define (本地化/设置 locale)
  (*当前本地化设置* locale)
  (define dot-pos (regexp-match-positions #rx"\\." locale))
  (if dot-pos
      (substring locale 0 (car (car dot-pos)))
      locale))

(define (本地化/获取)
  (*当前本地化设置*))

(define (本地化/货币 value)
  (define locale (*当前本地化设置*))
  (cond
    [(string-contains? locale "zh") (format "¥~a" (~r value))]
    [(string-contains? locale "ja") (format "¥~a" (~r value))]
    [(string-contains? locale "en") (format "$~a" (~r value))]
    [(string-contains? locale "fr") (format "~a €" (~r value))]
    [(string-contains? locale "de") (format "~a €" (~r value))]
    [else (format "~a" (~r value))]))

(define (本地化/语言)
  (define locale (本地化/获取))
  (cond
    [(string-contains? locale "en") "english"]
    [(string-contains? locale "zh") "chinese"]
    [(string-contains? locale "ja") "japanese"]
    [(string-contains? locale "ko") "korean"]
    [(string-contains? locale "fr") "french"]
    [(string-contains? locale "de") "german"]
    [(string-contains? locale "es") "spanish"]
    [else "unknown"]))

(define (本地化/编码)
  "UTF-8")

(define (本地化/数字格式)
  (hash 'decimal-point "."
        'thousands-sep ","
        'grouping '(3)))

(define (本地化/日期格式)
  (define locale (*当前本地化设置*))
  (cond
    [(string-contains? locale "zh") "%Y年%m月%d日"]
    [(string-contains? locale "en") "%m/%d/%Y"]
    [(string-contains? locale "ja") "%Y年%m月%d日"]
    [(string-contains? locale "fr") "%d/%m/%Y"]
    [else "%Y-%m-%d"]))

(define (本地化/时间格式)
  (define locale (*当前本地化设置*))
  (cond
    [(string-contains? locale "en") "%I:%M:%S %p"]
    [(string-contains? locale "zh") "%H:%M:%S"]
    [(string-contains? locale "ja") "%H:%M:%S"]
    [else "%H:%M:%S"]))

(define (本地化/可用列表)
  *可用本地化列表*)