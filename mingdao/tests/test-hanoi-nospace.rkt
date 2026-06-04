#lang racket/base

(require racket/port racket/file racket/control
         "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

;; 设置命名空间，类似 playground 的方式
(define ns
  (let ([ns (make-base-namespace)])
    (parameterize ([current-namespace ns])
      (define main-path
    (build-path (current-directory) ".." "main.rkt"))
      (eval `(require (file ,(path->string main-path)) racket/control))
      (void))
    ns))

(define code (port->string (open-input-file "../examples/hanoi-nospace.mingdao")))
(printf "代码内容:\n~a\n\n" code)

(printf "===== 求值结果 =====\n")
(parameterize ([current-output-port (current-output-port)]
               [current-error-port (current-error-port)]
               [current-namespace ns])
  (with-handlers ([exn:fail? (λ (e) (printf "错误: ~a\n" (exn-message e)))])
    (define tokens (tokenize code))
    (define ast (parse tokens '("汉诺塔")))
    (for ([expr ast])
      (printf "求值: ~a\n" expr)
      (call-with-values
        (λ () (eval expr ns))
        (λ results
          (when (and (pair? results) (not (void? (car results))))
            (displayln (car results))))))))

(printf "\n✓ 无空格汉诺塔测试完成\n")