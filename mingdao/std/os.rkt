#lang racket/base
(require racket/file racket/list racket/path racket/string racket/system ffi/unsafe)

(provide 获取cwd 设置cwd
         列出目录 创建目录 删除目录
         创建文件 删除文件
         文件存在 是文件 是目录
         获取环境变量 设置环境变量 删除环境变量
         获取pid
         重命名 复制文件
         文件大小 文件修改时间 移动文件
         路径拼接 绝对路径 相对路径
         获取文件扩展名 替换文件名
         命令行参数 系统名称
         开始目录 临时目录
         路径分隔符 当前目录)

;; 当前工作目录
(define (获取cwd)
  (current-directory))

(define (设置cwd 路径)
  (current-directory 路径))

;; 目录操作
(define (列出目录 [路径 (current-directory)])
  (directory-list 路径))

(define (创建目录 路径)
  (make-directory 路径))

(define (删除目录 路径)
  (delete-directory 路径))

;; 文件操作
(define (创建文件 路径)
  (call-with-output-file 路径 (λ (端口) (void)) #:exists 'replace))

(define (删除文件 路径)
  (delete-file 路径))

;; 文件查询
(define (文件存在 路径)
  (file-exists? 路径))

(define (是文件 路径)
  (and (file-exists? 路径) (not (directory-exists? 路径))))

(define (是目录 路径)
  (directory-exists? 路径))

;; 环境变量
(define (获取环境变量 名称)
  (getenv 名称))

(define (设置环境变量 名称 值)
  (putenv 名称 值))

(define (删除环境变量 名称)
  (putenv 名称 ""))

;; 进程 ID
(define 获取pid
  (let ([getpid
         (cond
           [(eq? (system-type) 'windows)
            (get-ffi-obj "GetCurrentProcessId" "kernel32" (_fun -> _uint32))]
           [else
            (get-ffi-obj "getpid" "libc" (_fun -> _int))])])
    (λ () (getpid))))

;; 文件操作
(define (重命名 旧路径 新路径)
  (rename-file-or-directory 旧路径 新路径))

(define (复制文件 源路径 目标路径)
  (copy-file 源路径 目标路径))

(define (文件大小 路径)
  (file-size 路径))

(define (文件修改时间 路径)
  (file-or-directory-modify-seconds 路径))

(define (移动文件 源路径 目标路径)
  (rename-file-or-directory 源路径 目标路径))

;; 路径操作
(define (路径拼接 . 部分)
  (apply build-path 部分))

(define (绝对路径 路径)
  (resolve-path 路径))

(define 系统分隔符
  (if (eq? (system-type) 'windows) "\\" "/"))

(define (相对路径 目标 [基准 (current-directory)])
  (define 目标-绝对 (resolve-path 目标))
  (define 基准-绝对 (resolve-path 基准))
  (define 目标-部件 (regexp-split #rx"[/\\\\]" (path->string 目标-绝对)))
  (define 基准-部件 (regexp-split #rx"[/\\\\]" (path->string 基准-绝对)))
  (define (公共前缀长度 a b)
    (let loop ([i 0])
      (if (or (>= i (length a)) (>= i (length b))
              (not (equal? (list-ref a i) (list-ref b i))))
          i
          (loop (+ i 1)))))
  (define 共同长 (公共前缀长度 目标-部件 基准-部件))
  (define 上溯数 (- (length 基准-部件) 共同长))
  (define 向下部件 (drop 目标-部件 共同长))
  (define 结果部件 (append (make-list 上溯数 "..") 向下部件))
  (if (null? 结果部件)
      (string->path ".")
      (string->path (string-join 结果部件 系统分隔符))))

(define (获取文件扩展名 路径)
  (filename-extension 路径))

(define (替换文件名 路径 新后缀)
  (path-replace-suffix 路径 新后缀))

;; 系统信息
(define (命令行参数)
  (current-command-line-arguments))

(define (系统名称)
  (system-type))

(define (开始目录)
  (find-system-path 'home-dir))

(define (临时目录)
  (find-system-path 'temp-dir))

;; 路径分隔符
(define 路径分隔符
  系统分隔符)

(define (当前目录)
  (current-directory))