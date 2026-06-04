#lang racket/base
(require racket/pretty)

(provide 美观打印 打印格式化 美观输出)

(define 美观打印 pretty-print)

(define (打印格式化 obj [width 70])
  (with-handlers ([exn:fail? (λ (e) (error "打印格式化错误: ~a" (exn-message e)))])
    (parameterize ([pretty-print-columns width])
      (pretty-print obj (current-output-port)))))

(define (美观输出 obj)
  (displayln (format "~s" obj)))