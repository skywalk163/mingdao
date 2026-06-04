#lang racket/base
;; 快速检查随机范围函数的参数顺序
(require racket/string racket/path racket/list racket/port racket/file racket/random
         (file "../../lang/tokenizer.rkt")
         (file "../../lang/parser.rkt"))

(define script-dir (path-only (path->complete-path (find-system-path 'run-file) (current-directory))))
(current-directory (build-path script-dir ".." ".."))

(define ns (make-base-empty-namespace))
(namespace-require 'racket/base ns)

;; 加载核心模块
(eval '(require (file "core.rkt") racket/random racket/control) ns)

;; 加载 helper 模块（定义随机范围）
(define helper-path (build-path (current-directory) "examples/plane-shooter/helper.mingdao"))
(define helper-code (port->string (open-input-file helper-path)))
(define helper-tokens (tokenize helper-code))
;; 需要函数名注册：随机范围，随机整数
(eval '(define (随机整数 min max)
         (+ min (random (- max min -1)))) ns)
(define helper-ast (parse helper-tokens '("随机范围" "随机整数")))
(for ([expr helper-ast]) (eval expr ns))

(printf "\n=== 检查 随机范围 参数顺序 ===\n")
(printf "函数定义: 随机范围 hi lo 返回 随机整数 lo hi\n")
(printf "调用 (随机范围 1 30): ")
(define v1 (eval '(随机范围 1 30) ns))
(printf "~a\n" v1)

(printf "调用 (随机范围 100 660): ")
(define v2 (eval '(随机范围 100 660) ns))
(printf "~a\n" v2)

(printf "\n=== 关键问题 ===\n")
(printf "调用 (随机范围 1 30) → hi=1, lo=30 → 随机整数(30, 1)\n")
(printf "随机整数(30, 1) = (+ 30 (random (- 1 30 -1))) = (+ 30 (random -28))\n")
(printf "random 需要正数参数，-28 会导致错误!\n")

(printf "\n=== 诊断完毕 ===\n")