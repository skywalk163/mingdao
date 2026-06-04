#lang racket/base
(require racket/port)
(require net/url)
(require net/http-client)
(require json)

(provide http/get http/post http/put http/delete http/head
         http/status-code http/headers http/body http/response
         http/make-request http/send-request)

(struct http/response (status-code headers body) #:transparent)

(define (make-headers alist)
  (for/list ([pair alist])
    (cons (car pair) (cdr pair))))

(define (http/make-request method url [headers '()] [body #f])
  (list method url headers body))

(define (http/send-request req)
  (define method (car req))
  (define url-str (cadr req))
  (define headers (caddr req))
  (define body (cadddr req))
  
  (with-handlers ([exn:fail? (λ (e) (error "HTTP请求失败: ~a" (exn-message e)))])
    (define url (string->url url-str))
    (define host (url-host url))
    (define port (or (url-port url) (if (equal? (url-scheme url) "https") 443 80)))
    (define path (url->path url))
    
    (define http-headers (make-headers headers))
    
    (define-values (status resp-headers resp-body)
      (http-sendrecv host path
                     #:port port
                     #:ssl? (equal? (url-scheme url) "https")
                     #:method method
                     #:headers http-headers
                     #:data body))
    
    (http/response status resp-headers (port->string resp-body))))

(define (http/get url [headers '()])
  (http/send-request (http/make-request "GET" url headers #f)))

(define (http/post url [headers '()] [body #f])
  (http/send-request (http/make-request "POST" url headers body)))

(define (http/put url [headers '()] [body #f])
  (http/send-request (http/make-request "PUT" url headers body)))

(define (http/delete url [headers '()])
  (http/send-request (http/make-request "DELETE" url headers #f)))

(define (http/head url [headers '()])
  (http/send-request (http/make-request "HEAD" url headers #f)))

(define (http/status-code resp)
  (http/response-status-code resp))

(define (http/headers resp)
  (http/response-headers resp))

(define (http/body resp)
  (http/response-body resp))