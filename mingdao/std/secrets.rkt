#lang racket/base
(require racket/random racket/list)

(provide 秘密/令牌字节 秘密/令牌十六进制 秘密/令牌URL安全
         秘密/随机整数范围 秘密/随机选择 秘密/随机打乱
         秘密/比较哈希 秘密/令牌二进制)

(define (秘密/令牌字节 n)
  (list->bytes (for/list ([i (in-range n)]) (random 256))))

(define (秘密/令牌十六进制 n)
  (define hex-chars "0123456789abcdef")
  (list->string
   (for/list ([i (in-range (* n 2))])
     (string-ref hex-chars (random 16)))))

(define (秘密/令牌URL安全 n)
  (define b64-chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
  (define len (quotient (+ (* n 8) 6 -1) 6))
  (list->string
   (for/list ([i (in-range len)])
     (string-ref b64-chars (random 64)))))

(define (秘密/随机整数范围 [最小值 0] [最大值 100])
  (define min-val (if (integer? 最小值) 最小值 0))
  (define max-val (if (integer? 最大值) 最大值 100))
  (when (> min-val max-val)
    (error "最小值不能大于最大值"))
  (+ min-val (random (- max-val min-val))))

(define (秘密/随机选择 lst)
  (when (null? lst)
    (error "列表不能为空"))
  (list-ref lst (random (length lst))))

(define (秘密/随机打乱 lst)
  (define result (append lst '()))
  (define n (length result))
  (for ([i (in-range n)])
    (define j (+ i (random (- n i))))
    (define tmp (list-ref result i))
    (set! result (list-set result i (list-ref result j)))
    (set! result (list-set result j tmp)))
  result)

(define (秘密/比较哈希 a b)
  (define a-len (bytes-length a))
  (define b-len (bytes-length b))
  (define min-len (min a-len b-len))
  (define result (bitwise-xor a-len b-len))
  (for ([i (in-range min-len)])
    (set! result (bitwise-ior result (bitwise-xor (bytes-ref a i) (bytes-ref b i)))))
  (= result 0))

(define (秘密/令牌二进制 n)
  (秘密/令牌字节 n))