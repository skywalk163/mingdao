#lang racket
;; 明道标准库测试 - CSV 模块
(require "../std/csv.rkt"
         "../lang/test.rkt")

(测试组 "CSV 模块"
  (λ ()
    (测试 "csv解析 - 简单行"
      (λ ()
        (define result (csv解析 "a,b,c"))
        (断言相等 '(("a" "b" "c")) result))))

  (λ ()
    (测试 "csv解析 - 多行"
      (λ ()
        (define result (csv解析 "a,b\nc,d"))
        (断言相等 '(("a" "b") ("c" "d")) result))))

  (λ ()
    (测试 "csv解析 - 空字段"
      (λ ()
        (define result (csv解析 "a,,c"))
        (断言相等 '(("a" "" "c")) result))))

  (λ ()
    (测试 "csv解析 - 带引号字段"
      (λ ()
        (define result (csv解析 "\"hello, world\",b"))
        (断言相等 '(("hello, world" "b")) result))))

  (λ ()
    (测试 "csv解析 - 引号内双引号转义"
      (λ ()
        (define result (csv解析 "\"say \"\"hello\"\"\",b"))
        (断言相等 '(("say \"hello\"" "b")) result))))

  (λ ()
    (测试 "csv解析 - 空字符串"
      (λ ()
        (define result (csv解析 ""))
        (断言相等 '() result))))

  (λ ()
    (测试 "csv解析 - 单字段"
      (λ ()
        (define result (csv解析 "hello"))
        (断言相等 '(("hello")) result))))

  (λ ()
    (测试 "csv解析 - 多行含空行"
      (λ ()
        (define result (csv解析 "a,b\n\nc,d"))
        (断言相等 '(("a" "b") ("") ("c" "d")) result))))

  (λ ()
    (测试 "csv生成 - 简单数据"
      (λ ()
        (define result (csv生成 '(("a" "b") ("c" "d"))))
        (断言相等 "a,b\nc,d" result))))

  (λ ()
    (测试 "csv生成 - 含逗号字段自动加引号"
      (λ ()
        (define result (csv生成 '(("hello, world" "b"))))
        (断言相等 "\"hello, world\",b" result))))

  (λ ()
    (测试 "csv生成 - 含引号字段自动转义"
      (λ ()
        (define result (csv生成 '(("say \"hello\"" "b"))))
        (断言相等 "\"say \"\"hello\"\"\",b" result))))

  (λ ()
    (测试 "csv生成 - 空数据"
      (λ ()
        (define result (csv生成 '()))
        (断言相等 "" result))))

  (λ ()
    (测试 "csv生成 → csv解析 往返"
      (λ ()
        (define original '(("name" "age") ("Alice" "30") ("Bob" "25")))
        (define serialized (csv生成 original))
        (define parsed (csv解析 serialized))
        (断言相等 original parsed))))

  (λ ()
    (测试 "csv生成 → csv解析 往返（含特殊字符）"
      (λ ()
        (define original '(("a\"b" "c,d" "e\nf")))
        (define serialized (csv生成 original))
        (define parsed (csv解析 serialized))
        (断言相等 original parsed))))
)

(运行测试)