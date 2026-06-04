#lang racket/base

(require racket/port
         racket/system
         racket/list
         racket/string)

(provide md5哈希 sha1哈希 sha256哈希 sha512哈希 文件md5 文件sha256)

;; ============================================================
;; 内部辅助：通过 certutil 计算文件哈希
;; certutil 输出格式：
;;   第1行: "MD5 hash of <path>:"
;;   第2行: "<32/40/64/128 hex chars>"
;;   第3行: "CertUtil: -hashfile command completed successfully."
;;
;; process 在 Racket 9.x 返回单个 subprocess 对象。
;; subprocess 索引：0=stdout, 1=stdin, 2=pid, 3=stderr, 4=control
;; ============================================================
(define (certutil-hash path algorithm)
  (define path-str (if (path? path) (path->string path) path))
  (define proc (process (format "certutil.exe -hashfile ~a ~a"
                                path-str algorithm)))
  (define stdout (first proc))
  (define lines (port->lines stdout))
  (close-input-port stdout)
  (string-downcase (string-trim (list-ref lines 1))))

;; ============================================================
;; 内部辅助：字符串哈希（写临时文件后调用 certutil）
;; ============================================================
(define (string-hash algorithm str)
  (define tmpdir (find-system-path 'temp-dir))
  (define tmpfile
    (build-path tmpdir
                (string-append "mingdao-hash-"
                               (number->string (random 1000000) 16)
                               ".tmp")))
  (call-with-output-file tmpfile #:exists 'replace
    (λ (p) (write-bytes (string->bytes/utf-8 str) p)))
  (define result (certutil-hash tmpfile algorithm))
  (delete-file tmpfile)
  result)

;; ============================================================
;; 公开接口 —— 字符串哈希
;; ============================================================

(define (md5哈希 s)
  (string-hash "MD5" s))

(define (sha1哈希 s)
  (string-hash "SHA1" s))

(define (sha256哈希 s)
  (string-hash "SHA256" s))

(define (sha512哈希 s)
  (string-hash "SHA512" s))

;; ============================================================
;; 公开接口 —— 文件哈希
;; ============================================================

(define (文件md5 path)
  (certutil-hash path "MD5"))

(define (文件sha256 path)
  (certutil-hash path "SHA256"))