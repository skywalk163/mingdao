#lang racket/base
(require racket/match
         racket/math)

(provide 打包 解包 打包大小 计算打包大小
         打包/整数大端 打包/整数小端 打包/整数网络序
         解包/整数大端 解包/整数小端 解包/整数网络序
         打包/字符串 解包/字符串
         打包/浮点 解包/浮点
         打包/大端 打包/小端
         解包/大端 解包/小端)

(define (打包 fmt . values)
  (define (parse-fmt fmt)
    (define chars (string->list fmt))
    (define endian 'native)
    (define types '())
    (for ([c (in-list chars)])
      (case c
        [(#\<) (set! endian 'little)]
        [(#\>) (set! endian 'big)]
        [(#\@) (set! endian 'native)]
        [(#\=) (set! endian 'native)]
        [(#\!) (void)]
        [(#\b) (set! types (cons 'int8 types))]
        [(#\B) (set! types (cons 'uint8 types))]
        [(#\h) (set! types (cons 'int16 types))]
        [(#\H) (set! types (cons 'uint16 types))]
        [(#\i) (set! types (cons 'int32 types))]
        [(#\I) (set! types (cons 'uint32 types))]
        [(#\l) (set! types (cons 'int32 types))]
        [(#\L) (set! types (cons 'uint32 types))]
        [(#\q) (set! types (cons 'int64 types))]
        [(#\Q) (set! types (cons 'uint64 types))]
        [(#\f) (set! types (cons 'float types))]
        [(#\d) (set! types (cons 'double types))]
        [else (void)]))
    (values endian (reverse types)))
  (define-values (endian types) (parse-fmt fmt))
  (define (pack-value val type)
    (match type
      ['int8 (integer->integer-bytes val 1 #f (eq? endian 'little))]
      ['uint8 (integer->integer-bytes val 1 #f (eq? endian 'little))]
      ['int16 (integer->integer-bytes val 2 #f (eq? endian 'little))]
      ['uint16 (integer->integer-bytes val 2 #f (eq? endian 'little))]
      ['int32 (integer->integer-bytes val 4 #f (eq? endian 'little))]
      ['uint32 (integer->integer-bytes val 4 #f (eq? endian 'little))]
      ['int64 (integer->integer-bytes val 8 #f (eq? endian 'little))]
      ['uint64 (integer->integer-bytes val 8 #f (eq? endian 'little))]
      ['float (real->floating-point-bytes (real->double-flonum val) 4 32 #t (eq? endian 'little))]
      ['double (real->floating-point-bytes (real->double-flonum val) 8 64 #t (eq? endian 'little))]))
  (apply bytes-append (map pack-value values types)))

(define (解包 fmt bstr)
  (define (parse-fmt fmt)
    (define chars (string->list fmt))
    (define endian 'native)
    (define types '())
    (for ([c (in-list chars)])
      (case c
        [(#\<) (set! endian 'little)]
        [(#\>) (set! endian 'big)]
        [(#\@) (set! endian 'native)]
        [(#\=) (set! endian 'native)]
        [(#\!) (void)]
        [(#\b) (set! types (cons 'int8 types))]
        [(#\B) (set! types (cons 'uint8 types))]
        [(#\h) (set! types (cons 'int16 types))]
        [(#\H) (set! types (cons 'uint16 types))]
        [(#\i) (set! types (cons 'int32 types))]
        [(#\I) (set! types (cons 'uint32 types))]
        [(#\l) (set! types (cons 'int32 types))]
        [(#\L) (set! types (cons 'uint32 types))]
        [(#\q) (set! types (cons 'int64 types))]
        [(#\Q) (set! types (cons 'uint64 types))]
        [(#\f) (set! types (cons 'float types))]
        [(#\d) (set! types (cons 'double types))]
        [else (void)]))
    (values endian (reverse types)))
  (define-values (endian types) (parse-fmt fmt))
  (define type-sizes
    '((int8 . 1) (uint8 . 1) (int16 . 2) (uint16 . 2)
      (int32 . 4) (uint32 . 4) (int64 . 8) (uint64 . 8)
      (float . 4) (double . 8)))
  (define (unpack-one offset type)
    (define size (cdr (assq type type-sizes)))
    (define chunk (subbytes bstr offset (+ offset size)))
    (match type
      ['int8 (integer-bytes->integer chunk #f (eq? endian 'little))]
      ['uint8 (integer-bytes->integer chunk #f (eq? endian 'little))]
      ['int16 (integer-bytes->integer chunk #f (eq? endian 'little))]
      ['uint16 (integer-bytes->integer chunk #f (eq? endian 'little))]
      ['int32 (integer-bytes->integer chunk #f (eq? endian 'little))]
      ['uint32 (integer-bytes->integer chunk #f (eq? endian 'little))]
      ['int64 (integer-bytes->integer chunk #f (eq? endian 'little))]
      ['uint64 (integer-bytes->integer chunk #f (eq? endian 'little))]
      ['float (floating-point-bytes->real chunk 4 32 #t (eq? endian 'little))]
      ['double (floating-point-bytes->real chunk 8 64 #t (eq? endian 'little))]))
  (let loop ([offset 0] [types types] [results '()])
    (if (null? types)
        (reverse results)
        (let ([val (unpack-one offset (car types))])
          (loop (+ offset (cdr (assq (car types) type-sizes))) (cdr types) (cons val results))))))

(define (打包大小 fmt)
  (define type-sizes
    '((#\b . 1) (#\B . 1) (#\h . 2) (#\H . 2)
      (#\i . 4) (#\I . 4) (#\l . 4) (#\L . 4)
      (#\q . 8) (#\Q . 8) (#\f . 4) (#\d . 8)))
  (define chars (string->list fmt))
  (for/sum ([c chars])
    (cond
      [(assq c type-sizes) => cdr]
      [else 0])))

(define (计算打包大小 fmt)
  (打包大小 fmt))

(define (打包/整数大端 val size)
  (integer->integer-bytes val size #t #f))

(define (打包/整数小端 val size)
  (integer->integer-bytes val size #f #f))

(define (打包/整数网络序 val size)
  (打包/整数大端 val size))

(define (解包/整数大端 bstr)
  (integer-bytes->integer bstr #t #f))

(define (解包/整数小端 bstr)
  (integer-bytes->integer bstr #f #f))

(define (解包/整数网络序 bstr)
  (解包/整数大端 bstr))

(define (打包/字符串 s)
  (string->bytes/utf-8 s))

(define (解包/字符串 bstr)
  (bytes->string/utf-8 bstr))

(define (打包/浮点 val)
  (real->floating-point-bytes (real->double-flonum val) 8 64 #t #f))

(define (解包/浮点 bstr)
  (floating-point-bytes->real bstr 8 64 #t #f))

(define (打包/大端 fmt . values)
  (apply 打包 (string-append ">" fmt) values))

(define (打包/小端 fmt . values)
  (apply 打包 (string-append "<" fmt) values))

(define (解包/大端 fmt bstr)
  (解包 (string-append ">" fmt) bstr))

(define (解包/小端 fmt bstr)
  (解包 (string-append "<" fmt) bstr))