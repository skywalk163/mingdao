#lang racket/base
(require racket/port racket/file)

(provide 序列化/转字节 序列化/转字符串 序列化/加载字节 序列化/加载字符串
         序列化/转文件 序列化/加载文件 序列化/协议 序列化/最高协议
         序列化/支持类型列表)

(define (序列化/转字节 obj)
  (with-handlers ([exn:fail? (λ (e) (error "序列化失败: ~a" (exn-message e)))])
    (let ([p (open-output-bytes)])
      (write obj p)
      (get-output-bytes p))))

(define (序列化/转字符串 obj)
  (with-handlers ([exn:fail? (λ (e) (error "序列化字符串失败: ~a" (exn-message e)))])
    (let ([p (open-output-string)])
      (write obj p)
      (get-output-string p))))

(define (序列化/加载字节 bs)
  (with-handlers ([exn:fail? (λ (e) (error "反序列化失败: ~a" (exn-message e)))])
    (let ([p (open-input-bytes bs)])
      (read p))))

(define (序列化/加载字符串 str)
  (with-handlers ([exn:fail? (λ (e) (error "反序列化字符串失败: ~a" (exn-message e)))])
    (let ([p (open-input-string str)])
      (read p))))

(define (序列化/转文件 obj path)
  (with-handlers ([exn:fail? (λ (e) (error "序列化写入文件失败: ~a" (exn-message e)))])
    (call-with-output-file path
      (λ (out) (write obj out))
      #:exists 'replace)))

(define (序列化/加载文件 path)
  (with-handlers ([exn:fail? (λ (e) (error "反序列化读取文件失败: ~a" (exn-message e)))])
    (call-with-input-file path
      (λ (in) (read in)))))

(define 序列化/协议 0)
(define 序列化/最高协议 0)

(define (序列化/支持类型列表)
  '(#t #f null
    integer? rational? real? complex? number?
    string? char? symbol? bytes?
    pair? list? vector? hash?
    exact? inexact? boolean? void?))