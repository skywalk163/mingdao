#lang racket/base

;; 依赖解析器测试

(require racket/base
         rackunit
         (file "../version.rkt")
         (file "../resolver.rkt"))

(displayln "=== 依赖解析器测试 ===\n")

;; ==================== 辅助函数测试 ====================

(displayln "--- 候选查找测试 ---")

;; 创建测试用注册表
(define test-registry
  (make-mock-registry
   (list
    (make-basic-package "foo" (make-version 1 0 0) '())
    (make-basic-package "foo" (make-version 1 1 0) '())
    (make-basic-package "foo" (make-version 2 0 0) '())
    (make-basic-package "bar" (make-version 0 9 0) '())
    (make-basic-package "bar" (make-version 1 0 0) '())
    (make-basic-package "baz" (make-version 1 5 0)
                        (list (make-dep "foo" (list (parse-constraint "^1.0.0"))))))))

;; 测试查找候选版本
(define foo-candidates (find-candidates test-registry "foo" (parse-constraint ">=1.0.0")))
(check-equal? (length foo-candidates) 3 "找到 3 个满足 >=1.0.0 的 foo 版本")
(check-true (ormap (lambda (v) (version=? v (make-version 1 0 0))) (map car foo-candidates)) "包含 1.0.0")
(check-true (ormap (lambda (v) (version=? v (make-version 1 1 0))) (map car foo-candidates)) "包含 1.1.0")
(check-true (ormap (lambda (v) (version=? v (make-version 2 0 0))) (map car foo-candidates)) "包含 2.0.0")

(define foo-exact-candidates (find-candidates test-registry "foo" (parse-constraint "=1.0.0")))
(check-equal? (length foo-exact-candidates) 1 "精确匹配 1.0.0")
(check-true (version=? (caar foo-exact-candidates) (make-version 1 0 0)) "版本为 1.0.0")

(define foo-caret-candidates (find-candidates test-registry "foo" (parse-constraint "^1.0.0")))
(check-equal? (length foo-caret-candidates) 2 "^1.0.0 匹配 1.0.0 和 1.1.0")

(check-true (null? (find-candidates test-registry "nonexist" (parse-constraint ">=1.0.0")))
            "不存在的包返回空列表")

(displayln "候选查找测试通过!\n")

;; ==================== 最佳选择测试 ====================

(displayln "--- 选择最新版本测试 ---")

(check-eq? (select-best '()) #f "空候选返回 #f")

(define foo-latest (select-best foo-candidates))
(check-true (package? foo-latest) "返回包结构")
(check-true (version=? (package-version foo-latest) (make-version 2 0 0))
            "选择最新版本 2.0.0")

(define foo-caret-latest (select-best foo-caret-candidates))
(check-true (version=? (package-version foo-caret-latest) (make-version 1 1 0))
            "^1.0.0 选择 1.1.0")

(displayln "选择最新版本测试通过!\n")

;; ==================== 完整解析流程测试 ====================

(displayln "--- 完整解析流程测试 ---")

;; 创建带传递依赖的注册表
(define transitive-registry
  (make-mock-registry
   (list
    ;; bar 1.0.0 依赖 foo ^1.0.0
    (make-basic-package "bar" (make-version 1 0 0)
                        (list (make-dep "foo" (list (parse-constraint "^1.0.0")))))
    ;; bar 0.9.0 依赖 foo ^0.9.0
    (make-basic-package "bar" (make-version 0 9 0)
                        (list (make-dep "foo" (list (parse-constraint "^0.9.0")))))
    ;; foo 1.5.0
    (make-basic-package "foo" (make-version 1 5 0) '())
    ;; foo 1.0.0
    (make-basic-package "foo" (make-version 1 0 0) '())
    ;; foo 0.9.0
    (make-basic-package "foo" (make-version 0 9 0) '())
    ;; myapp 直接依赖 bar ^1.0.0
    (make-basic-package "myapp" (make-version 1 0 0)
                        (list (make-dep "bar" (list (parse-constraint "^1.0.0"))))))))

;; 测试解析 myapp 的依赖
(define myapp-dep (make-dep "myapp" (list (parse-constraint ">=1.0.0"))))
(define bar-dep (make-dep "bar" (list (parse-constraint "^1.0.0"))))

;; 测试解析 bar ^1.0.0
(define bar-result (resolve-dependencies transitive-registry (list bar-dep)))
(define bar-packages (resolved-packages bar-result))
(check-equal? (length bar-packages) 2 "bar ^1.0.0 解析出 2 个包 (bar + foo)")
(check-true (ormap (lambda (n) (equal? n "bar")) (map package-name bar-packages)) "包含 bar")
(check-true (ormap (lambda (n) (equal? n "foo")) (map package-name bar-packages)) "包含 foo")
(check-true (null? (unresolved-deps bar-result)) "没有未解析的依赖")

;; 验证版本: bar 应该是 1.0.0 (最新满足 ^1.0.0)
(let ([bar-pkg (findf (lambda (p) (equal? (package-name p) "bar")) bar-packages)])
  (check-true (version=? (package-version bar-pkg) (make-version 1 0 0))
              "bar 版本为 1.0.0"))
;; 验证 foo 版本: 应该是 1.5.0 (满足 ^1.0.0 的最新版本)
(let ([foo-pkg (findf (lambda (p) (equal? (package-name p) "foo")) bar-packages)])
  (check-true (version=? (package-version foo-pkg) (make-version 1 5 0))
              "foo 版本为 1.5.0"))

(displayln "完整解析流程测试通过!\n")

;; ==================== 冲突检测测试 ====================

(displayln "--- 冲突检测测试 ---")

;; 创建有冲突的注册表
(define conflict-registry
  (make-mock-registry
   (list
    (make-basic-package "pkg" (make-version 1 0 0) '())
    (make-basic-package "pkg" (make-version 2 0 0) '()))))

;; 请求精确版本 1.0.0 但注册表有更高版本
(define conflict-result
  (resolve-dependencies conflict-registry
                        (list (make-dep "pkg" (list (parse-constraint "=1.0.0"))))))
(check-equal? (length (resolved-packages conflict-result)) 1 "解析出 1 个包")
(check-true (null? (conflicts conflict-result)) "没有冲突 (=1.0.0 精确匹配)")

;; 测试不存在的依赖
(define missing-result
  (resolve-dependencies test-registry
                        (list (make-dep "nonexistent" (list (parse-constraint ">=1.0.0"))))))
(check-true (null? (resolved-packages missing-result)) "不存在的包没有解析结果")
(check-equal? (length (conflicts missing-result)) 1 "有 1 个冲突记录")

(displayln "冲突检测测试通过!\n")

;; ==================== 解析结果结构测试 ====================

(displayln "--- 解析结果结构测试 ---")

(define result (resolve-dependencies transitive-registry (list bar-dep)))
(check-true (resolve-result? result) "返回 resolve-result 结构")
(check-true (list? (resolved-packages result)) "resolved-packages 是列表")
(check-true (list? (conflicts result)) "conflicts 是列表")

(check-exn exn:fail? (lambda () (make-resolve-result "not" "a" "list"))
           "无效参数抛出异常")

(displayln "解析结果结构测试通过!\n")

(displayln "=== 所有测试通过! ===")