#lang racket/base

(require "formatter.rkt"
         "debugger.rkt"
         "package-manager.rkt")

(printf "开始测试明道语言生态工具...\n\n")

;; 测试代码格式化工具
(printf "1. 测试代码格式化工具...\n")
(define test-code "定义 x 就是 1
如果 x > 0 那么
打印 \"正数\"
否则
打印 \"非正数\"")
(printf "原始代码:\n~a\n\n" test-code)
(define formatted-code (format-code test-code))
(printf "格式化后的代码:\n~a\n\n" formatted-code)

;; 测试调试器
(printf "2. 测试调试器...\n")
(define dbg (make-debugger))
(debugger-break dbg 10)
(debugger-set-variable! dbg 'x 42)
(printf "变量列表: ~a\n\n" (debugger-get-variables dbg))

;; 测试包管理器
(printf "3. 测试包管理器...\n")
(pm-install "test-package" "1.0.0")
(pm-list)
(printf "搜索包 (\"util\"): ~a\n\n" (pm-search "util"))

(printf "所有工具测试完成！\n")
