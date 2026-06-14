#lang racket/base

(require racket/hash
         racket/string
         racket/match)

(provide make-text-sync
         text-sync-open
         text-sync-change
         text-sync-close
         text-sync-get-text
         text-sync-get-uri)

;; 文本同步状态
(struct text-sync (documents))

;; 创建文本同步
(define (make-text-sync)
  (text-sync (make-hash)))

;; 打开文档
(define (text-sync-open state uri text)
  (hash-set! (text-sync-documents state) uri text))

;; 变更文档
(define (text-sync-change state uri changes)
  (define doc (hash-ref (text-sync-documents state) uri #f))
  (when doc
    (define new-text (apply-changes doc changes))
    (hash-set! (text-sync-documents state) uri new-text)))

;; 关闭文档
(define (text-sync-close state uri)
  (hash-remove! (text-sync-documents state) uri))

;; 获取文档文本
(define (text-sync-get-text state uri)
  (hash-ref (text-sync-documents state) uri #f))

;; 获取所有URI
(define (text-sync-get-uri state)
  (hash-keys (text-sync-documents state)))

;; 应用变更
(define (apply-changes original-text changes)
  (for/fold ([current-text original-text])
            ([change changes])
    (match change
      [(hash-table ('range range) ('text new-text))
       (replace-range current-text range new-text)]
      [(hash-table ('text new-text))
       new-text])))

;; 替换范围
(define (replace-range text range new-text)
  (define start (hash-ref range 'start))
  (define end (hash-ref range 'end))
  (define lines (string-split text "\n" #:trim? #f))
  (define start-line (hash-ref start 'line))
  (define start-char (hash-ref start 'character))
  (define end-line (hash-ref end 'line))
  (define end-char (hash-ref end 'character))
  
  ;; 这里简化实现，实际需要精确处理行列位置
  (string-join (for/list ([line lines]
                          [i (in-naturals)])
                 (if (and (<= start-line i end-line))
                     (if (= i start-line)
                         (string-append (substring line 0 (min start-char (string-length line)))
                                      new-text)
                         "")
                     line))
               "\n"))