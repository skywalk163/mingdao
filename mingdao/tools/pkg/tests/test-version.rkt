#lang racket/base

;; 版本处理模块测试

(require racket/base
         rackunit
         (file "../version.rkt"))

(displayln "=== 版本处理模块测试 ===\n")

;; ==================== 版本解析测试 ====================

(displayln "--- 版本解析测试 ---")

;; 基本版本解析
(check-equal? (parse-version "1.2.3")
              (make-version 1 2 3)
              "解析基本版本 1.2.3")

(check-equal? (parse-version "0.0.1")
              (make-version 0 0 1)
              "解析版本 0.0.1")

(check-equal? (parse-version "100.200.300")
              (make-version 100 200 300)
              "解析大版本号")

;; 带预发布标签
(check-equal? (parse-version "1.2.3-alpha")
              (make-version 1 2 3 "alpha")
              "解析带预发布标签版本")

(check-equal? (parse-version "1.2.3-alpha.1")
              (make-version 1 2 3 "alpha.1")
              "解析带点号的预发布标签")

(check-equal? (parse-version "1.0.0-rc1")
              (make-version 1 0 0 "rc1")
              "解析 rc 预发布")

;; 带构建元数据
(check-equal? (parse-version "1.2.3+build.123")
              (make-version 1 2 3 #f "build.123")
              "解析带构建元数据版本")

;; 同时带预发布和构建元数据
(check-equal? (parse-version "1.2.3-alpha+build.123")
              (make-version 1 2 3 "alpha" "build.123")
              "解析带预发布和构建元数据")

(displayln "版本解析测试通过!\n")

;; ==================== 版本比较测试 ====================

(displayln "--- 版本比较测试 ---")

;; 基本比较
(check-eq? (version-compare (make-version 1 0 0) (make-version 2 0 0))
           'less
           "1.0.0 < 2.0.0")

(check-eq? (version-compare (make-version 2 0 0) (make-version 1 0 0))
           'greater
           "2.0.0 > 1.0.0")

(check-eq? (version-compare (make-version 1 0 0) (make-version 1 0 0))
           'equal
           "1.0.0 = 1.0.0")

;; 次版本比较
(check-eq? (version-compare (make-version 1 1 0) (make-version 1 2 0))
           'less
           "1.1.0 < 1.2.0")

(check-eq? (version-compare (make-version 1 2 0) (make-version 1 1 0))
           'greater
           "1.2.0 > 1.1.0")

;; 补丁版本比较
(check-eq? (version-compare (make-version 1 0 1) (make-version 1 0 2))
           'less
           "1.0.1 < 1.0.2")

(check-eq? (version-compare (make-version 1 0 2) (make-version 1 0 1))
           'greater
           "1.0.2 > 1.0.1")

;; 预发布版本比较
(check-eq? (version-compare (make-version 1 0 0 "alpha") (make-version 1 0 0 "beta"))
           'less
           "alpha < beta")

(check-eq? (version-compare (make-version 1 0 0 "alpha") (make-version 1 0 0))
           'less
           "1.0.0-alpha < 1.0.0")

(check-eq? (version-compare (make-version 1 0 0) (make-version 1 0 0 "alpha"))
           'greater
           "1.0.0 > 1.0.0-alpha")

;; 预发布数字比较
(check-eq? (version-compare (make-version 1 0 0 "alpha.1") (make-version 1 0 0 "alpha.2"))
           'less
           "alpha.1 < alpha.2")

(check-eq? (version-compare (make-version 1 0 0 "alpha.10") (make-version 1 0 0 "alpha.2"))
           'greater
           "alpha.10 > alpha.2 (数字比较)")

;; 比较函数
(check-true (version<? (make-version 1 0 0) (make-version 2 0 0)) "version<?")
(check-true (version<=? (make-version 1 0 0) (make-version 1 0 0)) "version<=?")
(check-true (version=? (make-version 1 0 0) (make-version 1 0 0)) "version=?")
(check-true (version>=? (make-version 2 0 0) (make-version 1 0 0)) "version>=?")
(check-true (version>? (make-version 2 0 0) (make-version 1 0 0)) "version>?")

(displayln "版本比较测试通过!\n")

;; ==================== 约束解析测试 ====================

(displayln "--- 约束解析测试 ---")

(check-eq? (version-constraint-op (parse-constraint "1.0.0")) 'exact "exact 操作符")
(check-eq? (version-constraint-op (parse-constraint "=1.0.0")) 'exact "= 操作符")
(check-eq? (version-constraint-op (parse-constraint "^1.0.0")) 'caret "caret 操作符")
(check-eq? (version-constraint-op (parse-constraint "~1.0.0")) 'tilde "tilde 操作符")
(check-eq? (version-constraint-op (parse-constraint ">=1.0.0")) 'gte "gte 操作符")
(check-eq? (version-constraint-op (parse-constraint "<=1.0.0")) 'lte "lte 操作符")
(check-eq? (version-constraint-op (parse-constraint ">1.0.0")) 'gt "gt 操作符")
(check-eq? (version-constraint-op (parse-constraint "<1.0.0")) 'lt "lt 操作符")

(check-equal? (version-constraint-version (parse-constraint ">=1.2.3"))
              (make-version 1 2 3)
              "约束版本解析")

(displayln "约束解析测试通过!\n")

;; ==================== 约束匹配测试 ====================

(displayln "--- 约束匹配测试 ---")

;; Exact 匹配
(check-true (matches-constraint? (make-version 1 0 0) (parse-constraint "1.0.0")) "exact 匹配 1.0.0")
(check-false (matches-constraint? (make-version 1 0 1) (parse-constraint "1.0.0")) "exact 不匹配 1.0.1")
(check-false (matches-constraint? (make-version 2 0 0) (parse-constraint "1.0.0")) "exact 不匹配 2.0.0")

;; Caret 匹配
(check-true (matches-constraint? (make-version 1 0 0) (parse-constraint "^1.0.0")) "^1.0.0 匹配 1.0.0")
(check-true (matches-constraint? (make-version 1 9 9) (parse-constraint "^1.0.0")) "^1.0.0 匹配 1.9.9")
(check-false (matches-constraint? (make-version 2 0 0) (parse-constraint "^1.0.0")) "^1.0.0 不匹配 2.0.0")
(check-false (matches-constraint? (make-version 0 9 9) (parse-constraint "^1.0.0")) "^1.0.0 不匹配 0.9.9")

(check-true (matches-constraint? (make-version 1 2 3) (parse-constraint "^1.2.3")) "^1.2.3 匹配 1.2.3")
(check-true (matches-constraint? (make-version 1 9 9) (parse-constraint "^1.2.3")) "^1.2.3 匹配 1.9.9")
(check-false (matches-constraint? (make-version 2 0 0) (parse-constraint "^1.2.3")) "^1.2.3 不匹配 2.0.0")

;; Tilde 匹配
(check-true (matches-constraint? (make-version 1 2 3) (parse-constraint "~1.2.3")) "~1.2.3 匹配 1.2.3")
(check-true (matches-constraint? (make-version 1 2 9) (parse-constraint "~1.2.3")) "~1.2.3 匹配 1.2.9")
(check-false (matches-constraint? (make-version 1 3 0) (parse-constraint "~1.2.3")) "~1.2.3 不匹配 1.3.0")
(check-false (matches-constraint? (make-version 2 0 0) (parse-constraint "~1.2.3")) "~1.2.3 不匹配 2.0.0")

(check-true (matches-constraint? (make-version 1 2 0) (parse-constraint "~1.2.0")) "~1.2.0 匹配 1.2.0")
(check-true (matches-constraint? (make-version 1 2 9) (parse-constraint "~1.2.0")) "~1.2.0 匹配 1.2.9")
(check-false (matches-constraint? (make-version 1 3 0) (parse-constraint "~1.2.0")) "~1.2.0 不匹配 1.3.0")

;; GTE 匹配
(check-true (matches-constraint? (make-version 1 0 0) (parse-constraint ">=1.0.0")) ">=1.0.0 匹配 1.0.0")
(check-true (matches-constraint? (make-version 2 0 0) (parse-constraint ">=1.0.0")) ">=1.0.0 匹配 2.0.0")
(check-false (matches-constraint? (make-version 0 9 9) (parse-constraint ">=1.0.0")) ">=1.0.0 不匹配 0.9.9")

;; LTE 匹配
(check-true (matches-constraint? (make-version 1 0 0) (parse-constraint "<=1.0.0")) "<=1.0.0 匹配 1.0.0")
(check-true (matches-constraint? (make-version 0 9 9) (parse-constraint "<=1.0.0")) "<=1.0.0 匹配 0.9.9")
(check-false (matches-constraint? (make-version 2 0 0) (parse-constraint "<=1.0.0")) "<=1.0.0 不匹配 2.0.0")

;; GT 匹配
(check-true (matches-constraint? (make-version 2 0 0) (parse-constraint ">1.0.0")) ">1.0.0 匹配 2.0.0")
(check-false (matches-constraint? (make-version 1 0 0) (parse-constraint ">1.0.0")) ">1.0.0 不匹配 1.0.0")

;; LT 匹配
(check-true (matches-constraint? (make-version 0 9 9) (parse-constraint "<1.0.0")) "<1.0.0 匹配 0.9.9")
(check-false (matches-constraint? (make-version 1 0 0) (parse-constraint "<1.0.0")) "<1.0.0 不匹配 1.0.0")

(displayln "约束匹配测试通过!\n")

;; ==================== 格式化输出测试 ====================

(displayln "--- 格式化输出测试 ---")

(check-equal? (version->string (make-version 1 2 3)) "1.2.3" "基本版本格式化")
(check-equal? (version->string (make-version 1 2 3 "alpha")) "1.2.3-alpha" "带预发布格式化")
(check-equal? (version->string (make-version 1 2 3 #f "build.123")) "1.2.3+build.123" "带构建元数据格式化")
(check-equal? (version->string (make-version 1 2 3 "alpha" "build.123")) "1.2.3-alpha+build.123" "完整版本格式化")

(check-equal? (constraint->string (parse-constraint "1.0.0")) "=1.0.0" "exact 约束格式化")
(check-equal? (constraint->string (parse-constraint "^1.0.0")) "^1.0.0" "caret 约束格式化")
(check-equal? (constraint->string (parse-constraint "~1.0.0")) "~1.0.0" "tilde 约束格式化")
(check-equal? (constraint->string (parse-constraint ">=1.0.0")) ">=1.0.0" "gte 约束格式化")

(displayln "格式化输出测试通过!\n")

(displayln "=== 所有测试通过! ===")
