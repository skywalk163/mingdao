#lang racket/base

;; 异步协程模块
;; 包含 Future/Promise 实现和生成器支持

(require racket/async-channel
         racket/generator)

(provide ;; Future/Promise 相关
         未来 是未来? 创建未来 完成未来 绑定未来 异步 等待
         ;; 生成器相关
         generator yield 取第一个 转换列表 取前N个 生成器?)

;; ==================== 异步/协程 - Future/Promise实现 ====================

(struct 未来 (channel result done? mutex) #:mutable)

(define (是未来? obj)
  (未来? obj))

(define (创建未来)
  (未来 (make-async-channel) #f #f (make-semaphore 1)))

(define (完成未来 fut value)
  (call-with-semaphore (未来-mutex fut)
    (lambda ()
      (unless (未来-done? fut)
        (async-channel-put (未来-channel fut) value)
        (set-未来-result! fut value)
        (set-未来-done?! fut #t)))))

(define (绑定未来 fut callback)
  (thread
    (lambda ()
      (define result (async-channel-get (未来-channel fut)))
      (callback result))))

(define-syntax 异步
  (syntax-rules ()
    [(_ body ...)
     (let ([fut (创建未来)])
       (thread
         (lambda ()
           (define result (begin body ...))
           (完成未来 fut result)))
       fut)]))

(define (等待 fut)
  (if (未来-done? fut)
      (未来-result fut)
      (async-channel-get (未来-channel fut))))

;; ==================== 生成器相关函数 ====================

(define (取第一个 gen)
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (define v (gen))
    (if (void? v) #f v)))

(define (转换列表 gen)
  (let loop ()
    (with-handlers ([exn:fail? (lambda (e) '())])
      (define v (gen))
      (if (void? v)
          '()
          (cons v (loop))))))

(define (取前N个 n gen)
  (let loop ([i 0])
    (if (= i n)
        '()
        (with-handlers ([exn:fail? (lambda (e) '())])
          (let ([v (gen)])
            (if (void? v)
                '()
                (cons v (loop (add1 i)))))))))

(define (生成器? x)
  (procedure? x))