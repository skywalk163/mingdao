#lang racket/base

;; 包缓存管理模块
;; 负责包的缓存存储、读取和清理

(require racket/path
         racket/file
         racket/string
         racket/format
         racket/tcp
         racket/port)

(provide
 ;; 缓存路径
 cache-dir pkg-cache-dir git-cache-dir
 ;; 缓存操作
 cache-exists? cache-write cache-read cache-delete
 cache-clean cache-size
 ;; 包安装
 install-to-cache)

;; ==================== 缓存路径 ====================

(define (cache-dir)
  ;; 主缓存目录: ~/.mingdao/
  (build-path (find-system-path 'home-dir) ".mingdao"))

(define (pkg-cache-dir)
  ;; 包缓存目录: ~/.mingdao/registry/cache/
  (build-path (cache-dir) "registry" "cache"))

(define (git-cache-dir [hash #f])
  ;; Git 缓存目录: ~/.mingdao/git/<hash>/
  (if hash
      (build-path (cache-dir) "git" hash)
      (build-path (cache-dir) "git")))

;; 确保缓存目录存在
(define (ensure-cache-dirs!)
  (when (not (directory-exists? (cache-dir)))
    (make-directory* (cache-dir)))
  (when (not (directory-exists? (pkg-cache-dir)))
    (make-directory* (pkg-cache-dir)))
  (when (not (directory-exists? (git-cache-dir)))
    (make-directory* (git-cache-dir))))

;; ==================== 缓存文件路径 ====================

(define (pkg-cache-file name version)
  ;; 生成包缓存文件路径: <name>-<version>.tar.gz
  (build-path (pkg-cache-dir) (~a name "-" version ".tar.gz")))

;; ==================== 缓存操作 ====================

(define (cache-exists? name version)
  ;; 检查包是否已缓存
  (file-exists? (pkg-cache-file name version)))

(define (cache-write name version data)
  ;; 写入缓存
  (ensure-cache-dirs!)
  (let ([cache-file (pkg-cache-file name version)])
    (with-output-to-file cache-file
      (lambda ()
        (write data))
      #:mode 'binary
      #:exists 'replace)))

(define (cache-read name version)
  ;; 读取缓存
  (let ([cache-file (pkg-cache-file name version)])
    (when (not (file-exists? cache-file))
      (error 'cache-read "缓存文件不存在: ~a" cache-file))
    (with-input-from-file cache-file
      (lambda ()
        (read)))))

(define (cache-delete name version)
  ;; 删除缓存
  (let ([cache-file (pkg-cache-file name version)])
    (when (file-exists? cache-file)
      (delete-file cache-file))))

;; ==================== 缓存管理 ====================

(define (cache-clean)
  ;; 清理所有包缓存
  (let ([pkg-dir (pkg-cache-dir)])
    (when (directory-exists? pkg-dir)
      (for ([file (in-list (directory-list pkg-dir))])
        (let ([file-path (build-path pkg-dir file)])
          (when (and (file-exists? file-path)
                     (string-suffix? (path->string file) ".tar.gz"))
            (delete-file file-path))))))
  ;; 清理 git 缓存
  (let ([git-dir (git-cache-dir)])
    (when (directory-exists? git-dir)
      (for ([dir (in-list (directory-list git-dir))])
        (let ([dir-path (build-path git-dir dir)])
          (when (directory-exists? dir-path)
            (delete-directory dir)))))))

(define (cache-size)
  ;; 获取缓存大小（字节）
  (let ([total-size 0])
    ;; 计算包缓存大小
    (let ([pkg-dir (pkg-cache-dir)])
      (when (directory-exists? pkg-dir)
        (for ([file (in-list (directory-list pkg-dir))])
          (let ([file-path (build-path pkg-dir file)])
            (when (file-exists? file-path)
              (set! total-size (+ total-size (file-size file-path))))))))
    ;; 计算 git 缓存大小
    (let ([git-dir (git-cache-dir)])
      (when (directory-exists? git-dir)
        (for ([dir (in-list (directory-list git-dir))])
          (let ([dir-path (build-path git-dir dir)])
            (when (directory-exists? dir-path)
              (set! total-size (+ total-size (directory-size dir-path))))))))
    total-size))

(define (directory-size dir-path)
  ;; 计算目录大小（递归）
  (let ([size 0])
    (for ([item (in-list (directory-list dir-path))])
      (let ([item-path (build-path dir-path item)])
        (cond
          [(file-exists? item-path)
           (set! size (+ size (file-size item-path)))]
          [(directory-exists? item-path)
           (set! size (+ size (directory-size item-path)))])))
    size))

;; ==================== 包安装 ====================

(define (install-to-cache name version url)
  ;; 下载并缓存包
  ;; 参数:
  ;;   - name: 包名
  ;;   - version: 版本号
  ;;   - url: 包下载地址
  ;; 返回: 缓存文件路径
  (ensure-cache-dirs!)
  (let ([cache-file (pkg-cache-file name version)])
    (printf "正在下载包 ~a-~a...\n" name version)
    ;; 确保目录存在
    (let ([pkg-dir (pkg-cache-dir)])
      (when (not (directory-exists? pkg-dir))
        (make-directory* pkg-dir)))
    ;; 解析 URL 获取主机和路径
    (define-values (scheme host path port)
      (cond
        [(string-prefix? url "http://")
         (let* ([rest (substring url 7)]
               [m (regexp-match #rx"^([^/:]+)(?::(\\d+))?(/.*)$" rest)])
           (if m
               (values "http"
                       (list-ref m 1)
                       (or (list-ref m 3) "/")
                       (string->number (or (list-ref m 2) "80")))
               (values "http" rest "/" 80)))]
        [(string-prefix? url "https://")
         (error 'install-to-cache "HTTPS 暂不支持，请使用 HTTP URL")]
        [else
         (error 'install-to-cache "无效的 URL: ~a" url)]))
    ;; 下载文件
    (let-values ([(in out) (tcp-connect host port)])
      (fprintf out "GET ~a HTTP/1.1\r\n" path)
      (fprintf out "Host: ~a\r\n" host)
      (fprintf out "User-Agent: mingdao-pkg/1.0\r\n")
      (fprintf out "Connection: close\r\n")
      (fprintf out "\r\n")
      (flush-output out)
      ;; 读取响应头
      (let loop ()
        (let ([header-line (read-line in)])
          (when (and (not (string=? header-line ""))
                     (not (string=? header-line "\r")))
            (loop))))
      ;; 读取响应体并写入文件
      (call-with-output-file cache-file
        (lambda (out-file)
          (copy-port in out-file))
        #:mode 'binary
        #:exists 'replace)
      (close-input-port in)
      (close-output-port out))
    (printf "包 ~a-~a 已缓存到: ~a\n" name version cache-file)
    cache-file))
