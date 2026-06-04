#lang racket/base
(require racket/file racket/path racket/list racket/string racket/system racket/match)

(provide 文件工具/复制 文件工具/复制2 文件工具/复制模式 文件工具/复制状态
         文件工具/递归复制 文件工具/递归删除 文件工具/递归移动
         文件工具/磁盘使用 文件工具/移动
         文件工具/复制文件 文件工具/复制目录 文件工具/删除目录
         文件工具/压缩 文件工具/解压
         文件工具/获取存档格式 文件工具/注册存档格式 文件工具/获取解压目录
         文件工具/磁盘空间 文件工具/文件大小 文件工具/复制文件描述符)

(define (文件工具/复制文件 src dst)
  (copy-file src dst #t))

(define (文件工具/复制文件描述符 src-port dst-port [长度 1073741824])
  (define buf (make-bytes (min 长度 65536)))
  (let loop ([剩余 长度])
    (when (> 剩余 0)
      (define 读取 (read-bytes! buf src-port 0 (min 剩余 (bytes-length buf))))
      (when (> 读取 0)
        (write-bytes buf dst-port 0 读取)
        (loop (- 剩余 读取))))))

(define (文件工具/复制模式 src dst)
  (when (file-exists? src)
    (when (file-exists? dst)
      (define src-mode (file-or-directory-modify-seconds src 0))
      (void))))

(define (文件工具/复制状态 src dst)
  (文件工具/复制模式 src dst)
  (when (and (file-exists? src) (file-exists? dst))
    (define mtime (file-or-directory-modify-seconds src 0))
    (file-or-directory-modify-seconds dst mtime)))

(define (文件工具/复制 src dst)
  (cond
    [(file-exists? src)
     (文件工具/复制文件 src dst)
     (文件工具/复制状态 src dst)]
    [(directory-exists? src)
     (文件工具/递归复制 src dst)]
    [else (error "源路径不存在" src)]))

(define (文件工具/复制2 src dst)
  (文件工具/复制 src dst))

(define (文件工具/复制目录 src dst)
  (make-directory dst)
  (for ([entry (in-list (directory-list src))])
    (define src-path (build-path src entry))
    (define dst-path (build-path dst entry))
    (cond
      [(file-exists? src-path) (文件工具/复制文件 src-path dst-path)]
      [(directory-exists? src-path) (文件工具/复制目录 src-path dst-path)])))

(define (文件工具/递归复制 src dst)
  (文件工具/复制目录 src dst))

(define (文件工具/删除目录 path)
  (when (directory-exists? path)
    (for ([entry (in-list (directory-list path))])
      (define entry-path (build-path path entry))
      (cond
        [(file-exists? entry-path) (delete-file entry-path)]
        [(directory-exists? entry-path) (文件工具/递归删除 entry-path)]))
    (delete-directory path)))

(define (文件工具/递归删除 path)
  (cond
    [(file-exists? path) (delete-file path)]
    [(directory-exists? path) (文件工具/删除目录 path)]
    [else (error "路径不存在" path)]))

(define (文件工具/移动 src dst)
  (cond
    [(and (file-exists? src) (file-exists? dst))
     (rename-file-or-directory src dst #t)]
    [(file-exists? src)
     (rename-file-or-directory src dst)]
    [(directory-exists? src)
     (文件工具/递归复制 src dst)
     (文件工具/递归删除 src)]
    [else (error "源路径不存在" src)]))

(define (文件工具/递归移动 src dst)
  (文件工具/移动 src dst))

(define (文件工具/文件大小 path)
  (when (not (file-exists? path))
    (error "文件不存在" path))
  (file-size path))

(define (文件工具/磁盘使用 path)
  (define dir (if (directory-exists? path) path (build-path (path->directory-path path))))
  (define total 0)
  (define used 0)
  (define free 0)
  (values total used free))

(define (文件工具/磁盘空间 path)
  (文件工具/磁盘使用 path))

(define 文件工具/注册存档格式 #f)

(define (文件工具/获取存档格式 filename)
  (match (regexp-match #px"\\.(zip|tar|gz|bz2|xz)$" (string-downcase filename))
    [(list _ ext) ext]
    [else #f]))

(define (文件工具/压缩 base-name dir-path [format "zip"])
  (define out-file (string-append base-name "." format))
  (define proc (process (format "powershell.exe Compress-Archive -Path ~a -DestinationPath ~a -Force"
                                dir-path out-file)))
  (void (second proc))
  out-file)

(define (文件工具/解压 archive-path [extract-dir #f])
  (define dest (or extract-dir
                   (path->string (path-only archive-path))))
  (define abs-path (path->complete-path archive-path))
  (define proc (process (format "powershell.exe Expand-Archive -Path ~a -DestinationPath ~a -Force"
                                abs-path dest)))
  (void (second proc))
  dest)

(define (文件工具/获取解压目录 archive-path [extract-dir #f])
  (or extract-dir
      (path->string (path-only archive-path))))