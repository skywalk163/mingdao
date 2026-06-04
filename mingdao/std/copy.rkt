#lang racket/base
(require racket/list)

(provide 浅拷贝 深拷贝 复制列表 复制哈希)

(define (浅拷贝 obj)
  (cond
    [(list? obj) (复制列表 obj)]
    [(hash? obj) (复制哈希 obj)]
    [(vector? obj) (for/vector ([e (in-vector obj)]) e)]
    [else obj]))

(define (深拷贝 obj)
  (cond
    [(list? obj) (map 深拷贝 obj)]
    [(hash? obj)
     (for/hash ([(k v) (in-hash obj)])
       (values (深拷贝 k) (深拷贝 v)))]
    [(vector? obj)
     (list->vector (map 深拷贝 (vector->list obj)))]
    [else obj]))

(define (复制列表 lst)
  (if (list? lst)
      (take lst (length lst))
      (error "复制列表: 参数不是列表")))

(define (复制哈希 h)
  (if (hash? h)
      (for/hash ([(k v) (in-hash h)])
        (values k v))
      (error "复制哈希: 参数不是哈希表")))