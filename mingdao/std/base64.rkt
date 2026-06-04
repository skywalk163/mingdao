#lang racket/base
(require net/base64
         racket/string)

(provide base64编码 base64解码 base64url编码 base64url解码)

(define (base64编码 str)
  (with-handlers ([exn:fail? (λ (e) (error "base64编码错误: ~a" (exn-message e)))])
    (string-trim (bytes->string/utf-8 (base64-encode (string->bytes/utf-8 str))))))

(define (base64解码 str)
  (with-handlers ([exn:fail? (λ (e) (error "base64解码错误: ~a" (exn-message e)))])
    (bytes->string/utf-8 (base64-decode (string->bytes/utf-8 str)))))

(define (base64url编码 str)
  (with-handlers ([exn:fail? (λ (e) (error "base64url编码错误: ~a" (exn-message e)))])
    (regexp-replace #px"=+$"
     (string-replace (string-replace
                      (string-trim (bytes->string/utf-8 (base64-encode (string->bytes/utf-8 str))))
                      "+" "-") "/" "_")
     "")))

(define (base64url解码 str)
  (with-handlers ([exn:fail? (λ (e) (error "base64url解码错误: ~a" (exn-message e)))])
    (define s (string-replace (string-replace (regexp-replace #px"=+$" str "")
                                              "-" "+") "_" "/"))
    (define pad (modulo (- 4 (modulo (string-length s) 4)) 4))
    (bytes->string/utf-8 (base64-decode (string->bytes/utf-8 (string-append s (make-string pad #\=)))))))