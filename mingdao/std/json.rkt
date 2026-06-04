#lang racket/base
(require json
         racket/port)

(provide json解析 json生成 json字符串转列表 列表转json字符串
         json/从文件读取 json/写入文件
         解析json 生成json json转列表 列表转json
         json读文件 json写文件
         读取json文件 写入json文件)

(define (json解析 input-str)
  (with-handlers ([exn:fail? (λ (e)
                               (error (format "JSON解析错误: ~a" (exn-message e))))])
    (string->jsexpr input-str)))

(define (json生成 value)
  (with-handlers ([exn:fail? (λ (e)
                               (error (format "JSON生成错误: ~a" (exn-message e))))])
    (jsexpr->string (转换json键 value))))

(define json字符串转列表 json解析)
(define 列表转json字符串 json生成)
(define 解析json json解析)
(define 生成json json生成)
(define json转列表 json字符串转列表)
(define 列表转json 列表转json字符串)

(define (json/从文件读取 path)
  (with-handlers ([exn:fail? (λ (e)
                               (error (format "JSON文件读取错误: ~a" (exn-message e))))])
    (define content (with-input-from-file path
                      (λ () (port->string))))
    (string->jsexpr content)))

(define (json/写入文件 value path)
  (with-handlers ([exn:fail? (λ (e)
                               (error (format "JSON文件写入错误: ~a" (exn-message e))))])
    (with-output-to-file path
      (λ () (display (jsexpr->string (转换json键 value))))
      #:exists 'replace)))

(define json读文件 json/从文件读取)
(define json写文件 json/写入文件)
(define 读取json文件 json/从文件读取)
(define 写入json文件 json/写入文件)

;; 将字符串键的hash转换为符号键（Racket JSON库需要符号键）
(define (转换json键 v)
  (cond [(hash? v)
         (define kvs
           (for/list ([(k val) (in-hash v)])
             (list (if (string? k) (string->symbol k) k)
                   (转换json键 val))))
         (apply hasheq (apply append kvs))]
        [(list? v) (map 转换json键 v)]
        [else v]))