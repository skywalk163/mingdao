#lang racket/base

(require racket/list racket/string racket/system racket/path racket/format)

(provide
 参数/创建解析器 参数/添加参数 参数/解析 参数/解析已知
 参数/添加子解析器 参数/设置默认 参数/打印帮助
 参数/打印用法 参数/格式化帮助 参数/格式化用法 参数/输出帮助 参数/错误 参数/退出)

(struct 参数 (name short type default help required action nargs) #:mutable)
(struct 子解析器 (name parser help) #:mutable)
(struct 解析器 (prog description args subparsers epilog) #:mutable)

(define (参数/创建解析器 #:prog [prog (find-program-name)]
                         #:description [desc ""]
                         #:epilog [epilog ""])
  (解析器 prog desc null null epilog))

(define (参数/添加参数 parser
                       #:name [name ""]
                       #:short [short #f]
                       #:type [type string->number]
                       #:default [default #f]
                       #:help [help ""]
                       #:required [required #f]
                       #:action [action 'store]
                       #:nargs [nargs 1])
  (set-解析器-args! parser
    (append (解析器-args parser)
            (list (参数 name short type default help required action nargs)))))

(define (参数/添加子解析器 parser name #:help [help ""])
  (define sub (参数/创建解析器 #:prog (string-append (解析器-prog parser) " " name)))
  (set-解析器-subparsers! parser
    (append (解析器-subparsers parser)
            (list (子解析器 name sub help))))
  sub)

(define (参数/设置默认 parser key val)
  (参数/添加参数 parser #:name (format "--~a" key) #:default val))

(define (参数/解析 parser args)
  (parse-args parser args #f))

(define (参数/解析已知 parser args)
  (parse-args parser args #t))

(define (parse-args parser args known-only)
  (define result (make-hasheq))
  (define positional '())
  (define rest '())
  (define opt-args (filter (lambda (a) (and (参数-name a) (string-prefix? (参数-name a) "--"))) (解析器-args parser)))
  (define pos-args (filter (lambda (a) (or (not (参数-name a)) (not (string-prefix? (参数-name a) "--")))) (解析器-args parser)))
  (for-each (lambda (a) (hash-set! result (string->symbol (参数-name a)) (参数-default a))) (解析器-args parser))
  (let loop ((remaining args) (pos-idx 0))
    (cond
      [(null? remaining)
       (values result positional)]
      [else
       (define arg (car remaining))
       (define rest-args (cdr remaining))
       (cond
         [(or (string=? arg "--help") (string=? arg "-h"))
          (参数/打印帮助 parser)
          (exit 0)]
         [(string-prefix? arg "--")
          (define opt-name (substring arg 2))
          (define matching-opt
            (findf (lambda (a)
                     (and (参数-name a)
                          (or (string=? (参数-name a) arg)
                              (string=? (参数-name a) opt-name)
                              (and (参数-short a)
                                   (string=? (参数-short a) arg)))))
                   opt-args))
          (if matching-opt
            (let ((val (if (eq? (参数-action matching-opt) 'store_true)
                         #t
                         (if (null? rest-args)
                           (参数-default matching-opt)
                           ((参数-type matching-opt) (car rest-args))))))
              (hash-set! result (string->symbol (参数-name matching-opt)) val)
              (loop (if (eq? (参数-action matching-opt) 'store_true) rest-args (cdr rest-args)) pos-idx))
            (if known-only
              (loop rest-args pos-idx)
              (begin (set! rest (append rest (list arg))) (loop rest-args pos-idx))))]
         [(string-prefix? arg "-")
          (define short-name (substring arg 1))
          (define matching-opt
            (findf (lambda (a) (and (参数-short a) (string=? (参数-short a) short-name))) opt-args))
          (if matching-opt
            (let ((val (if (null? rest-args)
                         (参数-default matching-opt)
                         ((参数-type matching-opt) (car rest-args)))))
              (hash-set! result (string->symbol (参数-name matching-opt)) val)
              (loop (cdr rest-args) pos-idx))
            (if known-only
              (loop rest-args pos-idx)
              (begin (set! rest (append rest (list arg))) (loop rest-args pos-idx))))]
         [else
          (if (< pos-idx (length pos-args))
            (let ((pa (list-ref pos-args pos-idx)))
              (hash-set! result (string->symbol (参数-name pa)) ((参数-type pa) arg))
              (loop rest-args (+ pos-idx 1)))
            (begin (set! positional (append positional (list arg)))
                   (loop rest-args pos-idx)))])])))

(define (参数/格式化用法 parser)
  (define prog (解析器-prog parser))
  (define opt-args (filter (lambda (a) (string-prefix? (参数-name a) "--")) (解析器-args parser)))
  (define pos-args (filter (lambda (a) (not (string-prefix? (参数-name a) "--"))) (解析器-args parser)))
  (define opt-summary
    (string-join
      (map (lambda (a)
             (string-append "[" (参数-name a) (if (参数-short a) (string-append " " (参数-short a)) "") "]"))
           opt-args)
      " "))
  (define pos-summary
    (string-join (map (lambda (a) (参数-name a)) pos-args) " "))
  (string-trim (string-append "用法: " prog " " opt-summary " " pos-summary)))

(define (参数/打印用法 parser)
  (displayln (参数/格式化用法 parser)))

(define (参数/格式化帮助 parser)
  (define usage (参数/格式化用法 parser))
  (define desc (解析器-description parser))
  (define args (解析器-args parser))
  (define epilog (解析器-epilog parser))
  (define arg-lines
    (string-join
      (map (lambda (a)
             (let ((name (参数-name a))
                   (short (参数-short a))
                   (help (参数-help a))
                   (default (参数-default a)))
               (string-append "  " name
                 (if short (string-append ", -" short) "")
                 (if (not (equal? default #f)) (string-append " [默认: " (~a default) "]") "")
                 (if (not (string=? help "")) (string-append "  " help) ""))))
           args)
      "\n"))
  (string-trim
    (string-append usage "\n\n"
      (if (not (string=? desc "")) (string-append desc "\n\n") "")
      (if (not (string=? arg-lines "")) (string-append "参数:\n" arg-lines "\n") "")
      (if (not (string=? epilog "")) (string-append "\n" epilog "\n") ""))))

(define (参数/打印帮助 parser)
  (displayln (参数/格式化帮助 parser)))

(define (参数/输出帮助 parser)
  (参数/打印帮助 parser))

(define (参数/错误 parser msg)
  (fprintf (current-error-port) "~a: 错误: ~a~n" (解析器-prog parser) msg)
  (参数/打印用法 parser)
  (exit 1))

(define (参数/退出 parser code)
  (exit code))

(define (find-program-name)
  (path->string (find-system-path 'run-file)))