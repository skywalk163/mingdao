#lang racket/base

(require net/http-client net/uri-codec json racket/string racket/hash racket/port)

(provide 调用模型 支持的模型)

(define *host* "open.bigmodel.cn")
(define *path* "/api/paas/v4/chat/completions")
(define *default-model* "glm-4")
(define *models* '("glm-4" "glm-4-flash" "glm-4-plus" "glm-3-turbo"))

(define (支持的模型)
  *models*)

(define (调用模型 api-key messages #:model [model *default-model*] #:temperature [temperature 0.7] #:max-tokens [max-tokens 2048])
  (with-handlers ([exn:fail? (lambda (e) (format "错误: ~a" (exn-message e)))])
    (define body
      (jsexpr->bytes
       (make-hash
        (list (cons "model" model)
              (cons "messages" (for/list ([m messages])
                                 (make-hash
                                  (list (cons "role" (hash-ref m 'role))
                                        (cons "content" (hash-ref m 'content))))))
              (cons "temperature" temperature)
              (cons "max_tokens" max-tokens)))))
    (define headers
      (list (format "Host: ~a" *host*)
            "Content-Type: application/json"
            (format "Authorization: Bearer ~a" api-key)))
    (define-values (status-line resp-headers in)
      (http-sendrecv *host* *path*
                     #:method "POST"
                     #:headers headers
                     #:data body
                     #:port 443
                     #:ssl? #t))
    (define resp-data (port->bytes in))
    (close-input-port in)
    (define resp (read-json (open-input-bytes resp-data)))
    (cond
      [(and (hash? resp) (hash-has-key? resp "choices"))
       (define choices (hash-ref resp "choices"))
       (if (and (list? choices) (not (null? choices)))
           (let* ([first-choice (car choices)]
                  [message (and (hash? first-choice) (hash-ref first-choice "message" (lambda () #f)))])
             (if (and (hash? message) (hash-has-key? message "content"))
                 (hash-ref message "content")
                 (format "错误: 响应格式异常: ~a" (bytes->string/utf-8 resp-data))))
           (format "错误: 无可用响应: ~a" (bytes->string/utf-8 resp-data)))]
      [else
       (format "错误: ~a" (bytes->string/utf-8 resp-data))])))

(module+ main
  (displayln "provider: glm")
  (displayln (format "支持的模型: ~a" (string-join (支持的模型) ", "))))
