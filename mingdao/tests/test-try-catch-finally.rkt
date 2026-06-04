#lang racket/base

;; 明道语言 尝试/捕获/始终 - 运行时执行测试

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         racket/port)

;; 创建 Mingdao 运行时命名空间
(define (make-mingdao-namespace)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (define core-path
      (path->string (build-path (current-directory) ".." "core.rkt")))
    (eval `(require (file ,core-path)))
    (void))
  ns)

(define ns (make-mingdao-namespace))

(define test-passes 0)
(define test-failures 0)

(define (mingdao-eval expr)
  (parameterize ([current-namespace ns])
    (eval expr)))

(define (run-test name code expected)
  (printf "===== ~a =====\n" name)
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "失败：~a\n\n" (exn-message e))
                               (set! test-failures (add1 test-failures)))])
    (define tokens (tokenize code))
    (define ast (parse tokens))
    (printf "AST:\n~s\n" ast)
    (define result
      (for/list ([expr ast])
        (mingdao-eval expr)))
    (define actual (if (null? result) '(void) (car (reverse result))))
    (printf "结果: ~s\n" actual)
    (if (equal? actual expected)
        (begin
          (printf "✓ 通过（期望=~s, 实际=~s）\n\n" expected actual)
          (set! test-passes (add1 test-passes)))
        (begin
          (printf "✗ 失败：期望 ~s, 得到 ~s\n\n" expected actual)
          (set! test-failures (add1 test-failures))))))

;; ========== 测试1：基本捕获（除零） ==========
(run-test "基本捕获（除零）"
"定义 fn 就是函 n：
    尝试:
      10 除 0, 打印
    捕获 任意错误 为 e:
      \"出错\"
fn, 1"
  "出错")

;; ========== 测试2：正常执行无异常 ==========
(run-test "正常执行不触发捕获"
"定义 fn 就是函 n：
    尝试:
      n 加 1
    捕获 任意错误 为 e:
      0 减 1
fn, 5"
  6)

;; ========== 测试3：多路捕获（除零错误） ==========
(run-test "多路捕获（除零错误）"
"定义 fn 就是函 flag：
    尝试:
      如果 flag 那么:
        10 除 0
      否则:
        报错, \"手动错误\"
    捕获 除零错误 为 e:
      \"除零\"
    捕获 用户错误 为 e:
      \"用户异常\"
    捕获 任意错误 为 e:
      \"其他\"
fn, 真值"
  "除零")

;; ========== 测试4：多路捕获（用户错误） ==========
(run-test "多路捕获（用户错误）"
"定义 fn 就是函 flag：
    尝试:
      如果 flag 那么:
        10 除 0
      否则:
        报错, \"手动错误\"
    捕获 除零错误 为 e:
      \"除零\"
    捕获 用户错误 为 e:
      \"用户异常\"
    捕获 任意错误 为 e:
      \"其他\"
fn, 假值"
  "用户异常")

;; ========== 测试5：finally 正常执行 ==========
(run-test "finally 正常执行"
"定义 flag 就是 假值
尝试:
  赋值 flag 为 真值
捕获 任意错误 为 e:
  赋值 flag 为 假值
始终:
  赋值 flag 为 \"完成\"
flag"
  "完成")

;; ========== 测试6：finally 异常时执行 ==========
(run-test "finally 异常时执行"
"定义 flag 就是 假值
定义 fn 就是函 n：
    尝试:
      报错, \"测试\"
    捕获 任意错误 为 e:
      赋值 flag 为 \"已捕获\"
    始终:
      赋值 flag 为 \"已清理\"
fn, 1
flag"
  "已清理")

;; ========== 测试7：finally + 捕获返回值 ==========
(run-test "finally 捕获返回值"
"定义 fn 就是函 n：
    尝试:
      10 除 0
    捕获 任意错误 为 e:
      \"捕获值\"
    始终:
      \"始终值\"
fn, 1"
  "捕获值")

;; ========== 测试8：无 finally 正常路径 ==========
(run-test "无 finally 正常返回"
"定义 fn 就是函 n：
    尝试:
      n 加 1
    捕获 任意错误 为 e:
      0
fn, 41"
  42)

;; ========== 测试9：finally 未匹配异常时仍执行 ==========
(run-test "finally 未匹配异常时执行"
"定义 flag 就是 假值
定义 result 就是 空值
尝试:
  尝试:
    报错, \"测试\"
  捕获 类型错误 为 e:
    赋值 flag 为 \"类型\"
  始终:
    赋值 flag 为 \"最终清理\"
捕获 任意错误 为 e:
  flag"
  "最终清理")

;; ========== 测试10：嵌套尝试 ==========
(run-test "嵌套尝试"
"定义 inner 就是 \"\"
定义 outer 就是 \"\"
尝试:
  尝试:
    报错, \"内层\"
  捕获 用户错误 为 e:
    赋值 inner 为 \"内层捕获\"
  始终:
    赋值 inner 为 \"内层清理\"
  报错, \"外层\"
捕获 用户错误 为 e:
  赋值 outer 为 \"外层捕获\"
始终:
  赋值 outer 为 \"外层清理\"
inner, 拼接, outer"
  "内层清理外层清理")

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (displayln "所有运行时测试通过！")
    (printf "有 ~a 个测试失败！\n" test-failures))