#lang racket/base
(require racket/string)

(provide 小写字母 大写字母 数字字符 标点字符 空白字符 可打印字符
         十六进制字符 八进制字符 ascii字母 大小写字母
         ascii小写 ascii大写 ascii数字 ascii标点 ascii空白 ascii可打印
         字符串/大写 字符串/小写 字符串/首字母大写 字符串/首字母小写
         字符串/反转 字符串/居中 字符串/左对齐 字符串/右对齐
         字符串/开头判断 字符串/结尾判断
         字符串/交换大小写 字符串/下划线转驼峰 字符串/驼峰转下划线
         字符串/压缩空白 字符串/按宽度折行 字符串/切分行
         字符串/删除前缀 字符串/删除后缀
         字符串/格式 字符串/模板 字符串/转义
         字符串/索引所有 字符串/匹配计数)

(define 小写字母 "abcdefghijklmnopqrstuvwxyz")
(define 大写字母 "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
(define 数字字符 "0123456789")
(define 十六进制字符 "0123456789abcdefABCDEF")
(define 八进制字符 "01234567")
(define 标点字符 "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
(define 空白字符 " \t\n\r\v\f")
(define 可打印字符 (string-append 小写字母 大写字母 数字字符 标点字符 空白字符))

(define ascii小写 小写字母)
(define ascii大写 大写字母)
(define ascii数字 数字字符)
(define ascii标点 标点字符)
(define ascii空白 空白字符)
(define ascii可打印 可打印字符)
(define ascii字母 (string-append 小写字母 大写字母))
(define 大小写字母 (string-append 小写字母 大写字母))
(define 可打印 可打印字符)
(define ascii_letters 大小写字母)
(define ascii_lowercase 小写字母)
(define ascii_uppercase 大写字母)
(define 数字 数字字符)
(define 十六进制 十六进制字符)
(define 八进制 八进制字符)
(define 标点 标点字符)
(define 空白 空白字符)

(define (字符串/大写 s)
  (string-upcase s))

(define (字符串/小写 s)
  (string-downcase s))

(define (字符串/首字母大写 s)
  (if (zero? (string-length s))
      s
      (string-append (string (char-upcase (string-ref s 0)))
                     (string-downcase (substring s 1)))))

(define (字符串/首字母小写 s)
  (if (zero? (string-length s))
      s
      (string-append (string (char-downcase (string-ref s 0)))
                     (substring s 1))))

(define (字符串/反转 s)
  (list->string (reverse (string->list s))))

(define (字符串/居中 s width [pad " "])
  (define pad-len (string-length pad))
  (define total-pad (- width (string-length s)))
  (define left-pad (quotient total-pad 2))
  (define right-pad (- total-pad left-pad))
  (define (make-pad n)
    (if (<= n 0)
        ""
        (let loop ([i n] [acc ""])
          (if (< i pad-len)
              (string-append acc (substring pad 0 i))
              (loop (- i pad-len) (string-append acc pad))))))
  (string-append (make-pad left-pad) s (make-pad right-pad)))

(define (字符串/左对齐 s width [pad " "])
  (define pad-len (string-length pad))
  (define (make-pad n)
    (if (<= n 0)
        ""
        (let loop ([i n] [acc ""])
          (if (< i pad-len)
              (string-append acc (substring pad 0 i))
              (loop (- i pad-len) (string-append acc pad))))))
  (define s-len (string-length s))
  (if (>= s-len width)
      s
      (let ((need (- width s-len)))
        (string-append s (make-pad need)))))

(define (字符串/右对齐 s width [pad " "])
  (define pad-len (string-length pad))
  (define (make-pad n)
    (if (<= n 0)
        ""
        (let loop ([i n] [acc ""])
          (if (< i pad-len)
              (string-append (substring pad 0 i) acc)
              (loop (- i pad-len) (string-append pad acc))))))
  (define s-len (string-length s))
  (if (>= s-len width)
      s
      (let ((need (- width s-len)))
        (string-append (make-pad need) s))))

(define (字符串/开头判断 s prefix)
  (string-prefix? s prefix))

(define (字符串/结尾判断 s suffix)
  (string-suffix? s suffix))

(define (字符串/交换大小写 s)
  (list->string
   (map (lambda (c)
          (cond
            [(char-upper-case? c) (char-downcase c)]
            [(char-lower-case? c) (char-upcase c)]
            [else c]))
        (string->list s))))

(define (字符串/下划线转驼峰 s)
  (define parts (string-split s "_"))
  (define (capitalize-first s)
    (if (zero? (string-length s))
        s
        (string-append (string (char-upcase (string-ref s 0)))
                       (substring s 1))))
  (string-join (cons (car parts) (map capitalize-first (cdr parts))) ""))

(define (字符串/驼峰转下划线 s)
  (define chars (string->list s))
  (define result
    (for/list ([c chars] [i (in-naturals)])
      (if (and (> i 0) (char-upper-case? c))
          (string-append "_" (string (char-downcase c)))
          (string (char-downcase c)))))
  (string-join result ""))

(define (字符串/压缩空白 s)
  (regexp-replace* #px"\\s+" s " "))

(define (字符串/按宽度折行 s width)
  (define words (string-split s))
  (define (loop words lines current-line)
    (cond
      [(null? words) (reverse (if (string=? current-line "") lines (cons current-line lines)))]
      [else
       (define word (car words))
       (if (string=? current-line "")
           (loop (cdr words) lines word)
           (if (<= (+ (string-length current-line) 1 (string-length word)) width)
               (loop (cdr words) lines (string-append current-line " " word))
               (loop (cdr words) (cons current-line lines) word)))]))
  (string-join (loop words '() "") "\n"))

(define (字符串/切分行 s)
  (string-split s "\n"))

(define (字符串/删除前缀 s prefix)
  (if (string-prefix? s prefix)
      (substring s (string-length prefix))
      s))

(define (字符串/删除后缀 s suffix)
  (if (string-suffix? s suffix)
      (substring s 0 (- (string-length s) (string-length suffix)))
      s))

(define (字符串/格式 fmt . args)
  (apply format fmt args))

(define (字符串/模板 s . args)
  (define (replace-holder s key value)
    (regexp-replace* (string-append "\\{" key "\\}") s value))
  (define keys-and-vals
    (for/list ([arg args] [i (in-naturals)])
      (cons (number->string i) (format "~a" arg))))
  (for/fold ([result s]) ([kv keys-and-vals])
    (replace-holder result (car kv) (cdr kv))))

(define (字符串/转义 s)
  (regexp-replace* #rx"[\\\"\n\r\t]" s
                   (lambda (m)
                     (case (string-ref m 0)
                       [(#\newline) "\\n"]
                       [(#\return) "\\r"]
                       [(#\tab) "\\t"]
                       [(#\") "\\\""]
                       [(#\\) "\\\\"]
                       [else (string (string-ref m 0))]))))

(define (字符串/索引所有 s sub)
  (define sub-len (string-length sub))
  (define (loop start acc)
    (define pos (regexp-match-positions (regexp (regexp-quote sub)) s start))
    (if pos
        (loop (+ (car (car pos)) 1) (cons (car (car pos)) acc))
        (reverse acc)))
  (loop 0 '()))

(define (字符串/匹配计数 s sub)
  (length (字符串/索引所有 s sub)))