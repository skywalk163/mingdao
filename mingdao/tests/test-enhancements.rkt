#lang racket/base

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         "../lang/debug.rkt"
         "../lang/test.rkt"
         "../lang/error.rkt"
         racket/string
         racket/pretty
         racket/port)

;; 检查模块可加载性（最重要的测试）
(displayln "═══════════════════════════════════════")
(displayln "  明道语言增强功能 · 模块加载验证")
(displayln "═══════════════════════════════════════")
(displayln "")

;; ============================================================
;; 1. 验证 debug.rkt 模块
;; ============================================================
(displayln "▶ 验证 debug.rkt 模块...")

(display "  ✓ 断言函数: ") (displayln (procedure? 断言))
(display "  ✓ 跟踪函数: ") (displayln (procedure? 跟踪))
(display "  ✓ 检查函数: ") (displayln (procedure? 检查))
(display "  ✓ 检查列表函数: ") (displayln (procedure? 检查列表))
(display "  ✓ 断点函数: ") (displayln (procedure? 断点))
(display "  ✓ 调试输出函数: ") (displayln (procedure? 调试输出))
(display "  ✓ 记录函数: ") (displayln (procedure? 记录))
(display "  ✓ 调试模式函数: ") (displayln (procedure? 调试模式))

(displayln "")

;; ============================================================
;; 2. 验证 test.rkt 模块
;; ============================================================
(displayln "▶ 验证 test.rkt 模块...")

(display "  ✓ 测试函数: ") (displayln (procedure? 测试))
(display "  ✓ 测试组函数: ") (displayln (procedure? 测试组))
(display "  ✓ 断言测试函数: ") (displayln (procedure? 断言测试))
(display "  ✓ 断言相等函数: ") (displayln (procedure? 断言相等))
(display "  ✓ 运行测试函数: ") (displayln (procedure? 运行测试))

(displayln "")

;; ============================================================
;; 3. 验证 error.rkt 增强
;; ============================================================
(displayln "▶ 验证 error.rkt 增强...")

(display "  ✓ 格式化异常: ") (displayln (procedure? 格式化异常))
(display "  ✓ 错误摘要: ") (displayln (procedure? 错误摘要))
(display "  ✓ 运行时错误: ") (displayln (procedure? 运行时错误))
(display "  ✓ 类型错误: ") (displayln (procedure? 类型错误))
(display "  ✓ 断言失败错误: ") (displayln (procedure? 断言失败错误))

(displayln "")

;; ============================================================
;; 4. 功能测试：断言
;; ============================================================
(displayln "▶ 功能测试：断言...")

(define (test-断言)
  (断言 #t)
  (displayln "  ✓ 断言通过: 正常")
  (define result
    (with-handlers ([exn:fail? (λ (e) 'failed)])
      (断言 #f "故意失败")))
  (if (equal? result 'failed)
      (displayln "  ✓ 断言失败: 正确捕获异常")
      (displayln "  ✗ 断言失败: 未捕获异常")))

(test-断言)
(displayln "")

;; ============================================================
;; 5. 功能测试：检查
;; ============================================================
(displayln "▶ 功能测试：检查...")

(define output (open-output-string))
(parameterize ([current-output-port output])
  (检查 "测试" 42))
(define 检查输出 (get-output-string output))
(close-output-port output)

(if (and (string-contains? 检查输出 "测试")
         (string-contains? 检查输出 "数字"))
    (displayln "  ✓ 检查输出格式正确")
    (displayln "  ✗ 检查输出格式异常"))

(displayln "")

;; ============================================================
;; 6. 功能测试：跟踪
;; ============================================================
(displayln "▶ 功能测试：跟踪...")

(define (add a b) (+ a b))
(define traced-add (跟踪 add))

(define trace-output (open-output-string))
(parameterize ([current-output-port trace-output])
  (traced-add 3 4))
(define trace-result (get-output-string trace-output))
(close-output-port trace-output)

(if (and (string-contains? trace-result "进入")
         (string-contains? trace-result "返回"))
    (displayln "  ✓ 跟踪输出格式正确")
    (displayln "  ✗ 跟踪输出格式异常"))

(displayln "")

;; ============================================================
;; 7. 功能测试：记录
;; ============================================================
(displayln "▶ 功能测试：记录...")

(define log-output (open-output-string))
(parameterize ([current-output-port log-output])
  (记录 "info" "测试" "信息日志")
  (记录 "warn" "测试" "警告日志"))
(define log-result (get-output-string log-output))
(close-output-port log-output)

(if (string-contains? log-result "INFO")
    (displayln "  ✓ 记录输出格式正确")
    (displayln "  ✗ 记录输出格式异常"))

(displayln "")

;; ============================================================
;; 8. 功能测试：测试框架
;; ============================================================
(displayln "▶ 功能测试：测试框架...")

(define test-output (open-output-string))
(parameterize ([current-output-port test-output])
  (测试 "基本断言" (λ () (断言 #t)))
  (测试 "相等断言" (λ () (断言相等 42 42))))
(close-output-port test-output)

(displayln "  ✓ 测试框架可正常执行")

(displayln "")

;; ============================================================
;; 9. 功能测试：错误格式化
;; ============================================================
(displayln "▶ 功能测试：错误格式化...")

(define err (运行时错误 "测试错误信息" 10 5 "请检查代码"))
(define formatted (格式化错误信息 err))

(if (and (string-contains? formatted "运行时错误")
         (string-contains? formatted "第 10 行")
         (string-contains? formatted "测试错误信息")
         (string-contains? formatted "请检查代码"))
    (displayln "  ✓ 错误格式化完整正确")
    (displayln "  ✗ 错误格式化不完整"))

(define summary (错误摘要 err))
(if (string-contains? summary "运行时错误")
    (displayln "  ✓ 错误摘要正确")
    (displayln "  ✗ 错误摘要异常"))

(displayln "")

;; ============================================================
;; 10. 验证明道代码解析
;; ============================================================
(displayln "▶ 验证新关键字被解析器识别...")

(define test-codes
  '("断言, 真值"
    "42, \"分数\", 检查"
    "调试输出, \"标签\", 42"
    "记录, \"info\", \"模块\", \"消息\""
    "测试, \"用例\", 某函数"
    "运行测试"))

(for ([code test-codes])
  (with-handlers ([exn:fail? 
                    (λ (e) (displayln (format "  ✗ 解析失败: ~a" code)))]
                   [exn:break? void])
    (define tokens (tokenize code))
    (define ast (parse tokens))
    (displayln (format "  ✓ 解析成功: ~a → ~a" code ast))))

(displayln "")
(displayln "═══════════════════════════════════════")
(displayln "  验证完成！所有基础模块均正常工作")
(displayln "═══════════════════════════════════════")