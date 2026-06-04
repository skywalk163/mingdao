#lang racket/base
(require racket/port racket/file racket/string)

(provide csv读取 csv解析 csv写入 csv生成)

;; 解析一个 CSV 字段（支持引号转义、逗号、换行）
(define (parse-field str start)
  (let loop ([i start] [chars '()] [in-quotes #f])
    (if (>= i (string-length str))
        (values (list->string (reverse chars)) i)
        (let ([ch (string-ref str i)])
          (cond
            [(char=? ch #\")
             (if in-quotes
                 (if (and (< (+ i 1) (string-length str))
                          (char=? (string-ref str (+ i 1)) #\"))
                     (loop (+ i 2) (cons #\" chars) #t)
                     (loop (+ i 1) chars #f))
                 (loop (+ i 1) chars #t))]
            [(char=? ch #\,)
             (if in-quotes
                 (loop (+ i 1) (cons ch chars) #t)
                 (values (list->string (reverse chars)) (+ i 1)))]
            [(or (char=? ch #\newline) (char=? ch #\return))
             (if in-quotes
                 (loop (+ i 1) (cons ch chars) #t)
                 (values (list->string (reverse chars)) i))]
            [else
             (loop (+ i 1) (cons ch chars) in-quotes)])))))

;; 解析一整行 CSV（从 start 开始到换行或结尾）
(define (parse-row str start)
  (let loop ([i start] [fields '()])
    (if (>= i (string-length str))
        (values (reverse fields) i)
        (let-values ([(field next) (parse-field str i)])
          (if (>= next (string-length str))
              (values (reverse (cons field fields)) next)
              (let ([ch (string-ref str next)])
                (if (or (char=? ch #\newline) (char=? ch #\return))
                    (let ([skip (if (and (char=? ch #\return)
                                         (< (+ next 1) (string-length str))
                                         (char=? (string-ref str (+ next 1)) #\newline))
                                    (+ next 2)
                                    (+ next 1))])
                      (values (reverse (cons field fields)) skip))
                    (loop next (cons field fields)))))))))

(define (csv解析 str)
  (with-handlers ([exn:fail? (λ (e) (error "CSV解析错误: ~a" (exn-message e)))])
    (let loop ([i 0] [rows '()])
      (if (>= i (string-length str))
          (reverse rows)
          (let-values ([(row next) (parse-row str i)])
            (loop next (cons row rows)))))))

(define (csv读取 path)
  (with-handlers ([exn:fail? (λ (e) (error "无法读取CSV: ~a" (exn-message e)))])
    (csv解析 (call-with-input-file path (λ (in) (port->string in))))))

;; 将单个字段转义为 CSV 格式
(define (escape-field field)
  (if (regexp-match? "[,\"\n\r]" field)
      (string-append "\"" (regexp-replace* "\"" field "\"\"") "\"")
      field))

(define (csv生成 rows)
  (with-handlers ([exn:fail? (λ (e) (error "CSV生成错误: ~a" (exn-message e)))])
    (string-join
     (for/list ([row (in-list rows)])
       (string-join (map escape-field row) ","))
     "\n")))

(define (csv写入 path rows)
  (with-handlers ([exn:fail? (λ (e) (error "无法写入CSV: ~a" (exn-message e)))])
    (call-with-output-file path
      (λ (out) (display (csv生成 rows) out))
      #:exists 'replace)))