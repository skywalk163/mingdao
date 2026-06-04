#lang racket/base
(require racket/list
         racket/generator)

(provide 无限计数 循环 重复 累加 链 压缩 丢弃 保留
         滤除 分组 星映射 迭代切片 配对 跨越
         积 排列 元素组合 组合替换
         无限 无限计数器 拉链最长 拉链填充)

(define (无限计数 [start 0] [step 1])
  (generator ()
    (let loop ([n start])
      (yield n)
      (loop (+ n step)))))

(define (循环 lst)
  (generator ()
    (let loop ()
      (for ([elem (in-list lst)])
        (yield elem))
      (loop))))

(define (重复 elem [n #f])
  (if n
      (make-list n elem)
      (generator ()
        (let loop ()
          (yield elem)
          (loop)))))

(define (累加 lst)
  (let loop ([lst lst] [sum 0] [acc '()])
    (if (null? lst)
        (reverse acc)
        (let ([new-sum (+ sum (car lst))])
          (loop (cdr lst) new-sum (cons new-sum acc))))))

(define (链 . lsts)
  (apply append lsts))

(define (压缩 lst selectors)
  (for/list ([x (in-list lst)] [s (in-list selectors)] #:when s)
    x))

(define (丢弃 pred lst)
  (dropf lst pred))

(define (保留 pred lst)
  (takef lst pred))

(define (滤除 pred lst)
  (filter (λ (x) (not (pred x))) lst))

(define (分组 lst [keyfn values])
  (if (null? lst)
      '()
      (let loop ([lst (cdr lst)]
                 [key (keyfn (car lst))]
                 [group (list (car lst))]
                 [acc '()])
        (if (null? lst)
            (reverse (cons (list key (reverse group)) acc))
            (let ([new-key (keyfn (car lst))])
              (if (equal? new-key key)
                  (loop (cdr lst) key (cons (car lst) group) acc)
                  (loop (cdr lst) new-key (list (car lst)) (cons (list key (reverse group)) acc))))))))

(define (星映射 fn lst)
  (for/list ([args (in-list lst)])
    (apply fn args)))

(define (迭代切片 lst start [stop #f] [step 1])
  (define dropped (drop lst start))
  (for/list ([x (in-list dropped)]
             [i (in-naturals)]
             #:break (and stop (>= i (- stop start)))
             #:when (= (modulo i step) 0))
    x))

(define (配对 lst)
  (if (null? lst)
      '()
      (for/list ([a (in-list lst)] [b (in-list (cdr lst))])
        (list a b))))

(define (跨越 lst1 lst2 [fill #f])
  (define len1 (length lst1))
  (define len2 (length lst2))
  (define max-len (max len1 len2))
  (define extended1 (append lst1 (make-list (- max-len len1) fill)))
  (define extended2 (append lst2 (make-list (- max-len len2) fill)))
  (map list extended1 extended2))

(define (积 lst [repeat 1])
  (cartesian-product (make-list repeat lst)))

(define (排列 lst [r (length lst)])
  (if (= r (length lst))
      (permutations lst)
      (apply append
             (for/list ([c (in-list (combinations lst r))])
               (permutations c)))))

(define (元素组合 lst r)
  (combinations lst r))

(define (组合替换 lst r)
  (cond
    [(= r 0) '(())]
    [(null? lst) '()]
    [else (append (map (λ (x) (cons (car lst) x))
                       (组合替换 lst (- r 1)))
                  (组合替换 (cdr lst) r))]))

(define 无限 无限计数)
(define 无限计数器 无限计数)
(define 拉链最长 跨越)
(define 拉链填充 跨越)