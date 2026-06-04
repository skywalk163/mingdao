#lang racket/base
(require racket/random racket/match racket/format racket/port racket/system racket/string
         racket/list racket/file racket/path)

(provide uuid/生成 uuid/生成1 uuid/生成4 uuid/解析 uuid/转字符串
         uuid/版本 uuid/时钟序列 uuid/节点 uuid/时间戳
         uuid/命名空间DNS uuid/命名空间URL uuid/命名空间OID uuid/命名空间X500
         uuid/生成3 uuid/生成5 uuid/空 uuid/是否是有效)

(define uuid/命名空间DNS   (string->bytes/utf-8 "6ba7b810-9dad-11d1-80b4-00c04fd430c8"))
(define uuid/命名空间URL   (string->bytes/utf-8 "6ba7b811-9dad-11d1-80b4-00c04fd430c8"))
(define uuid/命名空间OID   (string->bytes/utf-8 "6ba7b812-9dad-11d1-80b4-00c04fd430c8"))
(define uuid/命名空间X500  (string->bytes/utf-8 "6ba7b814-9dad-11d1-80b4-00c04fd430c8"))

(define (uuid/空)
  "00000000-0000-0000-0000-000000000000")

(define (随机十六进制 n)
  (define hex-chars "0123456789abcdef")
  (list->string (for/list ([i (in-range n)]) (string-ref hex-chars (random 16)))))

(define (uuid/生成4)
  (string-append
   (随机十六进制 8) "-"
   (随机十六进制 4) "-4"
   (随机十六进制 3) "-"
   (vector-ref #(8 9 a b) (random 4))
   (随机十六进制 3) "-"
   (随机十六进制 12)))

(define (uuid/生成1)
  (define ts (* (current-milliseconds) 1000))
  (define time-low (let ([t (modulo ts (expt 2 32))])
                     (~r t #:base 16 #:min-width 8 #:pad-string "0")))
  (define time-mid (let ([t (modulo (quotient ts (expt 2 32)) (expt 2 16))])
                     (~r t #:base 16 #:min-width 4 #:pad-string "0")))
  (define time-high (let ([t (modulo (quotient ts (expt 2 48)) (expt 2 12))])
                      (~r (bitwise-ior #x1000 t) #:base 16 #:min-width 4 #:pad-string "0")))
  (define node (let ([n (random (expt 2 48))])
                 (~r n #:base 16 #:min-width 12 #:pad-string "0")))
  (define clock-seq (let ([c (random (expt 2 14))])
                      (~r (bitwise-ior #x8000 c) #:base 16 #:min-width 4 #:pad-string "0")))
  (string-append time-low "-" time-mid "-" time-high "-" clock-seq "-" node))

(define uuid/生成 uuid/生成4)

(define (uuid/解析 str)
  (define clean (string-downcase (string-replace str "-" "" #:all? #t)))
  (when (not (= (string-length clean) 32))
    (error "无效的UUID字符串"))
  (string-append (substring clean 0 8) "-"
                 (substring clean 8 12) "-"
                 (substring clean 12 16) "-"
                 (substring clean 16 20) "-"
                 (substring clean 20 32)))

(define (uuid/转字符串 u)
  u)

(define (uuid/版本 u)
  (define clean (string-replace u "-" "" #:all? #t))
  (string->number (substring clean 12 13) 16))

(define (uuid/时钟序列 u)
  (define clean (string-replace u "-" "" #:all? #t))
  (substring clean 16 20))

(define (uuid/节点 u)
  (define clean (string-replace u "-" "" #:all? #t))
  (substring clean 20 32))

(define (uuid/时间戳 u)
  (define clean (string-replace u "-" "" #:all? #t))
  (substring clean 0 12))

(define (uuid/生成3 命名空间 名称)
  (define namespace-hex (string-replace (bytes->string/utf-8 命名空间) "-" "" #:all? #t))
  (define name-str (if (string? 名称) 名称 (format "~a" 名称)))
  (define raw-data (string-append namespace-hex name-str))
  (define hash-str (md5-hash-str raw-data))
  (string-append (substring hash-str 0 8) "-"
                 (substring hash-str 8 12) "-3"
                 (substring hash-str 13 16) "-"
                 (substring hash-str 16 20) "-"
                 (substring hash-str 20 32)))

(define (uuid/生成5 命名空间 名称)
  (define namespace-hex (string-replace (bytes->string/utf-8 命名空间) "-" "" #:all? #t))
  (define name-str (if (string? 名称) 名称 (format "~a" 名称)))
  (define raw-data (string-append namespace-hex name-str))
  (define hash-str (sha1-hash-str raw-data))
  (string-append (substring hash-str 0 8) "-"
                 (substring hash-str 8 12) "-5"
                 (substring hash-str 13 16) "-"
                 (substring hash-str 16 20) "-"
                 (substring hash-str 20 32)))

(define (md5-hash-str s)
  (define tmpfile (string-append (path->string (find-system-path 'temp-dir))
                                 "\\mingdao-uuid-" (number->string (random 1000000) 16) ".tmp"))
  (call-with-output-file tmpfile #:exists 'replace
    (λ (p) (write-bytes (string->bytes/utf-8 s) p)))
  (define proc (process (format "certutil.exe -hashfile ~a MD5" tmpfile)))
  (define stdout (first proc))
  (define lines (port->lines stdout))
  (close-input-port stdout)
  (delete-file tmpfile)
  (string-downcase (string-trim (list-ref lines 1))))

(define (sha1-hash-str s)
  (define tmpfile (string-append (path->string (find-system-path 'temp-dir))
                                 "\\mingdao-uuid-" (number->string (random 1000000) 16) ".tmp"))
  (call-with-output-file tmpfile #:exists 'replace
    (λ (p) (write-bytes (string->bytes/utf-8 s) p)))
  (define proc (process (format "certutil.exe -hashfile ~a SHA1" tmpfile)))
  (define stdout (first proc))
  (define lines (port->lines stdout))
  (close-input-port stdout)
  (delete-file tmpfile)
  (string-downcase (string-trim (list-ref lines 1))))

(define (uuid/是否是有效 str)
  (define uuid-regex #px"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
  (and (string? str)
       (regexp-match? uuid-regex (string-downcase str))))