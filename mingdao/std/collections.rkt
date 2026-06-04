#lang racket/base
(require racket/list)

(provide 计数器/创建 计数器/最多 计数器/相加 计数器/相减
         双端队列/创建 双端队列/左追加 双端队列/右追加
         双端队列/左弹出 双端队列/右弹出
         双端队列/扩展 双端队列/左扩展 双端队列/旋转
         默认字典/创建 默认字典/获取
         有序字典/创建 有序字典/获取 有序字典/设置 有序字典/转为列表
         命名元组/创建 命名元组/新建
         链映射/创建 链映射/获取 链映射/新增)

;; ========== 计数器 (Counter) ==========

(define (计数器/创建 lst)
  (define ht (make-hash))
  (for ([elem (in-list lst)])
    (hash-set! ht elem (add1 (hash-ref ht elem 0))))
  ht)

(define (计数器/最多 counter [n #f])
  (define sorted (sort (hash->list counter) > #:key cdr))
  (if n
      (take sorted (min n (length sorted)))
      sorted))

(define (计数器/相加 c1 c2)
  (define keys (remove-duplicates (append (hash-keys c1) (hash-keys c2))))
  (for/hash ([k (in-list keys)])
    (values k (+ (hash-ref c1 k 0) (hash-ref c2 k 0)))))

(define (计数器/相减 c1 c2)
  (define keys (remove-duplicates (append (hash-keys c1) (hash-keys c2))))
  (for/hash ([k (in-list keys)])
    (values k (- (hash-ref c1 k 0) (hash-ref c2 k 0)))))

;; ========== 双端队列 (Deque) ==========

(define (双端队列/创建 . items)
  items)

(define (双端队列/左追加 dq item)
  (cons item dq))

(define (双端队列/右追加 dq item)
  (append dq (list item)))

(define (双端队列/左弹出 dq)
  (if (null? dq)
      (error "双端队列/左弹出: 队列为空")
      (values (cdr dq) (car dq))))

(define (双端队列/右弹出 dq)
  (if (null? dq)
      (error "双端队列/右弹出: 队列为空")
      (values (drop-right dq 1) (last dq))))

(define (双端队列/扩展 dq items)
  (append dq items))

(define (双端队列/左扩展 dq items)
  (append (reverse items) dq))

(define (双端队列/旋转 dq [n 1])
  (define len (length dq))
  (if (= len 0)
      dq
      (let ([k (modulo n len)])
        (if (= k 0)
            dq
            (let ([split (- len k)])
              (append (drop dq split) (take dq split)))))))

;; ========== 默认字典 (defaultdict) ==========

(define (默认字典/创建 fn)
  (cons fn (make-hash)))

(define (默认字典/获取 dd key)
  (hash-ref! (cdr dd) key (car dd)))

;; ========== 有序字典 (OrderedDict) ==========

(define (有序字典/创建)
  (list '() (hash)))

(define (有序字典/获取 od key [default #f])
  (hash-ref (cadr od) key default))

(define (有序字典/设置 od key val)
  (define keys (car od))
  (define ht (cadr od))
  (define new-keys (if (hash-has-key? ht key) keys (append keys (list key))))
  (define new-ht (hash-set ht key val))
  (list new-keys new-ht))

(define (有序字典/转为列表 od)
  (define keys (car od))
  (define ht (cadr od))
  (for/list ([k (in-list keys)])
    (cons k (hash-ref ht k))))

;; ========== 命名元组 (namedtuple) ==========

(define (命名元组/创建 name . fields)
  (λ vals
    (unless (= (length fields) (length vals))
      (error (format "~a: 需要 ~a 个字段，得到 ~a 个" name (length fields) (length vals))))
    (for/hash ([f fields] [v vals])
      (values f v))))

(define (命名元组/新建 type . vals)
  (apply type vals))

;; ========== 链映射 (ChainMap) ==========

(define (链映射/创建 . maps)
  maps)

(define (链映射/获取 cm key [default #f])
  (let loop ([maps cm])
    (cond
      [(null? maps) default]
      [(hash-has-key? (car maps) key) (hash-ref (car maps) key)]
      [else (loop (cdr maps))])))

(define (链映射/新增 cm m)
  (cons m cm))