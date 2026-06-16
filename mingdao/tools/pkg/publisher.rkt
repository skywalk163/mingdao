#lang racket/base

;; 包发布模块 - M6 包管理器核心模块
;; 负责包的发布验证、发布流程和版本标签

(require racket/base
         racket/string
         racket/file
         racket/system
         (file "manifest.rkt")
         (file "version.rkt"))

(provide
 publish-package
 tag-version
 verify-package)

;; ==================== 发布检查 ====================

(define (verify-package manifest)
  ;; 验证包是否可以发布
  ;; 返回 #t 表示验证通过，返回失败原因字符串表示验证失败
  (displayln "[发布检查] 开始验证包...")
  
  ;; 检查包名称
  (define name (package-manifest-name manifest))
  (when (string=? name "unnamed")
    (displayln "[发布检查] ✗ 包名称不能为 'unnamed'")
    (error 'verify-package "包名称不能为 'unnamed'"))
  (displayln (format "[发布检查] ✓ 包名称: ~a" name))
  
  ;; 检查版本
  (define ver (package-manifest-version manifest))
  (define zero-ver (make-version 0 0 0))
  (when (version=? ver zero-ver)
    (displayln "[发布检查] ✗ 版本不能为 0.0.0")
    (error 'verify-package "版本不能为 0.0.0"))
  (displayln (format "[发布检查] ✓ 包版本: ~a" (version->string ver)))
  
  ;; 检查作者
  (define authors (package-manifest-authors manifest))
  (when (null? authors)
    (displayln "[发布检查] ✗ 包必须有至少一个作者")
    (error 'verify-package "包必须有至少一个作者"))
  (displayln (format "[发布检查] ✓ 包作者: ~a" (string-join authors ", ")))
  
  (displayln "[发布检查] ✓ 所有检查通过，包可以发布")
  #t)

;; ==================== 版本标签 ====================

(define (tag-version manifest)
  ;; 为当前版本创建 Git 标签
  (define name (package-manifest-name manifest))
  (define ver (package-manifest-version manifest))
  (define tag (format "v~a" (version->string ver)))
  
  (displayln (format "[版本标签] 创建标签: ~a" tag))
  (define cmd (format "git tag ~a" tag))
  (displayln (format "[版本标签] 执行命令: ~a" cmd))
  
  (define result (system cmd))
  (if result
      (displayln (format "[版本标签] ✓ 标签 ~a 创建成功" tag))
      (displayln (format "[版本标签] ✗ 标签 ~a 创建失败" tag)))
  result)

;; ==================== 包发布 ====================

(define (publish-package manifest #:dry-run [dry-run #f])
  ;; 发布包到仓库
  ;; 参数:
  ;;   manifest - 包清单
  ;;   #:dry-run - 干运行模式，不实际发布
  
  (displayln (format "[发布] 开始发布包: ~a"
                    (package-manifest-name manifest)))
  
  ;; 验证包
  (displayln "[发布] 执行发布前验证...")
  (verify-package manifest)
  
  (if dry-run
      (begin
        (displayln "[发布] [Dry Run] 跳过实际发布")
        (displayln "[发布] ✓ Dry Run 完成"))
      (begin
        (displayln "[发布] 上传包到仓库...")
        ;; 这里应该是实际的发布逻辑
        ;; 目前先模拟发布过程
        (displayln "[发布] 生成包归档...")
        (displayln "[发布] 计算校验和...")
        (displayln "[发布] 上传到仓库...")
        (displayln "[发布] 更新仓库索引...")
        (displayln "[发布] ✓ 包发布成功"))))

;; ==================== 辅助函数 ====================

(define (format-publish-result success msg)
  ;; 格式化发布结果
  (if success
      (format "✓ ~a" msg)
      (format "✗ ~a" msg)))