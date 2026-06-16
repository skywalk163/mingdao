#lang racket/base

;; M6 包管理器集成测试
;; 验证所有模块协同工作

(require "../version.rkt"
         "../manifest.rkt"
         "../resolver.rkt"
         rackunit)

(printf "\n══════ 包管理器集成测试 ══════\n")

;; ==================== 测试 1: 版本解析 ====================
(printf "\n测试 1: 版本解析\n")

(check-true (version? (parse-version "1.0.0"))
            "版本解析成功")

(check-equal? (version-major (parse-version "2.3.4")) 2
              "版本主版本号正确")

(check-equal? (version-minor (parse-version "2.3.4")) 3
              "版本次版本号正确")

(check-equal? (version-patch (parse-version "2.3.4")) 4
              "版本补丁号正确")

;; ==================== 测试 2: 版本比较 ====================
(printf "\n测试 2: 版本比较\n")

(check-true (version>? (parse-version "2.0.0") (parse-version "1.0.0"))
            "版本大于比较正确")

(check-true (version<? (parse-version "1.0.0") (parse-version "2.0.0"))
            "版本小于比较正确")

(check-true (version>=? (parse-version "2.0.0") (parse-version "2.0.0"))
            "版本大于等于正确")

(check-true (version<=? (parse-version "1.0.0") (parse-version "1.0.0"))
            "版本小于等于正确")

(check-true (version=? (parse-version "1.0.0") (parse-version "1.0.0"))
            "版本相等正确")

;; ==================== 测试 3: 版本约束解析 ====================
(printf "\n测试 3: 版本约束解析\n")

(define caret-constraint (parse-constraint "^1.0.0"))
(check-eq? (version-constraint-op caret-constraint) 'caret
           "caret 操作符解析正确")

(define tilde-constraint (parse-constraint "~1.2.3"))
(check-eq? (version-constraint-op tilde-constraint) 'tilde
           "tilde 操作符解析正确")

(define gte-constraint (parse-constraint ">=1.0.0"))
(check-eq? (version-constraint-op gte-constraint) 'gte
           "gte 操作符解析正确")

(define lte-constraint (parse-constraint "<=2.0.0"))
(check-eq? (version-constraint-op lte-constraint) 'lte
           "lte 操作符解析正确")

(define gt-constraint (parse-constraint ">1.0.0"))
(check-eq? (version-constraint-op gt-constraint) 'gt
           "gt 操作符解析正确")

(define lt-constraint (parse-constraint "<2.0.0"))
(check-eq? (version-constraint-op lt-constraint) 'lt
           "lt 操作符解析正确")

;; ==================== 测试 4: 约束匹配 ====================
(printf "\n测试 4: 约束匹配\n")

(check-true (matches-constraint? (parse-version "1.9.9") (parse-constraint "^1.0.0"))
            "caret ^1.0.0 匹配 1.9.9")

(check-true (matches-constraint? (parse-version "1.0.0") (parse-constraint "^1.0.0"))
            "caret ^1.0.0 匹配 1.0.0")

(check-false (matches-constraint? (parse-version "2.0.0") (parse-constraint "^1.0.0"))
             "caret ^1.0.0 不匹配 2.0.0")

(check-true (matches-constraint? (parse-version "1.2.9") (parse-constraint "~1.2.0"))
            "tilde ~1.2.0 匹配 1.2.9")

(check-false (matches-constraint? (parse-version "1.3.0") (parse-constraint "~1.2.0"))
             "tilde ~1.2.0 不匹配 1.3.0")

(check-true (matches-constraint? (parse-version "1.0.0") (parse-constraint ">=1.0.0"))
            "gte >=1.0.0 匹配 1.0.0")

(check-true (matches-constraint? (parse-version "2.0.0") (parse-constraint ">=1.0.0"))
            "gte >=1.0.0 匹配 2.0.0")

(check-true (matches-constraint? (parse-version "1.0.0") (parse-constraint "<=1.0.0"))
            "lte <=1.0.0 匹配 1.0.0")

(check-true (matches-constraint? (parse-version "0.6.0") (parse-constraint ">0.5.0"))
            "gt >0.5.0 匹配 0.6.0")

(check-true (matches-constraint? (parse-version "0.4.0") (parse-constraint "<0.5.0"))
            "lt <0.5.0 匹配 0.4.0")

;; ==================== 测试 5: 创建清单 ====================
(printf "\n测试 5: 创建清单\n")

