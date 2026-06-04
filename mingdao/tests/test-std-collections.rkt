#lang racket
;; 明道标准库测试 - Collections 模块
(require "../std/collections.rkt"
         "../lang/test.rkt")

(测试组 "Collections - Counter"
  (λ ()
    (测试 "计数器/创建 - 基本"
      (λ ()
        (define c (计数器/创建 '(a b a c a b)))
        (断言相等 3 (hash-ref c 'a))
        (断言相等 2 (hash-ref c 'b))
        (断言相等 1 (hash-ref c 'c)))))

  (λ ()
    (测试 "计数器/最多"
      (λ ()
        (define c (计数器/创建 '(a b a c a b)))
        (define top (计数器/最多 c))
        (断言相等 'a (caar top)))))

  (λ ()
    (测试 "计数器/最多 N=2"
      (λ ()
        (define c (计数器/创建 '(a b a c a b)))
        (define top2 (计数器/最多 c 2))
        (断言相等 2 (length top2)))))

  (λ ()
    (测试 "计数器/相加"
      (λ ()
        (define c1 (计数器/创建 '(a b a)))
        (define c2 (计数器/创建 '(a b b)))
        (define sum (计数器/相加 c1 c2))
        (断言相等 3 (hash-ref sum 'a))
        (断言相等 3 (hash-ref sum 'b)))))

  (λ ()
    (测试 "计数器/相减"
      (λ ()
        (define c1 (计数器/创建 '(a a a b)))
        (define c2 (计数器/创建 '(a b)))
        (define diff (计数器/相减 c1 c2))
        (断言相等 2 (hash-ref diff 'a))
        (断言相等 0 (hash-ref diff 'b)))))
)

(测试组 "Collections - Deque"
  (λ ()
    (测试 "双端队列/创建"
      (λ ()
        (define dq (双端队列/创建 1 2 3))
        (断言相等 '(1 2 3) dq))))

  (λ ()
    (测试 "双端队列/左追加"
      (λ ()
        (define dq (双端队列/创建 2 3))
        (define result (双端队列/左追加 dq 1))
        (断言相等 '(1 2 3) result))))

  (λ ()
    (测试 "双端队列/右追加"
      (λ ()
        (define dq (双端队列/创建 1 2))
        (define result (双端队列/右追加 dq 3))
        (断言相等 '(1 2 3) result))))

  (λ ()
    (测试 "双端队列/左弹出"
      (λ ()
        (define dq (双端队列/创建 1 2 3))
        (define-values (new-dq val) (双端队列/左弹出 dq))
        (断言相等 1 val)
        (断言相等 '(2 3) new-dq))))

  (λ ()
    (测试 "双端队列/右弹出"
      (λ ()
        (define dq (双端队列/创建 1 2 3))
        (define-values (new-dq val) (双端队列/右弹出 dq))
        (断言相等 3 val)
        (断言相等 '(1 2) new-dq))))

  (λ ()
    (测试 "双端队列/左弹出 - 空队列异常"
      (λ ()
        (断言异常 exn:fail? (λ () (双端队列/左弹出 '())) null))))
)

(测试组 "Collections - defaultdict"
  (λ ()
    (测试 "默认字典/创建"
      (λ ()
        (define dd (默认字典/创建 (λ () 0)))
        (断言测试 (pair? dd))))
    (测试 "默认字典/获取 - 不存在的键返回默认值"
      (λ ()
        (define dd (默认字典/创建 (λ () 0)))
        (define val (默认字典/获取 dd 'x))
        (断言相等 0 val)))))

(测试组 "Collections - OrderedDict"
  (λ ()
    (测试 "有序字典/创建"
      (λ ()
        (define od (有序字典/创建))
        (断言相等 #f (有序字典/获取 od 'x)))))

  (λ ()
    (测试 "有序字典/设置和获取"
      (λ ()
        (define od (有序字典/创建))
        (define od2 (有序字典/设置 od 'a 1))
        (define od3 (有序字典/设置 od2 'b 2))
        (断言相等 1 (有序字典/获取 od3 'a))
        (断言相等 2 (有序字典/获取 od3 'b)))))

  (λ ()
    (测试 "有序字典/转为列表"
      (λ ()
        (define od (有序字典/创建))
        (define od1 (有序字典/设置 od 'a 1))
        (define od2 (有序字典/设置 od1 'b 2))
        (define lst (有序字典/转为列表 od2))
        (断言相等 '((a . 1) (b . 2)) lst))))
)

(测试组 "Collections - namedtuple"
  (λ ()
    (测试 "命名元组/创建和新建"
      (λ ()
        (define Point (命名元组/创建 "Point" 'x 'y))
        (define p (命名元组/新建 Point 10 20))
        (断言相等 10 (hash-ref p 'x))
        (断言相等 20 (hash-ref p 'y)))))

  (λ ()
    (测试 "命名元组 - 参数数量不匹配异常"
      (λ ()
        (define Point (命名元组/创建 "Point" 'x 'y))
        (断言异常 exn:fail? (λ () (命名元组/新建 Point 10)) null))))
)

(测试组 "Collections - ChainMap"
  (λ ()
    (测试 "链映射/创建和获取"
      (λ ()
        (define m1 (make-hasheq '((a . 1) (b . 2))))
        (define m2 (make-hasheq '((b . 3) (c . 4))))
        (define cm (链映射/创建 m1 m2))
        (断言相等 1 (链映射/获取 cm 'a))
        (断言相等 2 (链映射/获取 cm 'b))
        (断言相等 4 (链映射/获取 cm 'c))
        (断言相等 #f (链映射/获取 cm 'x)))))

  (λ ()
    (测试 "链映射/新增"
      (λ ()
        (define m1 (make-hasheq '((a . 1))))
        (define cm (链映射/创建 m1))
        (define m2 (make-hasheq '((b . 2))))
        (define cm2 (链映射/新增 cm m2))
        (断言相等 2 (链映射/获取 cm2 'b)))))
)

(运行测试)