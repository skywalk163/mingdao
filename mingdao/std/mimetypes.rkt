#lang racket/base
(require racket/list racket/string racket/path racket/hash)

(provide mime/猜测类型 mime/猜测扩展 mime/初始化 mime/已知类型
         mime/添加类型 mime/添加扩展 mime/后缀 mime/编码
         mime/猜测文件类型 mime/读取系统类型 mime/类型映射)

(define *mime-types*
  (make-hash
   (list
    (cons ".html" "text/html")
    (cons ".htm" "text/html")
    (cons ".css" "text/css")
    (cons ".js" "text/javascript")
    (cons ".json" "application/json")
    (cons ".xml" "application/xml")
    (cons ".txt" "text/plain")
    (cons ".md" "text/markdown")
    (cons ".csv" "text/csv")
    (cons ".png" "image/png")
    (cons ".jpg" "image/jpeg")
    (cons ".jpeg" "image/jpeg")
    (cons ".gif" "image/gif")
    (cons ".svg" "image/svg+xml")
    (cons ".ico" "image/x-icon")
    (cons ".bmp" "image/bmp")
    (cons ".webp" "image/webp")
    (cons ".mp3" "audio/mpeg")
    (cons ".wav" "audio/wav")
    (cons ".ogg" "audio/ogg")
    (cons ".mp4" "video/mp4")
    (cons ".avi" "video/x-msvideo")
    (cons ".mov" "video/quicktime")
    (cons ".webm" "video/webm")
    (cons ".pdf" "application/pdf")
    (cons ".zip" "application/zip")
    (cons ".tar" "application/x-tar")
    (cons ".gz" "application/gzip")
    (cons ".bz2" "application/x-bzip2")
    (cons ".exe" "application/x-msdownload")
    (cons ".dll" "application/x-msdownload")
    (cons ".doc" "application/msword")
    (cons ".docx" "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    (cons ".xls" "application/vnd.ms-excel")
    (cons ".xlsx" "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    (cons ".ppt" "application/vnd.ms-powerpoint")
    (cons ".pptx" "application/vnd.openxmlformats-officedocument.presentationml.presentation")
    (cons ".woff" "font/woff")
    (cons ".woff2" "font/woff2")
    (cons ".ttf" "font/ttf")
    (cons ".otf" "font/otf")
    (cons ".wasm" "application/wasm")
    (cons ".mjs" "text/javascript")
    (cons ".cjs" "text/javascript"))))

(define *mime-extensions*
  (make-hash
   (list
    (cons "text/html" ".html")
    (cons "text/css" ".css")
    (cons "text/javascript" ".js")
    (cons "application/json" ".json")
    (cons "application/xml" ".xml")
    (cons "text/plain" ".txt")
    (cons "image/png" ".png")
    (cons "image/jpeg" ".jpg")
    (cons "image/gif" ".gif")
    (cons "image/svg+xml" ".svg")
    (cons "application/pdf" ".pdf")
    (cons "application/zip" ".zip")
    (cons "application/gzip" ".gz"))))

(define (mime/猜测类型 filename)
  (with-handlers ([exn:fail? (λ _ (values #f #f))])
    (let ([ext (filename->ext filename)])
      (if ext
          (let ([mime (hash-ref *mime-types* ext #f)])
            (if mime
                (values mime #f)
                (values #f #f)))
          (values #f #f)))))

(define (mime/猜测扩展 mime-type)
  (with-handlers ([exn:fail? (λ _ (values #f #f))])
    (let ([ext (hash-ref *mime-extensions* mime-type #f)])
      (if ext
          (values ext #f)
          (values #f #f)))))

(define (mime/初始化 files)
  (void))

(define (mime/已知类型)
  (hash-keys *mime-types*))

(define (mime/添加类型 ext mime-type)
  (hash-set! *mime-types* ext mime-type)
  (hash-set! *mime-extensions* mime-type ext))

(define (mime/添加扩展 mime-type ext)
  (hash-set! *mime-extensions* mime-type ext)
  (hash-set! *mime-types* ext mime-type))

(define (mime/后缀 mime-type)
  (hash-ref *mime-extensions* mime-type #f))

(define (mime/编码 mime-type)
  #f)

(define (mime/猜测文件类型 path)
  (mime/猜测类型 (path->string path)))

(define (mime/读取系统类型)
  (hash-copy *mime-types*))

(define (mime/类型映射)
  (hash-copy *mime-types*))

(define (filename->ext filename)
  (let ([str (if (string? filename) filename (path->string filename))])
    (let loop ([i (sub1 (string-length str))])
      (cond
        [(< i 0) #f]
        [(char=? (string-ref str i) #\.)
         (substring str i)]
        [else (loop (sub1 i))]))))