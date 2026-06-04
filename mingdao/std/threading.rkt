#lang racket/base
(require racket/place)

(provide 线程/创建 线程/当前 线程/等待 线程/睡眠
         线程/锁 线程/获得锁 线程/释放锁
         线程/事件 线程/设置事件 线程/等待事件 线程/清除事件
         线程/信号量 线程/信号量等待 线程/信号量发布
         线程/定时器 线程/屏障
         ;; 新增功能
         线程/池 创建线程池 线程池/提交 线程池/关闭 线程池/等待
         线程/并行映射 线程/并行for 线程/异步执行
         线程/原子加 线程/原子减 线程/原子比较交换
         线程/本地存储 线程/获取本地值 线程/设置本地值
         线程/取消 线程/是否取消)

;; 使用 racket/base 提供的线程基本操作
(define (线程/创建 thunk)
  (thread thunk))

(define (线程/当前)
  (current-thread))

(define (线程/等待 t)
  (thread-wait t))

(define (线程/睡眠 sec)
  (sleep sec))

;; 互斥锁 —— 使用二元信号量实现（Racket CS 无 make-mutex）
(struct 锁 (sem) #:transparent)
(define (线程/锁)
  (锁 (make-semaphore 1)))

(define (线程/获得锁 m)
  (semaphore-wait (锁-sem m)))

(define (线程/释放锁 m)
  (semaphore-post (锁-sem m)))

;; 事件对象
(struct 事件 (sem) #:transparent)
(define (线程/事件)
  (事件 (make-semaphore 0)))

(define (线程/设置事件 evt)
  (semaphore-post (事件-sem evt)))

(define (线程/等待事件 evt)
  (semaphore-wait (事件-sem evt)))

(define (线程/清除事件 evt)
  ;; 清空信号量中所有已发布的许可
  (let loop ()
    (when (semaphore-try-wait? (事件-sem evt))
      (loop))))

;; 信号量
(define (线程/信号量 initial-count)
  (make-semaphore (or initial-count 1)))

(define (线程/信号量等待 sem)
  (semaphore-wait sem))

(define (线程/信号量发布 sem)
  (semaphore-post sem))

;; 定时器 —— 返回一个线程，到期后执行 thunk
(define (线程/定时器 sec thunk)
  (thread (λ ()
            (sleep sec)
            (thunk))))

;; 屏障 —— 使用信号量实现
(define (线程/屏障 n)
  (let ([count 0]
        [mutex-sem (make-semaphore 1)]
        [barrier-sem (make-semaphore 0)])
    (λ ()
      ;; 原子递增计数器
      (semaphore-wait mutex-sem)
      (set! count (+ count 1))
      (define reached count)
      (semaphore-post mutex-sem)
      (if (= reached n)
          ;; 最后一个线程到达：允许 n-1 个线程通过
          (let loop ()
            (when (semaphore-try-wait? barrier-sem)
              (loop))
            ;; 已清空 barrier-sem，现在发布 n-1 次
            (let loop2 ([i 1])
              (when (< i n)
                (semaphore-post barrier-sem)
                (loop2 (+ i 1)))))
          ;; 非最后一个线程：等待
          (semaphore-wait barrier-sem)))))

;; ============================================================
;; 增强功能
;; ============================================================

(struct 线程池 (tasks threads mutex shutdown?) #:mutable)

(define (创建线程池 [size 4])
  (define tasks (make-channel))
  (define mutex (make-semaphore 1))
  (define shutdown? #f)

  (define (worker)
    (let loop ()
      (define task (channel-get tasks))
      (if (eq? task 'shutdown)
          (void)
          (begin
            (with-handlers ([exn:fail? (λ (e) (void))])
              (task))
            (loop)))))

  (define threads
    (for/list ([i (in-range size)])
      (thread worker)))

  (线程池 tasks threads mutex #f))

(define (线程池/提交 pool task)
  (channel-put (线程池-tasks pool) task))

(define (线程池/等待 pool)
  (for-each thread-wait (线程池-threads pool)))

(define (线程池/关闭 pool)
  (for ([t (线程池-threads pool)])
    (channel-put (线程池-tasks pool) 'shutdown)))

(define 线程/池 创建线程池)

(define (线程/并行映射 func lst)
  (define results (make-channel))
  (define threads
    (for/list ([item lst])
      (thread (λ ()
                (channel-put results (cons item (func item)))))))
  (for-each thread-wait threads)
  (for/list ([i (in-range (length lst))])
    (cdr (channel-get results))))

(define (线程/并行for lst func)
  (define threads
    (for/list ([item lst])
      (thread (λ () (func item)))))
  (for-each thread-wait threads))

(define (线程/异步执行 thunk)
  (thread thunk))

(define (线程/原子加 var delta)
  (set-box! var (+ (unbox var) delta)))

(define (线程/原子减 var delta)
  (set-box! var (- (unbox var) delta)))

(define (线程/原子比较交换 var old new)
  (define current (unbox var))
  (if (equal? current old)
      (begin (set-box! var new) #t)
      #f))

(define *线程本地存储* (make-parameter (make-hash)))

(define (线程/本地存储)
  (unless (*线程本地存储*)
    (*线程本地存储* (make-hash)))
  (*线程本地存储*))

(define (线程/设置本地值 key value)
  (hash-set! (*线程本地存储*) key value))

(define (线程/获取本地值 key [default #f])
  (hash-ref (*线程本地存储*) key default))

(define (线程/取消 t)
  (kill-thread t))

(define (线程/是否取消 t)
  (not (thread-running? t)))