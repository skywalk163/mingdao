#lang racket

(require "../lang/tokenizer.rkt")

;; 检查哪些字符会被认为是关键字开头
(define (could-start-keyword? ch)
  (and (char? ch)
       (ormap (λ (kw) (char=? (string-ref kw 0) ch))
              (append 双字关键字 三字关键字 四字关键字 单字关键字 单字运算符))))

(displayln "检查 '生' 字符:")
(displayln (could-start-keyword? #\生))

(displayln "\n检查 '命' 字符:")
(displayln (could-start-keyword? #\命))

(displayln "\n所有以'生'开头的关键字:")
(for ([kw (append 双字关键字 三字关键字 四字关键字 单字关键字 单字运算符)])
  (when (char=? (string-ref kw 0) #\生)
    (displayln kw)))

(displayln "\n所有以'命'开头的关键字:")
(for ([kw (append 双字关键字 三字关键字 四字关键字 单字关键字 单字运算符)])
  (when (char=? (string-ref kw 0) #\命)
    (displayln kw)))

(displayln "\n所有关键字列表:")
(pretty-print 双字关键字)
