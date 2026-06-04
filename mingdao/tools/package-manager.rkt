#lang racket/base

(require racket/string
         racket/path
         racket/file
         racket/date)

(provide pm-install
         pm-uninstall
         pm-search
         pm-list
         pm-publish)

;; 包管理器状态
(struct package-manager (packages cache-dir) #:mutable)

;; 创建包管理器
(define (make-package-manager)
  (let ([cache-dir (build-path (find-system-path 'home-dir) ".mingdao" "packages")])
    (when (not (directory-exists? cache-dir))
      (make-directory* cache-dir))
    (package-manager (make-hash) cache-dir)))

;; 全局包管理器实例
(define current-pm (make-package-manager))

;; 安装包
(define (pm-install package-name [version #f])
  (printf "正在安装包: ~a~a\n" package-name (if version (format " (~a)" version) ""))
  ;; 模拟安装过程
  (sleep 0.5)
  (hash-set! (package-manager-packages current-pm) 
             (string->symbol package-name)
             (hash 'version (or version "1.0.0")
                   'installed-at (current-seconds)
                   'path (build-path (package-manager-cache-dir current-pm) package-name)))
  (printf "包 ~a 安装成功！\n" package-name))

;; 卸载包
(define (pm-uninstall package-name)
  (printf "正在卸载包: ~a\n" package-name)
  (hash-remove! (package-manager-packages current-pm) (string->symbol package-name))
  (printf "包 ~a 卸载成功！\n" package-name))

;; 搜索包
(define (pm-search keyword)
  (printf "搜索包: ~a\n" keyword)
  ;; 模拟搜索结果
  '("utils" "math" "string" "io"))

;; 列出已安装的包
(define (pm-list)
  (printf "已安装的包:\n")
  (for ([(name info) (package-manager-packages current-pm)])
    (printf "  - ~a (~a)\n" name (hash-ref info 'version "unknown"))))

;; 发布包
(define (pm-publish package-path)
  (printf "正在发布包: ~a\n" package-path)
  ;; 模拟发布过程
  (sleep 0.5)
  (printf "包发布成功！\n"))
