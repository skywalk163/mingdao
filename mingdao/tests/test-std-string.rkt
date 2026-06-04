#lang racket
;; 明道标准库测试 - String 模块
(require "../std/string.rkt"
         "../lang/test.rkt")

(测试组 "String 模块 - 常量"
  (λ ()
    (测试 "小写字母"
      (λ ()
        (断言相等 26 (string-length 小写字母))
        (断言测试 (string-contains? 小写字母 "a"))
        (断言测试 (string-contains? 小写字母 "z")))))

  (λ ()
    (测试 "大写字母"
      (λ ()
        (断言相等 26 (string-length 大写字母))
        (断言测试 (string-contains? 大写字母 "A"))
        (断言测试 (string-contains? 大写字母 "Z")))))

  (λ ()
    (测试 "数字字符"
      (λ ()
        (断言相等 10 (string-length 数字字符))
        (断言测试 (string-contains? 数字字符 "0"))
        (断言测试 (string-contains? 数字字符 "9")))))
)

(测试组 "String 模块 - 大小写转换"
  (λ ()
    (测试 "字符串/大写"
      (λ ()
        (define result (字符串/大写 "hello"))
        (断言相等 "HELLO" result))))

  (λ ()
    (测试 "字符串/小写"
      (λ ()
        (define result (字符串/小写 "HELLO"))
        (断言相等 "hello" result))))

  (λ ()
    (测试 "字符串/首字母大写"
      (λ ()
        (define result (字符串/首字母大写 "hello"))
        (断言相等 "Hello" result))))

  (λ ()
    (测试 "字符串/首字母大写 - 空字符串"
      (λ ()
        (define result (字符串/首字母大写 ""))
        (断言相等 "" result))))

  (λ ()
    (测试 "字符串/首字母小写"
      (λ ()
        (define result (字符串/首字母小写 "Hello"))
        (断言相等 "hello" result))))

  (λ ()
    (测试 "字符串/交换大小写"
      (λ ()
        (define result (字符串/交换大小写 "HelloWorld"))
        (断言相等 "hELLOwORLD" result))))
)

(测试组 "String 模块 - 对齐"
  (λ ()
    (测试 "字符串/居中"
      (λ ()
        (define result (字符串/居中 "a" 5))
        (断言相等 "  a  " result))))

  (λ ()
    (测试 "字符串/左对齐"
      (λ ()
        (define result (字符串/左对齐 "a" 3))
        (断言相等 "a  " result))))

  (λ ()
    (测试 "字符串/右对齐"
      (λ ()
        (define result (字符串/右对齐 "a" 3))
        (断言相等 "  a" result))))

  (λ ()
    (测试 "字符串/左对齐 - 宽度不足返回原文"
      (λ ()
        (define result (字符串/左对齐 "hello" 3))
        (断言相等 "hello" result))))
)

(测试组 "String 模块 - 判断"
  (λ ()
    (测试 "字符串/开头判断"
      (λ ()
        (断言测试 (字符串/开头判断 "hello" "he"))
        (断言测试 (not (字符串/开头判断 "hello" "el"))))))

  (λ ()
    (测试 "字符串/结尾判断"
      (λ ()
        (断言测试 (字符串/结尾判断 "hello" "lo"))
        (断言测试 (not (字符串/结尾判断 "hello" "el"))))))
)

(测试组 "String 模块 - 变换"
  (λ ()
    (测试 "字符串/反转"
      (λ ()
        (define result (字符串/反转 "abc"))
        (断言相等 "cba" result))))

  (λ ()
    (测试 "字符串/反转 - 空字符串"
      (λ ()
        (define result (字符串/反转 ""))
        (断言相等 "" result))))

  (λ ()
    (测试 "字符串/下划线转驼峰"
      (λ ()
        (define result (字符串/下划线转驼峰 "hello_world"))
        (断言相等 "helloWorld" result))))

  (λ ()
    (测试 "字符串/驼峰转下划线"
      (λ ()
        (define result (字符串/驼峰转下划线 "helloWorld"))
        (断言相等 "hello_world" result))))

  (λ ()
    (测试 "字符串/压缩空白"
      (λ ()
        (define result (字符串/压缩空白 "a   b  c"))
        (断言相等 "a b c" result))))

  (λ ()
    (测试 "字符串/删除前缀"
      (λ ()
        (define result (字符串/删除前缀 "hello world" "hello "))
        (断言相等 "world" result))))

  (λ ()
    (测试 "字符串/删除前缀 - 无匹配"
      (λ ()
        (define result (字符串/删除前缀 "hello" "xyz"))
        (断言相等 "hello" result))))

  (λ ()
    (测试 "字符串/删除后缀"
      (λ ()
        (define result (字符串/删除后缀 "test.txt" ".txt"))
        (断言相等 "test" result))))

  (λ ()
    (测试 "字符串/转义"
      (λ ()
        (define result (字符串/转义 "hello\nworld\"test"))
        (断言相等 "hello\\nworld\\\"test" result))))
)

(测试组 "String 模块 - 格式与模板"
  (λ ()
    (测试 "字符串/格式"
      (λ ()
        (define result (字符串/格式 "~a + ~a = ~a" 1 2 3))
        (断言相等 "1 + 2 = 3" result))))

  (λ ()
    (测试 "字符串/模板"
      (λ ()
        (define result (字符串/模板 "{0}和{1}是{0}" "苹果" "香蕉"))
        (断言相等 "苹果和香蕉是苹果" result))))
)

(测试组 "String 模块 - 行操作"
  (λ ()
    (测试 "字符串/按宽度折行"
      (λ ()
        (define result (字符串/按宽度折行 "a b c d e" 5))
        (断言相等 "a b c\nd e" result))))

  (λ ()
    (测试 "字符串/切分行"
      (λ ()
        (define result (字符串/切分行 "a\nb\nc"))
        (断言相等 '("a" "b" "c") result))))
)

(测试组 "String 模块 - 搜索计数"
  (λ ()
    (测试 "字符串/索引所有"
      (λ ()
        (define result (字符串/索引所有 "ababa" "a"))
        (断言相等 '(0 2 4) result))))

  (λ ()
    (测试 "字符串/匹配计数"
      (λ ()
        (define result (字符串/匹配计数 "ababa" "a"))
        (断言相等 3 result))))
)

(运行测试)