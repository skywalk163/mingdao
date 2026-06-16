#lang racket/base
(require "core/types.rkt")

;; 测试严格模式开关
(printf "*strict-runtime-mode* = ~a~n" *strict-runtime-mode*)
(enable-strict-runtime!)
(printf "启用后 *strict-runtime-mode* = ~a~n" *strict-runtime-mode*)
(disable-strict-runtime!)
(printf "禁用后 *strict-runtime-mode* = ~a~n" *strict-runtime-mode*)

;; 测试断言类型（严格模式下应该抛出异常）
(printf "~n--- 测试断言类型 ---~n")
(断言类型 42 '整数)
(printf "断言类型 42 '整数 通过~n")
(断言类型 3.14 '浮点数)
(printf "断言类型 3.14 '浮点数 通过~n")
(断言类型 "hello" '字符串)
(printf "断言类型 \"hello\" '字符串 通过~n")

;; 测试安全转换
(printf "~n--- 测试安全转换 ---~n")
(安全转整数 100)
(printf "安全转整数 100 通过~n")
(安全转浮点数 2.718)
(printf "安全转浮点数 2.718 通过~n")

;; 测试严格模式关闭后不检查
(disable-strict-runtime!)
(断言类型 123 '字符串)  ;; 应该不抛异常
(printf "禁用严格模式后，断言类型 123 '字符串 不抛异常~n")

(printf "~n所有测试通过！~n")
