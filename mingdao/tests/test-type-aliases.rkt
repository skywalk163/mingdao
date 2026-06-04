#lang racket/base
(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

(displayln "=== 测试类型别名 ===")

;; 测试1: 简单类型别名
(define test1-code
  "定义类型 MyInt 就是 整数
定义 x: MyInt 就是 42
x, 打印")

(displayln "\n--- 测试1: 简单类型别名 ---")
(define tokens1 (tokenize test1-code))
(define ast1 (parse tokens1))
(displayln "AST:")
(displayln ast1)

;; 测试2: 泛型类型别名
(define test2-code
  "定义类型 IntList 就是 列表<整数>
定义 xs: IntList 就是 [1, 2, 3]
xs, 打印")

(displayln "\n--- 测试2: 泛型类型别名 ---")
(define tokens2 (tokenize test2-code))
(define ast2 (parse tokens2))
(displayln "AST:")
(displayln ast2)

;; 测试3: 嵌套别名
(define test3-code
  "定义类型 A 就是 整数
定义类型 B 就是 A
定义类型 C 就是 B
定义 x: C 就是 42
x, 打印")

(displayln "\n--- 测试3: 嵌套类型别名 ---")
(define tokens3 (tokenize test3-code))
(define ast3 (parse tokens3))
(displayln "AST:")
(displayln ast3)

;; 测试4: 联合类型别名
(define test4-code
  "定义类型 IntOrString 就是 整数 | 字符串
定义 x: IntOrString 就是 42
定义 y: IntOrString 就是 \"hello\"
x, 打印
y, 打印")

(displayln "\n--- 测试4: 联合类型别名 ---")
(define tokens4 (tokenize test4-code))
(define ast4 (parse tokens4))
(displayln "AST:")
(displayln ast4)

;; 测试5: 嵌套泛型类型别名
(define test5-code
  "定义类型 Matrix 就是 列表<列表<整数>>
定义 m: Matrix 就是 [[1, 2], [3, 4]]
m, 打印")

(displayln "\n--- 测试5: 嵌套泛型类型别名 ---")
(define tokens5 (tokenize test5-code))
(define ast5 (parse tokens5))
(displayln "AST:")
(displayln ast5)

(displayln "\n=== 类型别名测试完成 ===")