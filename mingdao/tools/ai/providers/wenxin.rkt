#lang racket/base

(require net/http-client
         net/uri-codec
         json
         racket/string
         racket/hash
         racket/port)

(provide 调用模型 支持的模型)

(define host "qianfan.baidubce.com")
(define path "/v2/chat/completions")
(define default-model "ernie-4.0")
(define models '("ernie-4.0" "ernie-3.5"))

(define (支持的模型)
  models)

(define (调用模型 api-key messages
                 #:model [model default-model]
                 #:temperature [temperature 0.7]
                 #:max-tokens [max-tokens 2048])
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (string-append "错误: " (exn-message e)))])
    (define body-json
      (make-hash (list (cons "model" model)
                       (cons "messages" messages)
                       (cons "temperature" temperature)
                       (cons "max_tokens" max-tokens))))
    (define body (jsexpr->bytes body-json))
    (define headers
      (list (string-append "Content-Type: application/json")
            (string-append "Authorization: Bearer " api-key)))
    (define-values (status resp-headers in)
      (http-sendrecv host path
                     #:ssl? #t
                     #:port 443
                     #:method "POST"
                     #:headers headers
                     #:data body))
    (define response-json (read-json in))
    (close-input-port in)
    (cond
      [(hash? response-json)
       (define choices (hash-ref response-json "choices" (lambda () '())))
       (if (and (list? choices) (not (null? choices)))
           (let* ([first-choice (list-ref choices 0)]
                  [msg (hash-ref first-choice "message" (lambda () #f))]
                  [content (and (hash? msg)
                                (hash-ref msg "content" (lambda () "")))])
             (or content ""))
           (let ([err (hash-ref response-json "error" (lambda () #f))])
             (if err
                 (string-append "错误: " (jsexpr->string err))
                 "错误: 无响应内容")))]
      [else
       (string-append "错误: 响应格式异常 - " (jsexpr->string response-json))])))

(module+ main
  (writeln (list 'wenxin '支持的模型: (支持的模型))))
