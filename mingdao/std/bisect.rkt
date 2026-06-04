#lang racket/base
(require racket/list)

(provide 二分/左插入点 二分/右插入点 二分/插入左 二分/插入右
         二分/查找左 二分/查找右 二分/在范围内
         二分/左 二分/右
         二分/插入 二分/查找)

(define (二分/左插入点 lst item [lo 0] [hi #f])
  (define hi-val (or hi (length lst)))
  (let loop ([lo lo] [hi hi-val])
    (if (< lo hi)
        (let ([mid (quotient (+ lo hi) 2)])
          (if (< (list-ref lst mid) item)
              (loop (add1 mid) hi)
              (loop lo mid)))
        lo)))

(define (二分/右插入点 lst item [lo 0] [hi #f])
  (define hi-val (or hi (length lst)))
  (let loop ([lo lo] [hi hi-val])
    (if (< lo hi)
        (let ([mid (quotient (+ lo hi) 2)])
          (if (<= item (list-ref lst mid))
              (loop lo mid)
              (loop (add1 mid) hi)))
        lo)))

(define (二分/插入左 lst item [lo 0] [hi #f])
  (define pos (二分/左插入点 lst item lo hi))
  (append (take lst pos) (cons item (drop lst pos))))

(define (二分/插入右 lst item [lo 0] [hi #f])
  (define pos (二分/右插入点 lst item lo hi))
  (append (take lst pos) (cons item (drop lst pos))))

(define (二分/查找左 lst item [lo 0] [hi #f])
  (define pos (二分/左插入点 lst item lo hi))
  (if (and (< pos (length lst)) (equal? (list-ref lst pos) item))
      pos
      -1))

(define (二分/查找右 lst item [lo 0] [hi #f])
  (define pos (二分/右插入点 lst item lo hi))
  (if (and (> pos 0) (equal? (list-ref lst (sub1 pos)) item))
      (sub1 pos)
      -1))

(define (二分/在范围内 lst item [lo 0] [hi #f])
  (define pos (二分/左插入点 lst item lo hi))
  (and (< pos (length lst)) (equal? (list-ref lst pos) item)))

(define 二分/左 二分/左插入点)
(define 二分/右 二分/右插入点)
(define (二分/插入 lst item)
  (二分/插入左 lst item))
(define (二分/查找 lst item)
  (二分/查找左 lst item))