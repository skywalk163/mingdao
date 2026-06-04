#lang racket/base
(require racket/bytes
         racket/list
         racket/string
         racket/port
         racket/hash
         net/base64)

(provide 编解码/编码 编解码/解码 编解码/查找 编解码/注册 编解码/支持编码列表
         编解码/utf8编码 编解码/utf8解码 编解码/ascii编码 编解码/ascii解码
         编解码/latin1编码 编解码/latin1解码 编解码/utf16编码 编解码/utf16解码
         编解码/base64编码 编解码/base64解码 编解码/hex编码 编解码/hex解码
         编解码/rot13编码 编解码/rot13解码)

(define *编码注册表* (make-hash))

(define (编解码/查找 encoding)
  (hash-ref *编码注册表* encoding #f))

(define (编解码/注册 encoding encode-fn decode-fn)
  (hash-set! *编码注册表* encoding (cons encode-fn decode-fn)))

(define (编解码/支持编码列表)
  (hash-keys *编码注册表*))

(define (编解码/utf8编码 str)
  (string->bytes/utf-8 str))

(define (编解码/utf8解码 bstr)
  (bytes->string/utf-8 bstr))

(define (编解码/ascii编码 str)
  (define bstr (string->bytes/utf-8 str))
  (define len (bytes-length bstr))
  (define result (make-bytes len))
  (let loop ([i 0])
    (when (< i len)
      (let ([b (bytes-ref bstr i)])
        (bytes-set! result i (if (> b 127) 63 b))
        (loop (add1 i)))))
  result)

(define (编解码/ascii解码 bstr)
  (bytes->string/latin-1 bstr))

(define (编解码/latin1编码 str)
  (string->bytes/latin-1 str))

(define (编解码/latin1解码 bstr)
  (bytes->string/latin-1 bstr))

(define (编解码/utf16编码 str)
  (define out (open-output-bytes))
  (for ([c (in-string str)])
    (let ([cp (char->integer c)])
      (cond
        [(<= cp #xFFFF)
         (write-byte (bitwise-and cp #xFF) out)
         (write-byte (bitwise-and (arithmetic-shift cp -8) #xFF) out)]
        [else
         (let* ([cp2 (- cp #x10000)]
                [hi (+ #xD800 (arithmetic-shift cp2 -10))]
                [lo (+ #xDC00 (bitwise-and cp2 #x3FF))])
           (write-byte (bitwise-and hi #xFF) out)
           (write-byte (bitwise-and (arithmetic-shift hi -8) #xFF) out)
           (write-byte (bitwise-and lo #xFF) out)
           (write-byte (bitwise-and (arithmetic-shift lo -8) #xFF) out))])))
  (get-output-bytes out))

(define (编解码/utf16解码 bstr)
  (define len (bytes-length bstr))
  (define result (open-output-string))
  (let loop ([i 0])
    (when (< i len)
      (define lo (bytes-ref bstr i))
      (define hi (bytes-ref bstr (add1 i)))
      (define val (+ lo (* hi 256)))
      (if (and (>= val #xD800) (<= val #xDBFF))
          (let* ([lo2 (bytes-ref bstr (+ i 2))]
                 [hi2 (bytes-ref bstr (+ i 3))]
                 [val2 (+ lo2 (* hi2 256))]
                 [cp (+ #x10000 (arithmetic-shift (- val #xD800) 10) (- val2 #xDC00))])
            (write-char (integer->char cp) result)
            (loop (+ i 4)))
          (begin
            (write-char (integer->char val) result)
            (loop (+ i 2))))))
  (get-output-string result))

(define (编解码/base64编码 str)
  (string-trim (bytes->string/utf-8 (base64-encode (string->bytes/utf-8 str)))))

(define (编解码/base64解码 str)
  (bytes->string/utf-8 (base64-decode (string->bytes/utf-8 str))))

(define (编解码/hex编码 bstr)
  (define hex-chars "0123456789abcdef")
  (define len (bytes-length bstr))
  (define result (make-string (* len 2)))
  (let loop ([i 0])
    (when (< i len)
      (define b (bytes-ref bstr i))
      (string-set! result (* i 2) (string-ref hex-chars (arithmetic-shift b -4)))
      (string-set! result (+ 1 (* i 2)) (string-ref hex-chars (bitwise-and b #xF)))
      (loop (add1 i))))
  result)

(define (编解码/hex解码 str)
  (define len (string-length str))
  (define result (make-bytes (quotient len 2)))
  (let loop ([i 0])
    (when (< i (quotient len 2))
      (define hi (string-ref str (* i 2)))
      (define lo (string-ref str (+ 1 (* i 2))))
      (define hi-val (- (char->integer hi) (if (char<=? hi #\9) 48 (if (char<=? hi #\F) 55 87))))
      (define lo-val (- (char->integer lo) (if (char<=? lo #\9) 48 (if (char<=? lo #\F) 55 87))))
      (bytes-set! result i (+ (arithmetic-shift hi-val 4) lo-val))
      (loop (add1 i))))
  result)

(define (编解码/编码 encoding str)
  (cond
    [(equal? encoding "utf-8") (编解码/utf8编码 str)]
    [(equal? encoding "ascii") (编解码/ascii编码 str)]
    [(equal? encoding "latin-1") (编解码/latin1编码 str)]
    [(equal? encoding "utf-16") (编解码/utf16编码 str)]
    [(equal? encoding "base64") (编解码/base64编码 str)]
    [(equal? encoding "hex") (编解码/hex编码 str)]
    [(equal? encoding "rot13") (编解码/rot13编码 str)]
    [else (let ([entry (编解码/查找 encoding)])
            (if entry
                ((car entry) str)
                (raise (format "不支持的编码: ~a" encoding))))]))

(define (编解码/解码 encoding bstr)
  (cond
    [(equal? encoding "utf-8") (编解码/utf8解码 bstr)]
    [(equal? encoding "ascii") (编解码/ascii解码 bstr)]
    [(equal? encoding "latin-1") (编解码/latin1解码 bstr)]
    [(equal? encoding "utf-16") (编解码/utf16解码 bstr)]
    [(equal? encoding "base64") (编解码/base64解码 (if (bytes? bstr) (bytes->string/utf-8 bstr) bstr))]
    [(equal? encoding "hex") (编解码/hex解码 bstr)]
    [(equal? encoding "rot13") (编解码/rot13解码 bstr)]
    [else (let ([entry (编解码/查找 encoding)])
             (if entry
                 ((cdr entry) bstr)
                 (raise (format "不支持的编码: ~a" encoding))))]))

(define (编解码/rot13编码 str)
  (list->string
   (map (lambda (c)
          (cond
            [(char<=? #\a c #\z)
             (integer->char (+ (modulo (+ (- (char->integer c) (char->integer #\a)) 13) 26)
                              (char->integer #\a)))]
            [(char<=? #\A c #\Z)
             (integer->char (+ (modulo (+ (- (char->integer c) (char->integer #\A)) 13) 26)
                              (char->integer #\A)))]
            [else c]))
        (string->list str))))

(define (编解码/rot13解码 str)
  (编解码/rot13编码 str))