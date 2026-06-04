#lang racket/base
(require racket/string racket/list racket/match)

(provide 文件名/匹配 文件名/过滤 文件名/转义 文件名/转换正则)

(define (文件名/转换正则 pattern)
  (define special-chars '(#\. #\+ #\^ #\$ #\( #\) #\[ #\] #\{ #\} #\\ #\|))
  (define chars (string->list pattern))
  (define (process-chars chars)
    (match chars
      ['() ""]
      [(cons #\? rest) (string-append "." (process-chars rest))]
      [(cons #\* rest) (string-append ".*" (process-chars rest))]
      [(cons c rest)
       (if (member c special-chars)
           (string-append "\\" (string c) (process-chars rest))
           (string-append (string c) (process-chars rest)))]))
  (string-append "^" (process-chars chars) "$"))

(define (文件名/匹配 pattern name)
  (regexp-match? (regexp (文件名/转换正则 pattern)) name))

(define (文件名/过滤 pattern names)
  (filter (λ (n) (文件名/匹配 pattern n)) names))

(define (文件名/转义 pattern)
  (define special-chars '(#\* #\? #\[ #\]))
  (list->string
   (apply append
          (map (λ (c)
                 (if (member c special-chars)
                     (list #\\ c)
                     (list c)))
               (string->list pattern)))))