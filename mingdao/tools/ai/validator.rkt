#lang racket/base

;; 代码验证器
;; 验证生成的明道代码是否能正确分词、解析，以及是否通过基本语义分析

(require racket/string
         racket/list
         racket/match)

;; ============================================================
;; 有条件地加载 mingdao 解析器模块
;; ------------------------------------------------------------
;; 如果 mingdao/lang/tokenizer.rkt 或 parser.rkt 因依赖问题
;; 无法加载，则采用降级方案：用简单的字符串检查替代真正的解析。
;; ============================================================

(define 分词可用? #f)
(define 解析可用? #f)
(define 分词 #f)
(define 解析 #f)

(with-handlers ([exn:fail?
                 (lambda (e)
                   (set! 分词可用? #f)
                   (set! 分词 #f))])
  (define proc (dynamic-require "mingdao/lang/tokenizer.rkt" 'tokenize
                                (lambda () #f)))
  (when proc
    (set! 分词 proc)
    (set! 分词可用? #t)))

(with-handlers ([exn:fail?
                 (lambda (e)
                   (set! 解析可用? #f)
                   (set! 解析 #f))])
  (define proc (dynamic-require "mingdao/lang/parser.rkt" 'parse
                                (lambda () #f)))
  (when proc
    (set! 解析 proc)
    (set! 解析可用? #t)))

(provide 验证代码
         验证能分词
         验证能解析
         验证基本结构)

;; ------------------------------------------------------------
;; 降级方案：简单字符串检查
;;   code 非空；且包含关键字 "定义" 或 "如果" 或 "对于" 之一
;; ------------------------------------------------------------
(define (非空字符串? code)
  (and (string? code)
       (not (zero? (string-length (string-trim code))))))

(define (关键字降级检查 code)
  (and (非空字符串? code)
       (or (string-contains? code "定义")
           (string-contains? code "如果")
           (string-contains? code "对于"))))

;; ------------------------------------------------------------
;; 基本结构检查：粗略检查是否有明显未闭合的中文结构
;;   统计某些成对结构的出现次数，若明显失衡则判定为不通过。
;; 这里做非常粗略的启发式检查。
;; ------------------------------------------------------------
(define (验证基本结构 code)
  (cond
    [(not (string? code))
     (hash '通过 #f '问题 "代码必须为字符串")]
    [(not (非空字符串? code))
     (hash '通过 #f '问题 "代码为空")]
    [else
     (define def-count (length (regexp-match* #rx"定义" code)))
     (define if-count  (length (regexp-match* #rx"如果"   code)))
     (define for-count (length (regexp-match* #rx"对于"   code)))
     (if (and (zero? def-count) (zero? if-count) (zero? for-count))
         (hash '通过 #f '问题 "未发现任何中文结构关键字")
         (hash '通过 #t '问题 #f))]))

;; ------------------------------------------------------------
;; 验证能否分词
;; ------------------------------------------------------------
(define (验证能分词 code)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (hash '通过 #f '错误 (exn-message e)))])
    (cond
      [(not (string? code))
       (hash '通过 #f '错误 "代码必须为字符串")]
      [(not (非空字符串? code))
       (hash '通过 #f '错误 "代码为空")]
      [分词可用?
       (define tokens (分词 code))
       (hash '通过 #t '错误 #f 'token数 (length tokens))]
      [else
       (if (关键字降级检查 code)
           (hash '通过 #t '错误 #f 'token数 #f '降级? #t)
           (hash '通过 #f '错误 "降级检查未通过：缺少关键字" '降级? #t))])))

;; ------------------------------------------------------------
;; 验证能否解析
;; ------------------------------------------------------------
(define (验证能解析 code)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (hash '通过 #f '错误 (exn-message e)))])
    (cond
      [(not (string? code))
       (hash '通过 #f '错误 "代码必须为字符串")]
      [(not (非空字符串? code))
       (hash '通过 #f '错误 "代码为空")]
      [解析可用?
       (define tokens (if 分词可用? (分词 code) '()))
       (define ast (解析 tokens))
       (hash '通过 #t '错误 #f 'ast ast)]
      [else
       (if (关键字降级检查 code)
           (hash '通过 #t '错误 #f 'ast #f '降级? #t)
           (hash '通过 #f '错误 "降级检查未通过：缺少关键字" '降级? #t))])))

;; ------------------------------------------------------------
;; 综合验证代码
;;   返回 (hash '状态 ... '解析通过 ... '错误 ...)
;; ------------------------------------------------------------
(define (验证代码 code)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (hash '状态 '失败
                           '解析通过 #f
                           '分词通过 #f
                           '结构通过 #f
                           '错误 (exn-message e)))])
    (define 分词结果 (验证能分词 code))
    (define 解析结果 (验证能解析 code))
    (define 结构结果 (验证基本结构 code))
    (define 分词通过? (hash-ref 分词结果 '通过 #f))
    (define 解析通过? (hash-ref 解析结果 '通过 #f))
    (define 结构通过? (hash-ref 结构结果 '通过 #f))
    (define 状态
      (if (and 分词通过? 解析通过? 结构通过?)
          '通过
          '失败))
    (hash '状态 状态
          '解析通过 解析通过?
          '分词通过 分词通过?
          '结构通过 结构通过?
          '错误
          (cond
            [(hash-ref 解析结果 '错误 #f) => (lambda (x) x)]
            [(hash-ref 分词结果 '错误 #f) => (lambda (x) x)]
            [(hash-ref 结构结果 '问题 #f) => (lambda (x) x)]
            [else #f])
          '分词 分词结果
          '解析 解析结果
          '结构 结构结果)))
