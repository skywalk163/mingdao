#lang racket/base

(provide 归约 偏函数 恒等 补集 组合
         列表转函数 函数管道 柯里化)

(define (归约 f lst [初始值 #f])
  (if 初始值
      (foldl f 初始值 lst)
      (if (null? lst)
          (error "归约需要至少一个元素")
          (foldl f (car lst) (cdr lst)))))

(define (偏函数 f . args)
  (λ more-args
    (apply f (append args more-args))))

(define (恒等 x) x)

(define (补集 f)
  (λ args
    (not (apply f args))))

(define (组合 . fns)
  (define fs (reverse fns))
  (λ args
    (let loop ([funcs fs] [val (apply (car fs) args)])
      (if (null? (cdr funcs))
          val
          (loop (cdr funcs) ((cadr funcs) val))))))

(define (列表转函数 lst)
  (λ (key)
    (cond
      [(hash? lst) (hash-ref lst key #f)]
      [(assoc key lst) => cdr]
      [else #f])))

(define (函数管道 . fns)
  (λ (arg)
    (for/fold ([val arg]) ([f (in-list fns)])
      (f val))))

(define (柯里化 f arity)
  (let loop ([args '()] [n 0])
    (λ more-args
      (let ([new-args (append args more-args)]
            [new-n (+ n (length more-args))])
        (if (>= new-n arity)
            (apply f new-args)
            (loop new-args new-n))))))