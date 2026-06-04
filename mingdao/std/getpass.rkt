#lang racket/base
(require racket/port)

(provide 密码输入/获取 密码输入/获取用户 密码输入/获取密码)

(define (密码输入/获取 prompt)
  (with-handlers ([exn:fail? (λ (e) (error "密码输入失败: ~a" (exn-message e)))])
    (display prompt)
    (flush-output)
    (let ([line (read-line)])
      (if (eof-object? line) "" line))))

(define (密码输入/获取用户)
  (with-handlers ([exn:fail? (λ (e) (error "获取用户名失败: ~a" (exn-message e)))])
    (let ([user (getenv "USER")]
          [user-name (getenv "USERNAME")])
      (cond
        [user user]
        [user-name user-name]
        [else "unknown"]))))

(define (密码输入/获取密码 prompt)
  (with-handlers ([exn:fail? (λ (e) (error "获取密码失败: ~a" (exn-message e)))])
    (display prompt)
    (flush-output)
    (let ([line (read-line)])
      (if (eof-object? line) "" line))))