#lang racket/base

(require racket/path)

(define here
  (path-only (resolved-module-path-name (variable-reference->resolved-module-path (#%variable-reference)))))

(displayln (format "模块所在目录: ~a" here))

(define config-path (build-path here "config.rkt"))
(displayln (format "config.rkt 路径: ~a" config-path))

(define list-providers-fn
  (with-handlers ([exn:fail? (lambda (e) (format "ERR: ~a" (exn-message e)))])
    (dynamic-require config-path (quote list-providers) (lambda () (lambda () (quote FALLBACK))))))

(displayln (format "list-providers-fn: ~a" list-providers-fn))
(when (procedure? list-providers-fn)
  (displayln (list-providers-fn)))
