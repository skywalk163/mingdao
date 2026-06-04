#lang racket/base

;; 明道语言主入口模块
;; 支持完整加载和按需加载两种模式

(require "core.rkt"
         "runtime.rkt"
         "lang/debug.rkt"
         "lang/test.rkt"
         "lang/tokenizer.rkt"
         "lang/parser.rkt"
         "lang/reader.rkt"
         "lazy-load.rkt"
         racket/control
         racket/port
         racket/file
         racket/string
         racket/path)

(provide (all-from-out racket/base)
         (all-from-out "core.rkt")
         (all-from-out "lang/debug.rkt")
         (all-from-out "lang/test.rkt")
         (all-from-out "lang/reader.rkt")
         (all-from-out "lazy-load.rkt")
         (all-from-out "runtime.rkt")
         (all-from-out racket/control))

;; 默认情况下不自动加载标准库，由用户按需加载
;; 使用 (加载所有标准库) 加载全部
;; 使用 (加载模块 "模块名") 加载单个模块