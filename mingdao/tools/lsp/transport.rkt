#lang racket/base

(require racket/port
         racket/string
         racket/match
         json)

(provide make-stdio-transport
         transport-read
         transport-write)

;; 传输层接口 — 使用 reader/writer 避免与包装函数名冲突
(struct transport (reader writer))

;; 创建标准IO传输
(define (make-stdio-transport)
  (transport read-message write-message))

;; 包装函数：读消息
(define (transport-read tr)
  ((transport-reader tr)))

;; 包装函数：写消息
(define (transport-write tr msg)
  ((transport-writer tr) msg))

;; 读取消息（JSON-RPC 的 Content-Length 协议）
(define (read-message)
  (with-handlers ([exn:fail? (λ (e) #f)])
    (define header-line (read-line (current-input-port)))
    (when (eof-object? header-line)
      eof)
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