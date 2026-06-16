#lang racket/base

;; 清单解析模块测试

(require racket/base
         rackunit
         (file "../manifest.rkt")
         (file "../version.rkt"))

(displayln "=== 清单解析模块测试 ===\n")

;; ==================== 创建清单测试 ====================

(displayln "--- 创建清单测试 ---")

(define test-manifest
  (make-package-manifest
   #:name "my-package"
   #:version (make-version 1 0 0)
   #:authors '("Alice" "Bob")
   #:description "A test package"
   #:dependencies
   (list (make-dependency #:name "json" #:version (parse-constraint "^2.0.0"))
         (make-dependency #:name "logger"))
   #:dev-dependencies
   (list (make-dependency #:name "test" #:version (parse-constraint ">=1.0.0")))
   #:license "MIT"
   #:repository "https://github.com/example/my-package"))

(check-equal? (package-manifest-name test-manifest) "my-package" "清单名称")
(check-equal? (version->string (package-manifest-version test-manifest)) "1.0.0" "清单版本")
(check-equal? (package-manifest-authors test-manifest) '("Alice" "Bob") "清单作者")
(check-equal? (package-manifest-description test-manifest) "A test package" "清单描述")
(check-equal? (length (package-manifest-dependencies test-manifest)) 2 "依赖数量")
(check-equal? (length (package-manifest-dev-dependencies test-manifest)) 1 "开发依赖数量")
(check-equal? (package-manifest-license test-manifest) "MIT" "清单许可")
(check-equal? (package-manifest-repository test-manifest) "https://github.com/example/my-package" "清单仓库")

(displayln "创建清单测试通过!\n")

;; ==================== 创建依赖测试 ====================

(displayln "--- 创建依赖测试 ---")

(define test-dep (make-dependency
                  #:name "json"
                  #:version (parse-constraint "^2.0.0")
                  #:optional #t))

(check-equal? (dependency-name test-dep) "json" "依赖名称")
(check-equal? (dependency-version test-dep) (parse-constraint "^2.0.0") "依赖版本约束")
(check-true (dependency-optional test-dep) "依赖可选标记")
(check-false (dependency-git test-dep) "依赖无 git 源")

(define git-dep (make-dependency
                 #:name "ext-lib"
                 #:git "https://github.com/example/ext-lib.git"
                 #:tag "v1.0.0"))

(check-equal? (dependency-name git-dep) "ext-lib" "git 依赖名称")
(check-equal? (dependency-git git-dep) "https://github.com/example/ext-lib.git" "git 依赖源")
(check-equal? (dependency-tag git-dep) "v1.0.0" "git 依赖标签")

(displayln "创建依赖测试通过!\n")

;; ==================== 解析依赖测试 ====================

(displayln "--- 解析依赖测试 ---")

;; 解析字符串格式依赖
(define str-dep (parse-dependency "json ^2.0"))
(check-equal? (dependency-name str-dep) "json" "解析字符串依赖名称")
(check-equal? (dependency-version str-dep) (parse-constraint "^2.0.0") "解析字符串依赖版本")

;; 解析仅名称的依赖
(define name-only-dep (parse-dependency "logger"))
(check-equal? (dependency-name name-only-dep) "logger" "仅名称依赖")
(check-false (dependency-version name-only-dep) "仅名称依赖无版本")

;; 解析哈希表格式依赖
(define hash-dep (parse-dependency (hasheq 'name "json" 'version "^2.0")))
(check-equal? (dependency-name hash-dep) "json" "解析哈希表依赖名称")
(check-equal? (dependency-version hash-dep) (parse-constraint "^2.0.0") "解析哈希表依赖版本")

;; 解析带可选标记的哈希表依赖
(define opt-dep (parse-dependency (hasheq 'name "optional-dep" 'optional #t)))
(check-equal? (dependency-name opt-dep) "optional-dep" "可选依赖名称")
(check-true (dependency-optional opt-dep) "可选依赖标记")

(displayln "解析依赖测试通过!\n")

;; ==================== 解析清单测试 ====================

(displayln "--- 解析清单测试 ---")

(define ht (hasheq 'name "test-pkg"
                   'version "2.1.0"
                   'authors '("Author 1" "Author 2")
                   'description "Test description"
                   'dependencies '("json ^1.0" "cli >=1.0.0")
                   'dev-dependencies '("test ~1.0")
                   'license "Apache-2.0"
                   'repository "https://github.com/test/test-pkg"))

(define parsed (parse-manifest ht))

(check-equal? (package-manifest-name parsed) "test-pkg" "解析清单名称")
(check-equal? (version->string (package-manifest-version parsed)) "2.1.0" "解析清单版本")
(check-equal? (length (package-manifest-dependencies parsed)) 2 "解析清单依赖数量")
(check-equal? (length (package-manifest-dev-dependencies parsed)) 1 "解析清单开发依赖数量")

(displayln "解析清单测试通过!\n")

;; ==================== 序列化清单测试 ====================

(displayln "--- 序列化清单测试 ---")

(define ser (serialize-manifest test-manifest))

(check-equal? (hash-ref ser 'name) "my-package" "序列化清单名称")
(check-equal? (hash-ref ser 'version) "1.0.0" "序列化清单版本")
(check-true (list? (hash-ref ser 'dependencies)) "序列化依赖为列表")

(displayln "序列化清单测试通过!\n")

;; ==================== 依赖版本约束测试 ====================

(displayln "--- 依赖版本约束测试 ---")

(define caret-dep (parse-dependency "json ^2.0"))
(define tilde-dep (parse-dependency "json ~1.5"))
(define exact-dep (parse-dependency "json 1.0.0"))
(define gte-dep (parse-dependency "json >=1.0.0"))

(check-equal? (dependency-version caret-dep) (parse-constraint "^2.0.0") "caret 约束解析")
(check-equal? (dependency-version tilde-dep) (parse-constraint "~1.5.0") "tilde 约束解析")
(check-equal? (dependency-version exact-dep) (parse-constraint "1.0.0") "exact 约束解析")
(check-equal? (dependency-version gte-dep) (parse-constraint ">=1.0.0") "gte 约束解析")

;; 验证约束匹配
(check-true (matches-constraint? (make-version 2 0 0) (dependency-version caret-dep)) "^2.0 匹配 2.0.0")
(check-true (matches-constraint? (make-version 2 9 9) (dependency-version caret-dep)) "^2.0 匹配 2.9.9")
(check-false (matches-constraint? (make-version 3 0 0) (dependency-version caret-dep)) "^2.0 不匹配 3.0.0")

(displayln "依赖版本约束测试通过!\n")

(displayln "=== 所有测试通过! ===")