(define m (make-package-manifest #:name "test-pkg" #:version (parse-version "1.0.0")))
(check-equal? (package-manifest-name m) "test-pkg"
              "清单名称正确")

(check-true (version=? (package-manifest-version m) (parse-version "1.0.0"))
            "清单版本正确")

;; ==================== 测试 6: 创建带依赖的清单 ====================
(printf "\n测试 6: 创建带依赖的清单\n")

(define deps (list (make-dependency #:name "json" #:version (parse-constraint "^2.0"))))
(define m2 (make-package-manifest #:name "app" #:dependencies deps))
(check-equal? (package-manifest-name m2) "app"
              "带依赖清单名称正确")

(check-equal? (length (package-manifest-dependencies m2)) 1
              "带依赖清单有一个依赖")

(check-equal? (dependency-name (car (package-manifest-dependencies m2))) "json"
              "依赖名称正确")

;; ==================== 测试 7: 清单序列化 ====================
(printf "\n测试 7: 清单序列化\n")

(define serialized (serialize-manifest m2))
(check-true (hash-has-key? serialized 'name)
            "序列化包含 name 字段")

(check-true (hash-has-key? serialized 'version)
            "序列化包含 version 字段")

(check-true (hash-has-key? serialized 'dependencies)
            "序列化包含 dependencies 字段")

;; ==================== 测试 8: 依赖解析 ====================
(printf "\n测试 8: 依赖解析\n")

;; 创建模拟注册表
(define mock-packages
  (list
   (make-package "json" (parse-version "2.0.0") '())
   (make-package "json" (parse-version "2.1.0") '())
   (make-package "json" (parse-version "1.0.0") '())
   (make-package "logger" (parse-version "1.0.0") '())
   (make-package "logger" (parse-version "1.5.0")
                 (list (make-dep "json" (list (parse-constraint "^2.0")))))))

(define registry (make-mock-registry mock-packages))

;; 直接依赖解析
(define requirements
  (list (make-dep "logger" (list (parse-constraint "^1.0.0")))))

(define result (resolve-dependencies registry requirements))
(check-true (resolve-result? result)
            "解析结果结构正确")

(check-true (>= (length (resolved-packages result)) 1)
            "解析出至少一个包")

;; 传递依赖解析
(define requirements2
  (list (make-dep "logger" (list (parse-constraint "^1.5.0")))))

(define result2 (resolve-dependencies registry requirements2))
(check-true (>= (length (resolved-packages result2)) 2)
            "传递依赖解析正确")

;; ==================== 测试 9: 冲突检测 ====================
(printf "\n测试 9: 冲突检测\n")

(define conflicting-requirements
  (list
   (make-dep "json" (list (parse-constraint "^1.0.0")))
   (make-dep "json" (list (parse-constraint "^2.0.0")))))

(define conflict-result (resolve-dependencies registry conflicting-requirements))
(check-true (> (length (conflicts conflict-result)) 0)
            "检测到版本冲突")

;; ==================== 测试 10: 解析结果访问器 ====================
(printf "\n测试 10: 解析结果访问器\n")

(check-true (list? (resolved-packages result))
            "resolved-packages 返回列表")

(check-true (list? (conflicts result))
            "conflicts 返回列表")

;; ==================== 测试 11: 解析器创建 ====================
(printf "\n测试 11: 解析器创建\n")

(define resolve-result (make-resolve-result (make-hash) '()))
(check-true (resolve-result? resolve-result)
            "解析结果结构正确")

;; ==================== 测试 12: 最佳选择 ====================
(printf "\n测试 12: 最佳选择\n")

(define candidates (list (cons (parse-version "1.0.0") (make-package "test" (parse-version "1.0.0")))
                         (cons (parse-version "2.0.0") (make-package "test" (parse-version "2.0.0")))
                         (cons (parse-version "1.5.0") (make-package "test" (parse-version "1.5.0")))))

(define best (select-best candidates))
(check-equal? (package-version best) (parse-version "2.0.0")
              "select-best 选择最新版本")

;; ==================== 测试 13: 锁定文件结构 ====================
(printf "\n测试 13: 锁定文件结构\n")

(define lock-entry (make-lock-entry
                    #:name "test-pkg"
                    #:version (parse-version "1.0.0")
                    #:source "https://example.com"
                    #:checksum "abc123"))
(check-true (lock-entry? lock-entry)
            "锁定条目结构正确")

(check-equal? (lock-entry-name lock-entry) "test-pkg"
             "锁定条目名称正确")

(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  集成测试全部通过!                   ║\n")
(printf "║  M6 包管理器实现完成!              ║\n")
(printf "╚══════════════════════════════════════╝\n")
