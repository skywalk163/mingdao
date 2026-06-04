#lang racket/base
(require racket/tcp racket/system)

(provide 平台/系统 平台/版本 平台/处理器 平台/节点名 平台/机器 平台/架构
         平台/Python实现 平台/Python版本 平台/操作系统详情 平台/平台字符串
         平台/释出版本 平台/系统别名 平台/架构位宽)

(define (平台/系统)
  (system-type 'os))

(define (平台/版本)
  (system-type 'version))

(define (平台/处理器)
  (let ([arch (system-type 'machine)])
    (cond
      [(string? arch) arch]
      [else "unknown"])))

(define (平台/节点名)
  (with-handlers ([exn:fail? (λ _ "localhost")])
    (let-values ([(name _1 _2 _3) (tcp-addresses)])
      name)))

(define (平台/机器)
  (system-type 'machine))

(define (平台/架构)
  (system-type 'arch))

(define (平台/Python实现)
  "Racket")

(define (平台/Python版本)
  (system-type 'racket-version))

(define (平台/操作系统详情)
  (string-append
   (format "~a" (system-type 'os))
   " "
   (format "~a" (system-type 'version))))

(define (平台/平台字符串)
  (string-append
   (format "~a" (system-type 'os))
   "-"
   (format "~a" (system-type 'machine))
   "-"
   (format "~a" (system-type 'racket-version))))

(define (平台/释出版本)
  (system-type 'release))

(define (平台/系统别名)
  (let ([os (system-type 'os)])
    (case os
      [(win) "Windows"]
      [(macosx) "macOS"]
      [(linux) "Linux"]
      [(freebsd) "FreeBSD"]
      [(openbsd) "OpenBSD"]
      [(netbsd) "NetBSD"]
      [(solaris) "Solaris"]
      [else (format "~a" os)])))

(define (平台/架构位宽)
  (let ([arch (system-type 'arch)])
    (cond
      [(or (equal? arch 'x86_64) (equal? arch 'x64)) 64]
      [(or (equal? arch 'i386) (equal? arch 'x86)) 32]
      [else (system-type 'word-size)])))