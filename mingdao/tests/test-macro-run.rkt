#lang racket

;; 明道语言宏系统 - 实际运行测试
;; 测试宏定义和展开执行

(displayln "========================================")
(displayln "明道语言宏系统 - 运行测试")
(displayln "========================================")

;; 使用 REPL 的求值方式来测试宏
(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         racket/port)

;; 创建独立的命名空间（模拟 REPL 环境）
(define ns
  (let ([ns (make-base-namespace)])
    (parameterize ([current-namespace ns])
      (define core-path (path->string (build-path (current-directory) ".." "core.rkt")))
      (eval `(require (file ,core-path)
                      racket/control))
      (void))
    ns))

;; 在命名空间中求值
(define (mingdao-eval expr)
  (parameterize ([current-namespace ns])
    (eval expr)))

;; 解析并执行一段明道代码
(define (run-mingdao code)
  (define tokens (tokenize code))
  (define ast (parse tokens))
  (for ([expr ast])
    (mingdao-eval expr)))

;; 测试1：基本宏 - 双倍
(displayln "\n【测试1】基本宏 - 双倍")
(displayln "定义宏 双倍 就是宏：")
(displayln "    生成 (双倍 x)")
(displayln "    捕获 (x 乘 2)")
(displayln "使用：双倍 5")

(run-mingdao "定义宏 双倍 就是宏：
    生成 (双倍 x)
    捕获 (x 乘 2)")

(define result1
  (parameterize ([current-namespace ns])
    (eval '(双倍 5))))
(displayln (format "双倍 5 = ~a" result1))

;; 测试2：交换参数宏
(displayln "\n【测试2】交换参数宏")
(displayln "定义宏 交换 就是宏：")
(displayln "    生成 (交换 a b)")
(displayln "    捕获 (列表 b a)")
(newline)
(displayln "使用：交换 3 7")

(run-mingdao "定义宏 交换 就是宏：
    生成 (交换 a b)
    捕获 (列表 b a)")

(define result2
  (parameterize ([current-namespace ns])
    (eval '(交换 3 7))))
(displayln (format "交换 3 7 = ~a" result2))

;; 测试3：耗时操作宏（开始/结束计时）
(displayln "\n【测试3】计时宏")
(displayln "定义宏 耗时 就是宏：")
(displayln "    生成 (耗时 expr)")
(displayln "    捕获 (begin (打印 \"开始...\") expr (打印 \"完成!\"))")

(run-mingdao "定义宏 耗时 就是宏：
    生成 (耗时 expr)
    捕获 (begin (打印 \"开始...\") expr (打印 \"完成!\"))")

(displayln "执行 耗时 42：")
(parameterize ([current-namespace ns])
  (eval '(耗时 42)))

(displayln "\n")
(displayln "========================================")
(displayln "宏系统运行测试完成！")
(displayln "========================================")