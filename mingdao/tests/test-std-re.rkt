#lang racket
;; 明道标准库测试 - RE 模块
(require "../std/re.rkt"
         "../lang/test.rkt")

(测试组 "RE 模块"
  (λ ()
    (测试 "正则匹配 - 成功"
      (λ ()
        (define result (正则匹配 "\\d+" "abc123"))
        (断言测试 result "应匹配成功"))))

  (λ ()
    (测试 "正则匹配 - 失败"
      (λ ()
        (define result (正则匹配 "\\d+" "abc"))
        (断言测试 (not result) "不应匹配"))))

  (λ ()
    (测试 "正则搜索 - 找到匹配"
      (λ ()
        (define result (正则搜索 "\\d+" "abc123def456"))
        (断言相等 '("123") result))))

  (λ ()
    (测试 "正则搜索 - 无匹配"
      (λ ()
        (define result (正则搜索 "\\d+" "abc"))
        (断言相等 '() result))))

  (λ ()
    (测试 "正则替换"
      (λ ()
        (define result (正则替换 "\\d+" "abc123" "X"))
        (断言相等 "abcX" result))))

  (λ ()
    (测试 "正则全部替换"
      (λ ()
        (define result (正则全部替换 "\\d+" "a1b2c3" "X"))
        (断言相等 "aXbXcX" result))))

  (λ ()
    (测试 "正则分割"
      (λ ()
        (define result (正则分割 "\\s+" "a b   c"))
        (断言相等 '("a" "b" "c") result))))

  (λ ()
    (测试 "正则匹配所有"
      (λ ()
        (define result (正则匹配所有 "\\d+" "a1b22c333"))
        (断言相等 '("1" "22" "333") result))))

  (λ ()
    (测试 "正则转义"
      (λ ()
        (define result (正则转义 "a.b[c]"))
        (断言测试 (not (regexp-match? result "axb")) "点号被转义不应匹配任意字符")
        (断言测试 (regexp-match? result "a.b[c]") "应匹配原文"))))

  (λ ()
    (测试 "正则编译"
      (λ ()
        (define result (正则编译 "\\d+"))
        (断言测试 (regexp? result) "编译后应是正则对象"))))

  (λ ()
    (测试 "正则匹配位置"
      (λ ()
        (define result (正则匹配位置 "\\d+" "abc123def"))
        (断言相等 '((3 . 6)) result))))

  (λ ()
    (测试 "正则匹配位置 - 无匹配"
      (λ ()
        (define result (正则匹配位置 "\\d+" "abc"))
        (断言相等 #f result))))
)

(运行测试)