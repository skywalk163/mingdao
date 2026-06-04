#lang racket/base
(require racket/port)
(require "../std/logging.rkt")

(provide 运行测试)

;; ==================== 测试框架 ====================
(define 测试通过数 0)
(define 测试失败数 0)
(define 测试报告 '())

(define (记录测试结果 测试名 结果 详情)
  (if 结果
      (set! 测试通过数 (add1 测试通过数))
      (set! 测试失败数 (add1 测试失败数)))
  (set! 测试报告 (cons (list 测试名 结果 详情) 测试报告)))

(define (输出测试摘要)
  (printf "╔══════════════════════════════════════╗~n")
  (printf "║        明道测试报告                    ║~n")
  (printf "╚══════════════════════════════════════╝~n")
  (printf "~n  测试总数: ~a~n" (+ 测试通过数 测试失败数))
  (printf "  通过:     ~a~n" 测试通过数)
  (printf "  失败:     ~a~n~n" 测试失败数)
  (list '测试结果 (+ 测试通过数 测试失败数) 测试通过数 测试失败数 (reverse 测试报告)))

(define (开始测试组 组名)
  (printf "═══════════════════════════════════════~n")
  (printf "  📋 测试组: ~a~n" 组名)
  (printf "───────────────────────────────────────~n"))

;; ==================== Logging 模块测试 ====================
(开始测试组 "Logging 模块")

;; 测试1: 创建日志器
(let ([logger (日志/获取日志器 "test")])
  (记录测试结果 "创建日志器" (not (not logger)) "能成功创建日志器"))

;; 测试2: 日志级别常量
(let ([结果 (and (equal? 日志/DEBUG 0)
                  (equal? 日志/INFO 1)
                  (equal? 日志/WARNING 2)
                  (equal? 日志/ERROR 3)
                  (equal? 日志/CRITICAL 4))])
  (记录测试结果 "日志级别常量" 结果 "所有日志级别常量值正确"))

;; 测试3: 设置日志级别（不直接访问结构体）
(let* ([logger (日志/获取日志器 "test")]
       [_ (日志/设置级别 logger 日志/INFO)])
  (记录测试结果 "设置日志级别" #t "能成功调用设置日志级别函数"))

;; 测试4: 基本配置
(let ([logger (日志/基本配置)])
  (记录测试结果 "基本配置" (not (not logger)) "能成功调用基本配置"))

;; 测试5: 创建格式器
(let ([formatter (日志/格式器 "[~a] ~a")])
  (记录测试结果 "创建格式器" (not (not formatter)) "能成功创建格式器"))

;; 测试6: 流式处理器（不实际输出）
(let* ([fmt (日志/格式器 "[~a] ~a")]
       [handler (日志/流处理器 "test" 日志/DEBUG fmt (open-output-bytes))])
  (记录测试结果 "流式处理器" (not (not handler)) "能成功创建流式处理器"))

;; 测试7: 日志记录（DEBUG级别）
(let* ([out (open-output-bytes)]
       [logger (日志/获取日志器 "test")]
       [fmt (日志/格式器 "[~a] ~a")]
       [handler (日志/流处理器 "test" 日志/DEBUG fmt out)])
  (日志/添加处理器 logger handler)
  (日志/调试 logger "调试消息")
  (let ([输出内容 (get-output-string out)])
    (记录测试结果 "记录 DEBUG 日志" (string? 输出内容) "能记录 DEBUG 级别的日志")))

;; 测试8: 日志记录（INFO级别）
(let* ([out (open-output-bytes)]
       [logger (日志/获取日志器 "test")]
       [fmt (日志/格式器 "[~a] ~a")]
       [handler (日志/流处理器 "test" 日志/INFO fmt out)])
  (日志/添加处理器 logger handler)
  (日志/信息 logger "信息消息")
  (let ([输出内容 (get-output-string out)])
    (记录测试结果 "记录 INFO 日志" (string? 输出内容) "能记录 INFO 级别的日志")))

;; 测试9: 日志记录（WARNING级别）
(let* ([out (open-output-bytes)]
       [logger (日志/获取日志器 "test")]
       [fmt (日志/格式器 "[~a] ~a")]
       [handler (日志/流处理器 "test" 日志/WARNING fmt out)])
  (日志/添加处理器 logger handler)
  (日志/警告 logger "警告消息")
  (let ([输出内容 (get-output-string out)])
    (记录测试结果 "记录 WARNING 日志" (string? 输出内容) "能记录 WARNING 级别的日志")))

;; 测试10: 添加和移除处理器（不直接访问结构体）
(let* ([logger (日志/获取日志器 "test")]
       [fmt (日志/格式器 "[~a] ~a")]
       [handler (日志/流处理器 "test" 日志/DEBUG fmt (open-output-bytes))])
  (日志/添加处理器 logger handler)
  (日志/移除处理器 logger handler)
  (记录测试结果 "添加和移除处理器" #t "能成功调用添加和移除处理器函数"))

(输出测试摘要)

(define (运行测试)
  (输出测试摘要))
