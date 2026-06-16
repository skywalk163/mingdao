#lang racket/base

;; 包仓库模块
;; 负责与包仓库交互：查询版本、元数据、下载包、搜索等

(require racket/path
         racket/file
         racket/string
         racket/list
         racket/tcp
         racket/port
         racket/format
         "version.rkt"
         "cache.rkt")

(provide
 ;; 仓库结构
 make-registry registry?
 registry-url registry-index registry-cache
 ;; 版本查询
 registry-versions registry-metadata
 ;; 下载
 registry-download
 ;; 搜索
 search-registry)

;; ==================== 仓库结构 ====================

(struct registry (url index cache) #:transparent
  #:guard (lambda (url index cache name)
    (values url index cache)))

(define (make-registry [url "https://packages.racket-lang.org"]
                       [index "all.json"]
                       [cache (pkg-cache-dir)])
  ;; 创建仓库实例
  ;; 参数:
  ;;   - url: 仓库基础 URL
  ;;   - index: 索引文件名
  ;;   - cache: 缓存目录路径
  (registry url index cache))

;; ==================== 索引文件操作 ====================

(define (registry-index-file reg)
  ;; 获取索引文件路径
  (build-path (registry-cache reg) "index" (registry-index reg)))

(define (ensure-registry-cache reg)
  ;; 确保仓库缓存目录存在
  (let ([cache-dir (registry-cache reg)]
        [index-dir (build-path (registry-cache reg) "index")])
    (when (not (directory-exists? cache-dir))
      (make-directory* cache-dir))
    (when (not (directory-exists? index-dir))
      (make-directory* index-dir))))

(define (load-registry-index reg)
  ;; 加载仓库索引
  (let ([index-file (registry-index-file reg)])
    (ensure-registry-cache reg)
    (if (file-exists? index-file)
        (with-input-from-file index-file
          (lambda ()
            (read)))
        (hasheq))))

(define (save-registry-index reg index-data)
  ;; 保存仓库索引
  (let ([index-file (registry-index-file reg)])
    (ensure-registry-cache reg)
    (with-output-to-file index-file
      (lambda ()
        (write index-data))
      #:mode 'text
      #:exists 'replace)))

;; ==================== HTTP 请求 ====================

(define (http-get url)
  ;; 简单的 HTTP GET 请求
  ;; 返回: (values status headers body)
  (define url-port (open-output-string))
  (regexp-match #rx"^https?://([^/:]+)(?::(\\d+))?(/.*)$" url)
  (let* ([m (regexp-match #rx"^https?://([^/:]+)(?::(\\d+))?(/.*)$" url)]
         [host (if m (list-ref m 1) "packages.racket-lang.org")]
         [port (if m (string->number (or (list-ref m 2) "80")) 80)]
         [path (if m (list-ref m 3) "/")])
    (let-values ([(in out) (tcp-connect host port)])
      (fprintf out "GET ~a HTTP/1.1\r\n" path)
      (fprintf out "Host: ~a\r\n" host)
      (fprintf out "User-Agent: mingdao-pkg/1.0\r\n")
      (fprintf out "Accept: application/json\r\n")
      (fprintf out "Connection: close\r\n")
      (fprintf out "\r\n")
      (flush-output out)
      ;; 读取状态行
      (let ([status-line (read-line in)])
        (define status
          (let ([m (regexp-match #px"HTTP/\\d\\.\\d\\s+(\\d+)" status-line)])
            (if m (string->number (list-ref m 1)) 200)))
        ;; 读取响应头
        (define headers (hasheq))
        (let loop ([h (read-line in)])
          (when (and (string? h)
                     (not (string=? h ""))
                     (not (string=? h "\r")))
            (loop (read-line in))))
        ;; 读取响应体
        (let ([body (port->string in)])
          (close-input-port in)
          (close-output-port out)
          (values status headers body))))))

;; ==================== 版本查询 ====================

(define (registry-versions reg pkg-name)
  ;; 获取包的所有版本
  ;; 参数:
  ;;   - reg: 仓库实例
  ;;   - pkg-name: 包名
  ;; 返回: 版本列表 (按版本号排序)
  (let ([index (load-registry-index reg)])
    (define pkg-data (hash-ref index pkg-name #f))
    (if pkg-data
        (let ([versions-str (hash-ref pkg-data 'versions '())])
          (sort (map parse-version versions-str) version-compare))
        ;; 如果本地索引没有，尝试从远程获取
        (let* ([url (build-path (registry-url reg) (format "pkg/~a" pkg-name) "v")]
               [json-url (path->string url)])
          (let-values ([(status headers body) (http-get json-url)])
            (if (= status 200)
                (let ([versions-str (string-split (string-trim body) "\n")])
                  (sort (map parse-version versions-str) version-compare))
                '()))))))

(define (registry-metadata reg pkg-name)
  ;; 获取包的元数据
  ;; 参数:
  ;;   - reg: 仓库实例
  ;;   - pkg-name: 包名
  ;; 返回: 包元数据 (hash)
  (let ([index (load-registry-index reg)])
    (define pkg-data (hash-ref index pkg-name #f))
    (if pkg-data
        pkg-data
        ;; 如果本地索引没有，尝试从远程获取
        (let* ([url (build-path (registry-url reg) (format "pkg/~a" pkg-name) "meta")]
               [json-url (path->string url)])
          (let-values ([(status headers body) (http-get json-url)])
            (if (= status 200)
                (call-with-input-string body read)
                (hasheq)))))))

;; ==================== 下载 ====================

(define (registry-download reg pkg-name version)
  ;; 下载包到缓存
  ;; 参数:
  ;;   - reg: 仓库实例
  ;;   - pkg-name: 包名
  ;;   - version: 版本号
  ;; 返回: 缓存文件路径
  (define cache-file (build-path (pkg-cache-dir)
                                  (~a pkg-name "-" version ".tar.gz")))
  (cond
    [(cache-exists? pkg-name version)
     (printf "包 ~a-~a 已在缓存中\n" pkg-name version)
     cache-file]
    [else
     ;; 构建下载 URL
     (let* ([url (path->string
                  (build-path (registry-url reg)
                              "pkg" pkg-name
                              (format "~a.tar.gz" version)))]
            [cached (install-to-cache pkg-name version url)])
       (printf "包 ~a-~a 已下载到: ~a\n" pkg-name version cached)
       cached)]))

;; ==================== 搜索 ====================

(define (search-registry reg query)
  ;; 在仓库中搜索包
  ;; 参数:
  ;;   - reg: 仓库实例
  ;;   - query: 搜索关键词
  ;; 返回: 匹配包的列表 (每项包含 name, description, version)
  (let ([index (load-registry-index reg)]
        [results '()])
    (hash-for-each index
      (lambda (pkg-name pkg-data)
        (let ([name-str (format "~a" pkg-name)]
              [desc (hash-ref pkg-data 'description "")])
          (when (or (string-contains? name-str query)
                    (string-contains? desc query))
            (set! results
                  (cons (hash 'name pkg-name
                              'version (car (hash-ref pkg-data 'versions '("")))
                              'description desc)
                        results))))))
    (reverse results)))
