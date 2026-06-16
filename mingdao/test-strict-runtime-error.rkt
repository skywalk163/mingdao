#lang racket/base
(require "core/types.rkt")

;; 确保严格模式开启
(enable-strict-runtime!)

(printf "测试严格模式下的类型断言失败...~n")

;; 这应该抛出异常
(with-handlers ([exn:fail? (lambda (e)
                              (printf "正确捕获异常: ~a~n" (exn-message e))
                              (printf "测试通过！~n"))])
  (断言类型 123 '字符串)
  (printf "错误：应该抛出异常但没有抛出！~n"))
