#lang racket/base

(require racket/hash
         racket/string
         "text-sync.rkt"
         (prefix-in parser: "../../lang/parser.rkt")
         (prefix-in tokenizer: "../../lang/tokenizer.rkt")
         (prefix-in typechecker: "../../lang/type-checker.rkt"))

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

;; 收集诊断信息 — 分词 → 解析 → 类型检查
(define (collect-diagnostics text)
  (let/ec return
    (define diagnostics '())
    
    ;; 收集诊断的辅助函数
    (define (add-diagnostic line char severity msg)
      (define range
        (hash 'start (hash 'line line 'character (max 0 (sub1 char)))
              'end (hash 'line line 'character (+ char 1))))
      (set! diagnostics
            (cons (hash 'range range
                        'severity severity
                        'source "明道语言"
                        'message msg)
                  diagnostics)))
    
    ;; 1. 分词阶段
    (define tokens
      (with-handlers ([exn:fail? (λ (e)
                                   (define msg (exn-message e))
                                   (cond
                                     [(regexp-match #rx"第 (\\d+) 行，第 (\\d+) 列" msg)
                                      => (λ (m)
                                           (define line (string->number (cadr m)))
                                           (define col (string->number (caddr m)))
                                           (add-diagnostic (sub1 line) (sub1 col) 1 msg))]
                                     [else
                                      (add-diagnostic 0 0 1 msg)])
                                   '())])
        (tokenizer:tokenize text)))
    (when (null? tokens)
      (return (reverse diagnostics)))
    
    ;; 2. 解析阶段
    (define ast
      (with-handlers ([exn:fail? (λ (e)
                                   (add-diagnostic 0 0 1 (exn-message e))
                                   #f)])
        (parser:parse tokens)))
    
    (unless ast
      (return (reverse diagnostics)))
    
    ;; 3. 类型检查阶段（警告级别，不阻断）
    (with-handlers ([exn:fail? (λ (e) (void))])
      (typechecker:check-types ast #hasheq() #hasheq()
                               (λ (msg) (add-diagnostic 0 0 2 msg))))
    
    (reverse diagnostics)))