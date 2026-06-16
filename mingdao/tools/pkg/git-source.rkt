#lang racket/base

;; Git 源处理模块
;; 负责从 Git 仓库获取包

(require racket/base
         racket/path
         racket/file
         racket/string
         racket/format
         racket/list
         (file "cache.rkt")
         (file "manifest.rkt"))

(provide
 ;; Git 缓存目录
 git-source-cache-dir
 ;; Git 操作
 git-clone git-pull git-checkout
 ;; 获取包
 fetch-git-source get-package-from-git)

;; ==================== Git 缓存目录 ====================

(define (git-source-cache-dir url)
  ;; 计算 Git 仓库的缓存路径
  ;; 使用 URL 的哈希值作为目录名，确保唯一性
  (define url-hash
    (let ([h (make-hash)])
      (for ([c (in-string url)])
        (set! h (+ (* h 31) (char->integer c))))
      (number->string h 16)))
  (build-path (git-cache-dir) url-hash))

;; ==================== Git 操作 ====================

(define (git-clone url [target-dir #f])
  ;; 克隆 Git 仓库
  ;; 参数:
  ;;   - url: Git 仓库 URL
  ;;   - target-dir: 目标目录，默认为缓存目录
  ;; 返回: 克隆后的仓库路径
  (define clone-dir (or target-dir (git-source-cache-dir url)))
  (printf "[Git] 正在克隆仓库: ~a\n" url)
  (when (not (directory-exists? clone-dir))
    (make-directory* clone-dir)
    ;; 模拟 git clone 操作
    ;; 实际实现应使用 racket/git 库
    (printf "[Git] 克隆完成，缓存目录: ~a\n" clone-dir))
  clone-dir)

(define (git-pull repo-dir)
  ;; 更新 Git 仓库
  ;; 参数:
  ;;   - repo-dir: 仓库目录
  ;; 返回: 是否更新成功
  (printf "[Git] 正在更新仓库: ~a\n" repo-dir)
  ;; 模拟 git pull 操作
  ;; 实际实现应使用 racket/git 库
  (printf "[Git] 更新完成\n")
  #t)

(define (git-checkout repo-dir ref)
  ;; 检出指定版本/分支/提交
  ;; 参数:
  ;;   - repo-dir: 仓库目录
  ;;   - ref: 版本号、分支名或提交哈希
  ;; 返回: 是否检出成功
  (printf "[Git] 正在检出: ~a\n" ref)
  ;; 模拟 git checkout 操作
  ;; 实际实现应使用 racket/git 库
  (printf "[Git] 检出完成\n")
  #t)

;; ==================== 获取包 ====================

(define (fetch-git-source url #:ref [ref #f])
  ;; 克隆或更新 Git 仓库
  ;; 参数:
  ;;   - url: Git 仓库 URL
  ;;   - ref: 指定版本/分支/提交（可选）
  ;; 返回: 仓库本地路径
  (define repo-dir (git-source-cache-dir url))
  
  (if (directory-exists? repo-dir)
      (begin
        (printf "[Git] 仓库已存在，更新中...\n")
        (git-pull repo-dir)
        (when ref
          (git-checkout repo-dir ref)))
      (begin
        (printf "[Git] 仓库不存在，开始克隆...\n")
        (git-clone url repo-dir)
        (when ref
          (git-checkout repo-dir ref))))
  
  (printf "[Git] 仓库路径: ~a\n" repo-dir)
  repo-dir)

(define (get-package-from-git repo-dir)
  ;; 从 Git 仓库获取包信息
  ;; 参数:
  ;;   - repo-dir: 仓库本地路径
  ;; 返回: 包清单或 #f
  (printf "[Git] 从仓库获取包信息: ~a\n" repo-dir)
  
  ;; 查找 Mingdao.toml 文件
  (define manifest-path (build-path repo-dir "Mingdao.toml"))
  
  (if (file-exists? manifest-path)
      (begin
        (printf "[Git] 找到清单文件: ~a\n" manifest-path)
        ;; 简单的 TOML 解析
        (let ([ht (make-hash)])
          (for-each
           (lambda (line)
             (let ([trimmed (string-trim line)])
               (cond
                 [(or (string=? "" trimmed) (string-prefix? trimmed "#"))
                  (void)]
                 [(string-prefix? trimmed "[")
                  (void)]
                 [(string-contains? trimmed "=")
                  (let* ([parts (string-split trimmed "=")]
                         [key (string-trim (car parts))]
                         [value (string-trim (cadr parts) "\"")])
                    (hash-set! ht (string->symbol key) value))]
                 [else
                  (void)])))
           (string-split (file->string manifest-path) "\n"))
          (parse-manifest ht)))
      (begin
        (printf "[Git] 未找到清单文件: ~a\n" manifest-path)
        #f)))
