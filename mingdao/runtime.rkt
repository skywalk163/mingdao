#lang racket/base

(require "lang/tokenizer.rkt"
         "lang/parser.rkt"
         racket/string
         racket/file
         racket/path
         racket/port)

(provide 导入
         global-function-names
         current-import-dir
         processed-files)

(define global-function-names '())

(define current-import-dir (make-parameter #f))

(define processed-files (make-hash))

(define (collect-function-names code)
  (define names '())
  (for ([line (in-list (string-split code "\n"))])
    (define trimmed (string-trim line))
    (cond
      [(and (string-prefix? trimmed "定义 ")
            (string-contains? trimmed " 就是函 "))
       (define parts (string-split trimmed))
       (when (>= (length parts) 3)
         (set! names (cons (list-ref parts 1) names)))]
      [(and (string-prefix? trimmed "定义")
            (string-contains? trimmed "就是函"))
       (define after-定义 (substring trimmed 2))
       (define 就是函-pos (string-contains? after-定义 "就是函"))
       (when 就是函-pos
         (define name (substring after-定义 0 就是函-pos))
         (when (> (string-length name) 0)
           (set! names (cons name names))))]))
  names)

(define (collect-imports code)
  (define imports '())
  (for ([line (in-list (string-split code "\n"))])
    (define trimmed (string-trim line))
    (when (string-prefix? trimmed "导入 ")
      (define path-str (string-trim (substring trimmed 3) "\""))
      (set! imports (cons path-str imports))))
  (reverse imports))

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
        (if (absolute-path? import-path)
            import-path
            (build-path base-dir import-path)))
      (collect-all-functions import-full))))

(define (导入 filepath)
  (define full-path
    (if (absolute-path? filepath)
        filepath
        (let ([base-dir (current-import-dir)])
          (if base-dir
              (build-path base-dir filepath)
              (build-path (current-directory) filepath)))))
  (when (not (file-exists? full-path))
    (error (format "找不到文件: ~a" full-path)))
  
  (hash-clear! processed-files)
  (collect-all-functions full-path)
  
  (define (process-module path)
    (define code (port->string (open-input-file path)))
    (define tokens (tokenize code))
    (define ast (parse tokens global-function-names))
    (parameterize ([current-import-dir (build-path (path-only path))])
      (for ([expr ast])
        (cond
          [(and (list? expr) (eq? (car expr) 'mingdao-import))
           (let ()
             (define import-full
               (let ([base-dir (current-import-dir)])
                 (if base-dir
                     (build-path base-dir (cadr expr))
                     (build-path (current-directory) (cadr expr)))))
           (process-module import-full))]
          [(and (list? expr) (eq? (car expr) 'mingdao-export))
           (void)]
          [else
           (eval expr (current-namespace))]))))
  
  (hash-clear! processed-files)
  (process-module full-path)
  (void))