#lang racket
;; 明道标准库测试 - JSON 模块
(require "../std/json.rkt"
         "../lang/test.rkt")

(测试组 "JSON 模块"
  (λ ()
    (测试 "json解析 - 解析对象"
      (λ ()
        (define result (json解析 "{\"name\":\"明道\",\"version\":1}"))
        (断言相等 #hasheq((name . "明道") (version . 1)) result))))

  (λ ()
    (测试 "json解析 - 解析数组"
      (λ ()
        (define result (json解析 "[1,2,3]"))
        (断言相等 '(1 2 3) result))))

  (λ ()
    (测试 "json解析 - 解析字符串"
      (λ ()
        (define result (json解析 "\"hello\""))
        (断言相等 "hello" result))))

  (λ ()
    (测试 "json解析 - 解析数字"
      (λ ()
        (define result (json解析 "42"))
        (断言相等 42 result))))

  (λ ()
    (测试 "json解析 - 空对象"
      (λ ()
        (define result (json解析 "{}"))
        (断言相等 #hasheq() result))))

  (λ ()
    (测试 "json解析 - 空数组"
      (λ ()
        (define result (json解析 "[]"))
        (断言相等 '() result))))

  (λ ()
    (测试 "json解析 - 无效输入抛异常"
      (λ ()
        (断言异常 exn:fail? json解析 (list "{invalid}")))))

  (λ ()
    (测试 "json生成 - 对象"
      (λ ()
        (define result (json生成 #hasheq((name . "测试") (count . 3))))
        (define parsed (json解析 result))
        (断言相等 "测试" (hash-ref parsed 'name))
        (断言相等 3 (hash-ref parsed 'count)))))

  (λ ()
    (测试 "json生成 - 数组"
      (λ ()
        (define result (json生成 '(1 2 3)))
        (断言相等 "[1,2,3]" result))))

  (λ ()
    (测试 "json生成 - 字符串"
      (λ ()
        (define result (json生成 "hello"))
        (断言相等 "\"hello\"" result))))

  (λ ()
    (测试 "json生成 - 空数组"
      (λ ()
        (define result (json生成 '()))
        (断言相等 "[]" result))))

  (λ ()
    (测试 "json字符串转列表 是 json解析 的别名"
      (λ ()
        (define r1 (json解析 "[1,2,3]"))
        (define r2 (json字符串转列表 "[1,2,3]"))
        (断言相等 r1 r2))))

  (λ ()
    (测试 "列表转json字符串 是 json生成 的别名"
      (λ ()
        (define r1 (json生成 '("a" "b")))
        (define r2 (列表转json字符串 '("a" "b")))
        (断言相等 r1 r2))))
)

(运行测试)