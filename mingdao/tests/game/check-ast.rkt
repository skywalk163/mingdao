#lang racket
;; 检查关键 AST 结构
(require "../../lang/tokenizer.rkt"
         "../../lang/parser.rkt"
         racket/string racket/path racket/list racket/port racket/file)

(define script-dir (path-only (path->complete-path (find-system-path 'run-file) (current-directory))))
(current-directory (build-path script-dir ".." ".."))

(define global-function-names '())

(define (collect-function-names code)
  (define names '())
  (for ([line (in-list (string-split code "\n"))])
    (define trimmed (string-trim line))
    (when (string-prefix? trimmed "定义 ")
      (define parts (string-split trimmed))
      (when (and (>= (length parts) 3) (equal? (list-ref parts 2) "就是函"))
        (set! names (cons (list-ref parts 1) names)))))
  names)

(define (collect-imports code)
  (define imports '())
  (for ([line (in-list (string-split code "\n"))])
    (define trimmed (string-trim line))
    (when (string-prefix? trimmed "导入 ")
      (define path-str (string-trim (substring trimmed 3) "\""))
      (set! imports (cons path-str imports))))
  (reverse imports))

(define processed-files (make-hash))
(define (collect-all-functions full-path)
  (when (not (hash-ref processed-files full-path #f))
    (hash-set! processed-files full-path #t)
    (define code (port->string (open-input-file full-path)))
    (define base-dir (build-path (path-only full-path)))
    (define local-funcs (collect-function-names code))
    (for ([name local-funcs])
      (set! global-function-names (cons name global-function-names)))
    (define imports (collect-imports code))
    (for ([import-path imports])
      (define import-full
        (if (absolute-path? import-path) import-path
            (build-path base-dir import-path)))
      (collect-all-functions import-full))))

(collect-all-functions (build-path (current-directory) "examples/plane-shooter/main.mingdao"))

(define (show-ast path)
  (define full (build-path (current-directory) "examples/plane-shooter" path))
  (define code (port->string (open-input-file full)))
  (define tokens (tokenize code))
  (define ast (parse tokens global-function-names))
  (printf "\n=== ~a AST ===\n" path)
  (for ([expr ast])
    (printf "  ~s\n" expr)))

;; 显示关键模块的AST
(show-ast "helper.mingdao")
(show-ast "state.mingdao")

(printf "\n=== main.mingdao AST ===\n")
(define main-code (port->string (open-input-file (build-path (current-directory) "examples/plane-shooter/main.mingdao"))))
(define main-tokens (tokenize main-code))
(define main-ast (parse main-tokens global-function-names))
(for ([expr main-ast])
  (if (and (list? expr) (eq? (car expr) 'mingdao-import))
      (printf "  (mingdao-import ~s)\n" (cadr expr))
      (printf "  ~s\n" expr)))