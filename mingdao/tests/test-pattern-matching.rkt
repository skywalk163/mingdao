#lang racket/base

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         racket/port
         racket/pretty)

(define (run-test name code)
  (printf "===== ~a =====\n" name)
  (with-handlers ([exn:fail? (lambda (e) 
                               (printf "失败：~a\n\n" (exn-message e))
                               (set! test-failures (add1 test-failures)))])
    (define tokens (tokenize code))
    (printf "Token 数: ~a\n" (length tokens))
    (define ast (parse tokens))
    (printf "AST:\n~s\n" ast)
    (printf "✓ 通过\n\n")
    (set! test-passes (add1 test-passes))))

(define test-passes 0)
(define test-failures 0)

;; 测试1：基本数字匹配
(run-test "基本数字匹配"
"定义 n 就是 3
匹配 n:
  1 那么:
    \"一\", 打印
  2 那么:
    \"二\", 打印
  3 那么:
    \"三\", 打印
  否则:
    \"其他\", 打印
")

;; 测试2：字符串匹配
(run-test "字符串匹配"
"定义 s 就是 \"Hello\"
匹配 s:
  \"Hi\" 那么:
    \"Hi!\", 打印
  \"Hello\" 那么:
    \"世界，你好！\", 打印
  否则:
    \"未知\", 打印
")

;; 测试3：通配符匹配
(run-test "通配符匹配"
"定义 x 就是 42
匹配 x:
  0 那么:
    \"零\", 打印
  任意 那么:
    \"非零\", 打印
  否则:
    \"不会执行到此\", 打印
")

;; 测试4：变量绑定模式
(run-test "变量绑定模式"
"定义 n 就是 5
匹配 n:
  a 那么:
    a, 打印
  否则:
    \"不会执行\", 打印
")

;; 测试5：列表解构模式
(run-test "列表解构模式"
"定义 lst 就是 [1, 2, 3]
匹配 lst:
  [a, b, c] 那么:
    a 加 b 加 c, 打印
  否则:
    \"不匹配\", 打印
")

;; 测试6：守卫条件
(run-test "守卫条件"
"定义 n 就是 15
匹配 n:
  x 如果 x 大于 10 那么:
    \"大\", 打印
  x 如果 x 大于 5 那么:
    \"中\", 打印
  否则:
    \"小\", 打印
")

;; 测试7：单行模式
(run-test "单行模式"
"定义 n 就是 2
匹配 n:
  1 那么: \"一\", 打印
  2 那么: \"二\", 打印
  否则: \"其他\", 打印
")

;; 测试8：布尔值匹配
(run-test "布尔值匹配"
"定义 flag 就是 真值
匹配 flag:
  真值 那么:
    \"真\", 打印
  假值 那么:
    \"假\", 打印
  否则:
    \"未知\", 打印
")

;; 测试9：空列表匹配
(run-test "空列表匹配"
"定义 lst 就是 []
匹配 lst:
  [] 那么:
    \"空列表\", 打印
  否则:
    \"非空\", 打印
")

;; 测试10：整数模式匹配
(run-test "整数模式匹配"
"定义 n 就是 5
匹配 n:
  1 那么: n 减 1, 打印
  5 那么: n 加 10, 打印
  否则: 0, 打印
")

(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (displayln "所有模式匹配测试通过！")
    (printf "有 ~a 个测试失败！\n" test-failures))