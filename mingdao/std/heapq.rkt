#lang racket/base
(require racket/list)

(provide 堆/创建 堆/推入 堆/弹出 堆/查看 堆/大小 堆/为空
         堆/推入弹出 堆/替换 堆/合并 堆/排序
         堆/最大/创建 堆/最大/推入 堆/最大/弹出
         堆/归并 堆/最小堆化 堆/最大堆化
         堆/弹出全部)

(define (堆/创建)
  '())

(define (堆/推入 heap item)
  (define (siftup h k)
    (let loop ([h h] [k k])
      (if (zero? k)
          h
          (let ([parent (quotient (sub1 k) 2)])
            (if (< (list-ref h k) (list-ref h parent))
                (loop (list-set (list-set h k (list-ref h parent)) parent (list-ref h k)) parent)
                h)))))
  (siftup (append heap (list item)) (length heap)))

(define (堆/弹出 heap)
  (if (null? heap)
      (error "堆为空")
      (堆/弹出内部 heap)))

(define (堆/弹出内部 heap)
  (define (siftdown h k n)
    (let loop ([h h] [k k])
      (define smallest k)
      (define left (+ (* 2 k) 1))
      (define right (+ (* 2 k) 2))
      (define new-smallest
        (cond
          [(and (< left n) (< (list-ref h left) (list-ref h smallest))) left]
          [else smallest]))
      (define final-smallest
        (cond
          [(and (< right n) (< (list-ref h right) (list-ref h new-smallest))) right]
          [else new-smallest]))
      (if (not (= final-smallest k))
          (loop (list-set (list-set h k (list-ref h final-smallest)) final-smallest (list-ref h k)) final-smallest)
          h)))
  (define last (car (reverse heap)))
  (define rest-heap (reverse (cdr (reverse heap))))
  (if (null? rest-heap)
      (values last '())
      (values last (siftdown (list-set rest-heap 0 last) 0 (length rest-heap)))))

(define (堆/查看 heap)
  (if (null? heap)
      (error "堆为空")
      (car heap)))

(define (堆/大小 heap)
  (length heap))

(define (堆/为空 heap)
  (null? heap))

(define (堆/推入弹出 heap item)
  (if (null? heap)
      (values item (list item))
      (let ([smallest (car heap)])
        (if (< item smallest)
            (values item heap)
            (values smallest (堆/推入 (cdr heap) item))))))

(define (堆/替换 heap item)
  (if (null? heap)
      (error "堆为空")
      (let ([smallest (car heap)])
        (define (siftdown h k n)
          (let loop ([h h] [k k])
            (define smallest-idx k)
            (define left (+ (* 2 k) 1))
            (define right (+ (* 2 k) 2))
            (define new-smallest
              (cond
                [(and (< left n) (< (list-ref h left) (list-ref h smallest-idx))) left]
                [else smallest-idx]))
            (define final-smallest
              (cond
                [(and (< right n) (< (list-ref h right) (list-ref h new-smallest))) right]
                [else new-smallest]))
            (if (not (= final-smallest k))
                (loop (list-set (list-set h k (list-ref h final-smallest)) final-smallest (list-ref h k)) final-smallest)
                h)))
        (values smallest (siftdown (list-set heap 0 item) 0 (length heap))))))

(define (堆/合并 . heaps)
  (foldl (lambda (h1 h2)
           (for/fold ([acc (堆/创建)]) ([item h2])
             (堆/推入 acc item)))
         (car heaps) (cdr heaps)))

(define (堆/排序 lst)
  (define heap (for/fold ([h (堆/创建)]) ([item lst])
                 (堆/推入 h item)))
  (let loop ([h heap] [result '()])
    (if (堆/为空 h)
        (reverse result)
        (let-values ([(item rest) (堆/弹出 h)])
          (loop rest (cons item result))))))

(define (堆/最大/创建)
  '())

(define (堆/最大/推入 heap item)
  (堆/推入 heap (- item)))

(define (堆/最大/弹出 heap)
  (let-values ([(item rest) (堆/弹出 heap)])
    (values (- item) rest)))

(define (堆/归并 . sorted-lists)
  (define heap (堆/创建))
  (define iterators
    (for/list ([lst (in-list sorted-lists)] [i (in-naturals)])
      (if (null? lst)
          #f
          (cons (car lst) (cons i (cdr lst))))))
  (for ([it (in-list iterators)])
    (when it
      (set! heap (堆/推入 heap (cons (car it) it)))))
  (let loop ([h heap] [result '()])
    (if (堆/为空 h)
        (reverse result)
        (let-values ([(item rest) (堆/弹出 h)])
          (define it (cdr item))
          (define val (car item))
          (define new-h
            (if (null? (cddr it))
                rest
                (堆/推入 rest (cons (car (cddr it)) (cons (car it) (cdr (cddr it)))))))
          (loop new-h (cons val result))))))

(define (堆/最小堆化 lst)
  (for/fold ([h (堆/创建)]) ([item lst])
    (堆/推入 h item)))

(define (堆/最大堆化 lst)
  (for/fold ([h (堆/最大/创建)]) ([item lst])
    (堆/最大/推入 h item)))

(define (堆/弹出全部 heap)
  (let loop ([h heap] [result '()])
    (if (堆/为空 h)
        (reverse result)
        (let-values ([(item rest) (堆/弹出 h)])
          (loop rest (cons item result))))))