#lang racket/base

(require racket/string
         racket/hash)

(provide make-debugger
         debugger-break
         debugger-continue
         debugger-step
         debugger-next
         debugger-get-variables
         debugger-get-stack
         debugger-set-variable!)

;; 调试器状态
(struct debugger (state breakpoints variables stack current-line) #:mutable)

;; 创建调试器
(define (make-debugger)
  (debugger 'idle (make-hash) (make-hash) '() 0))

;; 设置断点
(define (debugger-break dbg line)
  (hash-set! (debugger-breakpoints dbg) line #t)
  (printf "断点设置在第 ~a 行\n" line))

;; 继续执行
(define (debugger-continue dbg)
  (set-debugger-state! dbg 'running)
  (printf "继续执行\n"))

;; 单步执行
(define (debugger-step dbg)
  (set-debugger-state! dbg 'stepping)
  (printf "单步执行\n"))

;; 下一步
(define (debugger-next dbg)
  (set-debugger-state! dbg 'next)
  (printf "下一步\n"))

;; 获取变量
(define (debugger-get-variables dbg)
  (hash->list (debugger-variables dbg)))

;; 获取堆栈
(define (debugger-get-stack dbg)
  (debugger-stack dbg))

;; 设置变量
(define (debugger-set-variable! dbg name value)
  (hash-set! (debugger-variables dbg) name value)
  (printf "变量 ~a = ~a\n" name value))
