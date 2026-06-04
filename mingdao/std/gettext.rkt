#lang racket/base
(require racket/hash
         racket/string
         racket/list)

(provide 国际化/翻译 国际化/绑定文本域 国际化/文本域 国际化/语言 国际化/语言环境
         国际化/默认域 国际化/安装 国际化/翻译字符串 国际化/复数翻译 国际化/获取翻译
         国际化/空翻译)

(define *文本域表* (make-hash))
(define *当前域* (make-parameter "messages"))
(define *当前语言* (make-parameter "en"))
(define *当前语言环境* (make-parameter "en_US.UTF-8"))
(define *翻译表* (make-hash))
(define *复数翻译表* (make-hash))

(define (国际化/翻译 msgid [domain #f])
  (define dom (or domain (*当前域*)))
  (define lang (*当前语言*))
  (define key (format "~a:~a:~a" dom lang msgid))
  (hash-ref *翻译表* key msgid))

(define (国际化/绑定文本域 domain localedir)
  (hash-set! *文本域表* domain localedir)
  domain)

(define (国际化/文本域)
  (*当前域*))

(define (国际化/语言)
  (*当前语言*))

(define (国际化/语言环境)
  (*当前语言环境*))

(define (国际化/默认域)
  "messages")

(define (国际化/安装 lang [localedir #f])
  (*当前语言* lang)
  (when localedir
    (*当前语言环境* localedir)))

(define (国际化/翻译字符串 msgid)
  (国际化/翻译 msgid))

(define (国际化/复数翻译 msgid msgid_plural n)
  (define lang (*当前语言*))
  (define key (format "~a:~a:~a" (*当前域*) lang msgid))
  (define plural-forms (hash-ref *复数翻译表* key #f))
  (if plural-forms
      (if (= n 1) msgid msgid_plural)
      (if (= n 1) msgid msgid_plural)))

(define (国际化/获取翻译 msgid)
  (国际化/翻译 msgid))

(define (国际化/空翻译 msgid)
  msgid)