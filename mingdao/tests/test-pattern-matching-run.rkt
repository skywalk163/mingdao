#lang racket/base

;; 明道语言模式匹配 - 运行时执行测试
;; 验证 match 产生的 AST 能在 Racket 运行时正确执行

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

;; ========== 测试1：基本数字匹配 ==========
(run-test "基本数字匹配（返回字符串）"
"定义 fn 就是函 n：
    匹配 n:
      1 那么: 返回 \"一\"
      2 那么: 返回 \"二\"
      3 那么: 返回 \"三\"
      否则: 返回 \"其他\"
fn, 3"
  "三")

;; ========== 测试2：匹配数字 1 ==========
(run-test "基本数字匹配（匹配1）"
"定义 fn 就是函 n：
    匹配 n:
      1 那么: 返回 \"一\"
      2 那么: 返回 \"二\"
      3 那么: 返回 \"三\"
      否则: 返回 \"其他\"
fn, 1"
  "一")

;; ========== 测试3：匹配缺省分支 ==========
(run-test "匹配缺省分支"
"定义 fn 就是函 n：
    匹配 n:
      1 那么: 返回 \"一\"
      2 那么: 返回 \"二\"
      否则: 返回 \"其他\"
fn, 99"
  "其他")

;; ========== 测试4：守卫条件 ==========
(run-test "守卫条件"
"定义 fn 就是函 n：
    匹配 n:
      x 如果 x 大于 10 那么: 返回 \"大\"
      x 如果 x 大于 5 那么: 返回 \"中\"
      否则: 返回 \"小\"
fn, 15"
  "大")

;; ========== 测试5：守卫条件（中）==========
(run-test "守卫条件（中）"
"定义 fn 就是函 n：
    匹配 n:
      x 如果 x 大于 10 那么: 返回 \"大\"
      x 如果 x 大于 5 那么: 返回 \"中\"
      否则: 返回 \"小\"
fn, 7"
  "中")

;; ========== 测试6：守卫条件（小）==========
(run-test "守卫条件（小）"
"定义 fn 就是函 n：
    匹配 n:
      x 如果 x 大于 10 那么: 返回 \"大\"
      x 如果 x 大于 5 那么: 返回 \"中\"
      否则: 返回 \"小\"
fn, 3"
  "小")

;; ========== 测试7：字符串匹配 ==========
(run-test "字符串匹配"
"定义 fn 就是函 s：
    匹配 s:
      \"Hello\" 那么: 返回 \"世界你好\"
      \"Hi\" 那么: 返回 \"你好\"
      否则: 返回 \"未知\"
fn, \"Hello\""
  "世界你好")

;; ========== 测试8：通配符匹配 ==========
(run-test "通配符匹配"
"定义 fn 就是函 x：
    匹配 x:
      0 那么: 返回 \"零\"
      任意 那么: 返回 \"非零\"
      否则: 返回 \"未知\"
fn, 42"
  "非零")

;; ========== 测试9：布尔值匹配 ==========
(run-test "布尔值匹配"
"定义 fn 就是函 flag：
    匹配 flag:
      真值 那么: 返回 \"真\"
      假值 那么: 返回 \"假\"
      否则: 返回 \"未知\"
fn, 真值"
  "真")

;; ========== 测试10：多语句体 ==========
(run-test "多语句体"
"定义 result 就是 \"\"
定义 fn 就是函 n：
    匹配 n:
      1 那么:
        赋值 result 为 \"多\"
        result, 打印
      否则:
        赋值 result 为 \"其他\"
        result, 打印
fn, 1
result"
  "多")

;; ========== 测试11：列表解构 ==========
(run-test "列表解构模式"
"定义 fn 就是函 lst：
    匹配 lst:
      [a, b, c] 那么: 返回 a 加 b 加 c
      否则: 返回 \"不匹配\"
fn, [1, 2, 3]"
  6)

;; ========== 测试12：变量绑定 ==========
(run-test "变量绑定模式"
"定义 fn 就是函 n：
    匹配 n:
      a 那么: 返回 a 加 1
      否则: 返回 0
fn, 5"
  6)

;; ========== 测试13：空列表匹配 ==========
(run-test "空列表匹配"
"定义 fn 就是函 lst：
    匹配 lst:
      [] 那么: 返回 \"空列表\"
      否则: 返回 \"非空\"
fn, []"
  "空列表")

;; ========== 汇总 ==========
(printf "\n========== 汇总 ==========\n")
(printf "通过: ~a\n" test-passes)
(printf "失败: ~a\n" test-failures)
(if (= test-failures 0)
    (displayln "所有运行时测试通过！")
    (printf "有 ~a 个测试失败！\n" test-failures))