#lang racket/base

(require racket/hash
         racket/string
         (prefix-in parser: "../../lang/parser.rkt")
         (prefix-in tokenizer: "../../lang/tokenizer.rkt")
         (prefix-in error: "../../lang/error.rkt"))

(provide make-diagnostics
         diagnostics-compute)

;; 诊断状态
(struct diagnostics ())

;; 创建诊断器
(define (make-diagnostics)
  (diagnostics))

;; 计算诊断信息
(define (diagnostics-compute state text-sync uri)
  (define text (text-sync-get-text text-sync uri))
  (if text
      (collect-diagnostics text)
      '()))

;; 收集诊断信息
(define (collect-diagnostics text)
  (with-handlers ([exn:fail? (λ (e)
                              (list (make-error-diagnostic 0 0 (exn-message e))))])
    (define tokens (tokenizer:tokenize text))
    (define ast (parser:parse tokens))
    '()))

;; 创建错误诊断
(define (make-error-diagnostic line char message)
  (hash 'range (hash 'start (hash 'line line 'character char)
                      'end (hash 'line line 'character (+ char 1)))
         'severity 1
         'source "明道语言"
         'message message))

;; 创建警告诊断
(define (make-warning-diagnostic line char message)
  (hash 'range (hash 'start (hash 'line line 'character char)
                      'end (hash 'line line 'character (+ char 1)))
         'severity 2
         'source "明道语言"
         'message message))