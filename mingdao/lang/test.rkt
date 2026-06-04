#lang racket/base

(require racket/list
         racket/string
         racket/format
         racket/match)

(provide 测试
         测试组
         断言测试
         断言相等
         断言不等
         断言异常
         运行测试
         测试结果?
         测试结果-总数
         测试结果-通过
         测试结果-失败
         测试结果-详情)

;; ============================================================
;; 测试状态
;; ============================================================

(define 测试总数 0)
(define 通过数 0)
(define 失败数 0)
(define 失败详情 '())

(struct 测试结果 (总数 通过 失败 详情) #:transparent)

;; ============================================================
;; 断言宏（用于测试中）
;; ============================================================

(define (raise-exn msg)
  (raise (exn:fail msg (current-continuation-marks))))

(define (断言测试 条件 [消息 ""])
  (unless 条件
    (raise-exn (format "断言失败：~a" (if (string=? 消息 "") 条件 消息))))
  #t)

(define (断言相等 期望值 实际值 [消息 ""])
  (unless (equal? 期望值 实际值)
    (define 附加消息 (if (string=? 消息 "") "" (format " (~a)" 消息)))
    (raise-exn (format "断言失败：期望 ~a，实际 ~a~a" 期望值 实际值 附加消息)))
  #t)

(define (断言不等 期望值 实际值 [消息 ""])
  (when (equal? 期望值 实际值)
    (define 附加消息 (if (string=? 消息 "") "" (format " (~a)" 消息)))
    (raise-exn (format "断言失败：不应等于 ~a~a" 期望值 附加消息)))
  #t)

(define (断言异常 异常类型 函数 参数)
  (define 成功?
    (with-handlers ([exn:fail? (λ (e) #t)])
      (apply 函数 参数)
      #f))
  (unless 成功?
    (raise-exn (format "断言失败：未抛出异常 ~a" 异常类型)))
  #t)

;; ============================================================
;; 测试用例
;; ============================================================

(define (测试 名称 测试表达式)
  (set! 测试总数 (add1 测试总数))
  (printf "  🧪 测试: ~a ... " 名称)
  (flush-output)
  (define 结果
    (with-handlers ([exn:fail?
                     (λ (e)
                       (set! 失败数 (add1 失败数))
                       (set! 失败详情 (cons (list 名称 (exn-message e)) 失败详情))
                       (printf "✗ 失败\n")
                       (printf "    错误: ~a\n" (exn-message e))
                       (flush-output)
                       #f)])
      (测试表达式)
      (set! 通过数 (add1 通过数))
      (printf "✓ 通过\n")
      (flush-output)
      #t))
  结果)

;; ============================================================
;; 测试组
;; ============================================================

(define (测试组 组名 . 测试列表)
  (printf "\n═══════════════════════════════════════\n")
  (printf "  📋 测试组: ~a\n" 组名)
  (printf "═══════════════════════════════════════\n")
  (for ([测试项 测试列表])
    (测试项))
  (printf "───────────────────────────────────────\n")
  (flush-output))

;; ============================================================
;; 运行测试（报告汇总）
;; ============================================================

(define (运行测试)
  (printf "\n")
  (printf "╔══════════════════════════════════════╗\n")
  (printf "║        明道测试报告                    ║\n")
  (printf "╚══════════════════════════════════════╝\n")
  (printf "\n")
  (printf "  测试总数: ~a\n" 测试总数)
  (printf "  通过:     ~a\n" 通过数)
  (printf "  失败:     ~a\n" 失败数)
  (when (> 失败数 0)
    (printf "\n")
    (printf "  ⚠ 失败的测试:\n")
    (for ([失败 (reverse 失败详情)])
      (printf "    • ~a\n" (car 失败))
      (printf "      ~a\n" (cadr 失败))))
  (printf "\n")
  (define 结果 (测试结果 测试总数 通过数 失败数 (reverse 失败详情)))
  (set! 测试总数 0)
  (set! 通过数 0)
  (set! 失败数 0)
  (set! 失败详情 '())
  (printf "\n")
  (flush-output)
  结果)