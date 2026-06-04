#lang racket/base

(require racket/port
         racket/string
         racket/match
         json)

(provide make-stdio-transport
         transport-read
         transport-write)

;; 传输层接口
(struct transport (read write))

;; 创建标准IO传输
(define (make-stdio-transport)
  (transport (λ () (read-message))
             (λ (msg) (write-message msg))))

;; 读取消息
(define (read-message)
  (with-handlers ([exn:fail? (λ (e) #f)])
    (define header-line (read-line (current-input-port)))
    (when (eof-object? header-line)
      (eof-object))
    (if (string-prefix? header-line "Content-Length: ")
        (let* ([length-str (string-trim (substring header-line (string-length "Content-Length: ")))]
               [content-length (string->number length-str)])
          (read-line (current-input-port)) ; 读取空行
          (define content (read-bytes content-length (current-input-port)))
          (when content
            (with-input-from-bytes content
              (λ () (read-json)))))
        (read-message))))

;; 写入消息
(define (write-message message)
  (define content (jsexpr->string message))
  (display (format "Content-Length: ~a\r\n\r\n" (string-length content)))
  (display content)
  (flush-output))