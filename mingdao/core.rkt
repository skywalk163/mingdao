#lang racket/base

;; 明道语言核心库 - 模块聚合入口
;; 整合所有子模块，提供统一的导出接口

(require "core/base.rkt"
         "core/types.rkt"
         "core/oop.rkt"
         "core/async.rkt"
         "core/error.rkt"
         "core/keywords.rkt")

;; 重新导出所有子模块的内容，保持向后兼容性
(provide
 ;; 从 base.rkt 导出
 (all-from-out "core/base.rkt")
 ;; 从 types.rkt 导出
 (all-from-out "core/types.rkt")
 ;; 从 oop.rkt 导出
 (all-from-out "core/oop.rkt")
 ;; 从 async.rkt 导出
 (all-from-out "core/async.rkt")
 ;; 从 error.rkt 导出
 (all-from-out "core/error.rkt")
 ;; 从 keywords.rkt 导出
 (all-from-out "core/keywords.rkt"))