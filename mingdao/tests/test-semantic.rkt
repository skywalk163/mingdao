#lang racket/base

(require rackunit
         rackunit/text-ui
         (only-in "../lang/semantic.rkt"
                  analyze
                  semantic-error
                  semantic-error-type))

(define builtin-names
  (list "打印" "长度" "索引" "列表" "加" "减" "乘" "除" "如果" "那么" "否则"
        "否则若" "对于" "从" "到" "返回" "赋值" "定义" "就是"
        "真值" "假值" "空值" "匿名函数" "字典" "导入" "导出"
        "映射" "过滤" "范围" "尝试" "捕获" "始终" "匹配" "任意" "新建"))

(define (run-test name ast expected-error-count [expected-types #f])
  (test-case name
    (let* ([errors (analyze ast builtin-names)])
      (check-equal? (length errors) expected-error-count
                    (format "测试 ~a: 期望 ~a 个错误，实际得到 ~a 个: ~a"
                            name expected-error-count (length errors)
                            (map semantic-error-type errors)))
      (when expected-types
        (check-equal? (map semantic-error-type errors) expected-types
                      (format "测试 ~a: 期望错误类型 ~a，实际 ~a"
                              name expected-types (map semantic-error-type errors)))))))

(define semantic-tests
  (test-suite
   "明道语言语义分析器测试"

   ;; 1. 变量定义后使用 — 应无错误
   (run-test "1. 正常变量定义和使用"
             '((define x 5)
               (define y 10)
               (打印 x))
             0)

   ;; 2. 引用未定义变量 — 应产生 undefined-var 错误
   (run-test "2. 引用未定义变量"
             '((define x 5)
               (打印 y))
             1
             '(undefined-var))

   ;; 3. 重复定义变量 — 应产生 redefined 错误
   (run-test "3. 同一作用域重复定义变量"
             '((define x 5)
               (define x 10)
               (打印 x))
             1
             '(redefined))

   ;; 4. 调用未定义函数 — 应产生 undefined-var 错误
   (run-test "4. 调用未定义函数"
             '((define x 5)
               (未定义函数 x))
             1
             '(undefined-var))

   ;; 5. 调用已定义的内置函数 — 应无错误
   (run-test "5. 调用内置函数（打印）"
             '((打印 "Hello")
               (打印 (列表 1 2 3))
               (长度 (列表 1 2 3)))
             0)

   ;; 6. 函数定义及参数注册 — 应无错误
   (run-test "6. 函数定义及其参数在函数体内可用"
             '((define (加法 a b)
                 (加 a b))
               (打印 (加法 1 2)))
             0)

   ;; 7. 函数内引用全局变量 — 应无错误
   (run-test "7. 函数体内引用全局定义的变量"
             '((define 基数 10)
               (define (翻倍 x)
                 (加 x 基数))
               (打印 (翻倍 5)))
             0)

   ;; 8. 作用域遮蔽（子作用域定义同名变量） — 应产生 shadowed 警告
   (run-test "8. 子作用域遮蔽父作用域同名变量（if 分支）"
             '((define x 1)
               (if #t
                   (define x 2)
                   (define x 3))
               (打印 x))
             2
             '(shadowed shadowed))

   ;; 9. 常量赋值（对不可变绑定执行 set!） — 应产生 constant-assign 错误
   (run-test "9. 对函数绑定（不可变）执行 set!"
             '((define (foo) 42)
               (set! foo 100)
               (打印 foo))
             1
             '(constant-assign))

   ;; 10. for 循环（嵌套 let/ec + for） — 应无错误
   (run-test "10. for 循环与 let/ec 作用域嵌套"
             '((let/ec 跳出
                 (for ((i (in-range 0 10)))
                   (打印 i)))
               (打印 "完成"))
             0)

   ;; 11. 混合测试 — 一段完整代码的综合分析
   (run-test "11. 混合场景：多种构造的综合分析"
             '((define 姓名 "小明")
               (define 年龄 18)
               (define (问候 who)
                 (打印 (加 "你好, " who)))
               (问候 姓名)
               (for ((i (in-range 0 年龄)))
                 (打印 i))
               (if #t
                   (打印 "是")
                   (打印 "否")))
             0)

   ;; 附加：边界测试 — 空程序
   (run-test "附加-1. 空程序应无错误"
             '()
             0)

   ;; 附加：边界测试 — 多个未定义变量累积
   (run-test "附加-2. 多个未定义符号产生多个错误"
             '((打印 a)
               (打印 b)
               (打印 c))
             3
             '(undefined-var undefined-var undefined-var))

   ;; 附加：边界测试 — 仅数字/字符串字面量
   (run-test "附加-3. 仅数字和字符串字面量"
             '((打印 42)
               (打印 "hi"))
             0)

   ;; 附加：边界测试 — 重复定义 + 遮蔽组合
   (run-test "附加-4. 同作用域重复定义（redefined）与子作用域遮蔽（shadowed）同时出现"
             '((define x 1)
               (define x 2)
               (if #t
                   (define x 3)
                   0))
             2
             '(redefined shadowed))

   ;; 附加：边界测试 — for-each 形式（遍历列表）
   (run-test "附加-5. for-each 形式的 for 循环"
             '((define 数据 (列表 1 2 3))
               (for ((item 数据))
                 (打印 item)))
             0)

   ;; 附加：使用 = 赋值给可变变量
   (run-test "附加-6. 使用 = 对可变变量赋值合法"
             '((define x 1)
               (= x 2)
               (打印 x))
             0)

   ;; 附加：对未定义变量执行 set! 应产生 undefined-var
   (run-test "附加-7. 对未定义变量 set! 产生 undefined-var"
             '((set! y 42))
             1
             '(undefined-var))))

(module+ main
  (printf "========== 开始运行语义分析器测试 ==========~n")
  (define total-failures (run-tests semantic-tests))
  (printf "========== 测试完成：失败 ~a 个 ==========~n" total-failures))

(module+ test
  (run-tests semantic-tests))
