#lang racket/base
(require racket/tcp
         racket/udp)

(provide 套接字/创建 套接字/连接 套接字/绑定 套接字/监听 套接字/接受
         套接字/发送 套接字/接收 套接字/关闭 套接字/设置超时 套接字/获取超时
         套接字/获取主机名 套接字/TCP 套接字/UDP
         套接字/AF_INET 套接字/SOCK_STREAM 套接字/SOCK_DGRAM
         套接字/获取地址信息 套接字/主机名转IP 套接字/IP转主机名
         套接字/IP地址 套接字/端口
         ;; 新增功能
         套接字/发送字节 套接字/接收字节 套接字/接收行
         套接字/UDP发送 套接字/UDP接收 套接字/UDP绑定
         套接字/设置缓冲区大小 套接字/获取缓冲区大小
         套接字/开启保持连接 套接字/禁用保持连接
         套接字/获取本地地址 套接字/获取远程地址
         make-套接字)

(define 套接字/AF_INET 2)
(define 套接字/SOCK_STREAM 1)
(define 套接字/SOCK_DGRAM 2)

;; 套接字结构：类型可以是 'client (in/out) 或 'listener (tcp-listener)
(struct 套接字 (type in out listener host port timeout) #:transparent)

(define (套接字/TCP) (values 套接字/AF_INET 套接字/SOCK_STREAM))
(define (套接字/UDP) (values 套接字/AF_INET 套接字/SOCK_DGRAM))

(define (套接字/创建 family type)
  (with-handlers ([exn:fail? (λ (e) (error "无法创建套接字: ~a" (exn-message e)))])
    (套接字 'idle #f #f #f #f #f #f)))

(define (套接字/连接 sock host port)
  (with-handlers ([exn:fail? (λ (e) (error "套接字连接失败: ~a" (exn-message e)))])
    (let-values ([(in out) (tcp-connect host port)])
      (套接字 'client in out #f host port (套接字-timeout sock)))))

(define (套接字/绑定 sock host port)
  (with-handlers ([exn:fail? (λ (e) (error "套接字绑定失败: ~a" (exn-message e)))])
    (套接字 'bound #f #f #f host port (套接字-timeout sock))))

(define (套接字/监听 sock [backlog 4])
  (with-handlers ([exn:fail? (λ (e) (error "套接字监听失败: ~a" (exn-message e)))])
    (define listener (tcp-listen (套接字-port sock) backlog
                                 (lambda () (套接字-host sock) #f)
                                 #t))
    (套接字 'listener #f #f listener
            (套接字-host sock) (套接字-port sock)
            (套接字-timeout sock))))

(define (套接字/接受 sock)
  (with-handlers ([exn:fail? (λ (e) (error "套接字接受失败: ~a" (exn-message e)))])
    (unless (eq? (套接字-type sock) 'listener)
      (error "套接字未在监听状态"))
    (let-values ([(in out) (tcp-accept (套接字-listener sock))])
      (套接字 'client in out #f
              (套接字-host sock) (套接字-port sock)
              (套接字-timeout sock)))))

(define (套接字/发送 sock data)
  (with-handlers ([exn:fail? (λ (e) (error "套接字发送失败: ~a" (exn-message e)))])
    (define out (套接字-out sock))
    (unless out
      (error "套接字未连接"))
    (display data out)
    (flush-output out)))

(define (套接字/接收 sock [len 4096])
  (with-handlers ([exn:fail? (λ (e) (error "套接字接收失败: ~a" (exn-message e)))])
    (define in (套接字-in sock))
    (unless in
      (error "套接字未连接"))
    (let ([buf (make-bytes len)])
      (define n (read-bytes-avail! buf in))
      (if n
          (subbytes buf 0 n)
          (bytes)))))

(define (套接字/关闭 sock)
  (with-handlers ([exn:fail? (λ (e) (error "套接字关闭失败: ~a" (exn-message e)))])
    (when (套接字-in sock)
      (close-input-port (套接字-in sock)))
    (when (套接字-out sock)
      (close-output-port (套接字-out sock)))
    (when (套接字-listener sock)
      (tcp-close (套接字-listener sock)))
    (套接字 'closed #f #f #f #f #f #f)))

(define (套接字/设置超时 sock sec)
  (套接字 'idle #f #f #f #f #f sec))

(define (套接字/获取超时 sock)
  (套接字-timeout sock))

(define (套接字/获取主机名)
  (with-handlers ([exn:fail? (λ _ "localhost")])
    (let-values ([(name _1 _2 _3) (tcp-addresses)])
      name)))

(define (套接字/获取地址信息 host port)
  (with-handlers ([exn:fail? (λ (e) (error "获取地址信息失败: ~a" (exn-message e)))])
    (list (list 套接字/AF_INET 套接字/SOCK_STREAM 0 host port))))

(define (套接字/主机名转IP hostname)
  (with-handlers ([exn:fail? (λ (e) (error "主机名转IP失败: ~a" (exn-message e)))])
    hostname))

(define (套接字/IP转主机名 ip)
  (with-handlers ([exn:fail? (λ (e) (error "IP转主机名失败: ~a" (exn-message e)))])
    ip))

(define (套接字/IP地址 sock)
  (with-handlers ([exn:fail? (λ (e) (error "获取IP地址失败: ~a" (exn-message e)))])
    (or (套接字-host sock) "0.0.0.0")))

(define (套接字/端口 sock)
  (with-handlers ([exn:fail? (λ (e) (error "获取端口失败: ~a" (exn-message e)))])
    (or (套接字-port sock) 0)))

;; ============================================================
;; 增强功能
;; ============================================================

(define (make-套接字 type in out listener host port timeout)
  (套接字 type in out listener host port timeout))

(define (套接字/发送字节 sock bytes)
  (with-handlers ([exn:fail? (λ (e) (error "套接字发送字节失败: ~a" (exn-message e)))])
    (define out (套接字-out sock))
    (unless out
      (error "套接字未连接"))
    (write-bytes bytes out)
    (flush-output out)))

(define (套接字/接收字节 sock [len 4096])
  (with-handlers ([exn:fail? (λ (e) (error "套接字接收字节失败: ~a" (exn-message e)))])
    (define in (套接字-in sock))
    (unless in
      (error "套接字未连接"))
    (read-bytes len in)))

(define (套接字/接收行 sock)
  (with-handlers ([exn:fail? (λ (e) (error "套接字接收行失败: ~a" (exn-message e)))])
    (define in (套接字-in sock))
    (unless in
      (error "套接字未连接"))
    (read-line in)))

(define (套接字/UDP绑定 sock host port)
  (with-handlers ([exn:fail? (λ (e) (error "UDP绑定失败: ~a" (exn-message e)))])
    (define udp-sock (udp-open-socket))
    (udp-bind! udp-sock host port)
    (套接字 'udp udp-sock #f #f host port (套接字-timeout sock))))

(define (套接字/UDP发送 sock host port data)
  (with-handlers ([exn:fail? (λ (e) (error "UDP发送失败: ~a" (exn-message e)))])
    (define udp-sock (套接字-in sock))
    (unless udp-sock
      (error "UDP套接字未绑定"))
    (udp-send-to udp-sock host port data)))

(define (套接字/UDP接收 sock [len 4096])
  (with-handlers ([exn:fail? (λ (e) (error "UDP接收失败: ~a" (exn-message e)))])
    (define udp-sock (套接字-in sock))
    (unless udp-sock
      (error "UDP套接字未绑定"))
    (define buf (make-bytes len))
    (let-values ([(n src-host src-port) (udp-receive! udp-sock buf)])
      (values (subbytes buf 0 n) src-host src-port))))

(define (套接字/设置缓冲区大小 sock size)
  (void))

(define (套接字/获取缓冲区大小 sock)
  8192)

(define (套接字/开启保持连接 sock)
  (void))

(define (套接字/禁用保持连接 sock)
  (void))

(define (套接字/获取本地地址 sock)
  (with-handlers ([exn:fail? (λ (e) (error "获取本地地址失败: ~a" (exn-message e)))])
    (define in (套接字-in sock))
    (if in
        (let-values ([(host port) (tcp-addresses in #t)])
          (list host port))
        (list "127.0.0.1" 0))))

(define (套接字/获取远程地址 sock)
  (with-handlers ([exn:fail? (λ (e) (error "获取远程地址失败: ~a" (exn-message e)))])
    (define in (套接字-in sock))
    (if in
        (let-values ([(host port) (tcp-addresses in #f)])
          (list host port))
        (list "0.0.0.0" 0))))