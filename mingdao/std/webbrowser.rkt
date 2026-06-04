#lang racket/base

(require racket/system racket/hash)

(provide
 浏览器/打开 浏览器/新标签 浏览器/新窗口
 浏览器/获取 浏览器/注册 浏览器/默认浏览器
 浏览器/打开URL 浏览器/可用浏览器列表)

(define BROWSER-REGISTRY (make-hash))

(define DEFAULT-BROWSER 'system)

(define (浏览器/注册 name proc)
  (hash-set! BROWSER-REGISTRY name proc))

(define (浏览器/获取 name)
  (hash-ref BROWSER-REGISTRY name (lambda () #f)))

(define (浏览器/可用浏览器列表)
  (hash-keys BROWSER-REGISTRY))

(define (浏览器/默认浏览器)
  DEFAULT-BROWSER)

(define (open-with-system url)
  (system (format "start ~a" url)))

(define (浏览器/打开 url #:browser [browser #f])
  (if browser
    (let ((proc (浏览器/获取 browser)))
      (if proc
        (proc url)
        (open-with-system url)))
    (open-with-system url)))

(define (浏览器/新标签 url #:browser [browser #f])
  (浏览器/打开 url #:browser browser))

(define (浏览器/新窗口 url #:browser [browser #f])
  (浏览器/打开 url #:browser browser))

(define (浏览器/打开URL url #:browser [browser #f])
  (浏览器/打开 url #:browser browser))

(浏览器/注册 "default" open-with-system)