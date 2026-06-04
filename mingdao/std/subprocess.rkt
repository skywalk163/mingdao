#lang racket/base
(require racket/system
         racket/port
         racket/string
         racket/list)

(provide 子进程/运行 子进程/调用 子进程/检查调用 子进程/检查输出
         子进程/Popen 子进程/管道 子进程/通信 子进程/等待
         子进程/轮询 子进程/终止 子进程/杀死
         子进程/返回码 子进程/标准输出 子进程/标准错误
         子进程/已完成进程)

(define (子进程/已完成进程 proc out err exit-code)
  (vector proc out err exit-code))

(define (子进程/返回码 proc-info)
  (vector-ref proc-info 3))

(define (子进程/标准输出 proc-info)
  (vector-ref proc-info 1))

(define (子进程/标准错误 proc-info)
  (vector-ref proc-info 2))

(define (子进程/运行 cmd [args '()])
  (define full-cmd (if (list? cmd) cmd (cons cmd args)))
  (define in (open-input-nowhere))
  (define out (open-output-string))
  (define err (open-output-string))
  (define-values (p i o e) (subprocess in out err (car full-cmd) (cdr full-cmd)))
  (define exit-code (subprocess-wait p))
  (close-input-port i)
  (close-output-port o)
  (close-output-port e)
  (define out-str (get-output-string out))
  (define err-str (get-output-string err))
  (子进程/已完成进程 p out-str err-str exit-code))

(define (子进程/调用 cmd [args '()])
  (子进程/运行 cmd args))

(define (子进程/检查调用 cmd [args '()])
  (define result (子进程/运行 cmd args))
  (define code (子进程/返回码 result))
  (when (not (zero? code))
    (raise (format "命令 ~a 返回非零退出码: ~a" cmd code)))
  result)

(define (子进程/检查输出 cmd [args '()])
  (define result (子进程/检查调用 cmd args))
  (子进程/标准输出 result))

(define (子进程/Popen cmd [mode 'r])
  (define full-cmd (if (list? cmd) cmd (list cmd)))
  (define-values (p i o e) (subprocess #f #f #f (car full-cmd) (cdr full-cmd)))
  (vector p mode i o))

(define (子进程/通信 proc-info [input #f])
  (define proc (vector-ref proc-info 0))
  (define out (open-output-string))
  (define err (open-output-string))
  (define-values (p i o e) (subprocess #f out err proc))
  (define exit-code (subprocess-wait p))
  (close-output-port out)
  (close-output-port err)
  (define out-str (get-output-string out))
  (define err-str (get-output-string err))
  (values out-str err-str))

(define (子进程/等待 proc-info)
  (define proc (vector-ref proc-info 0))
  (subprocess-wait proc))

(define (子进程/轮询 proc-info)
  (define proc (vector-ref proc-info 0))
  (subprocess-wait proc 0))

(define (子进程/终止 proc-info)
  (define proc (vector-ref proc-info 0))
  (subprocess-kill proc))

(define (子进程/杀死 proc-info)
  (define proc (vector-ref proc-info 0))
  (subprocess-kill proc))

(define (子进程/管道 mode)
  (cond
    [(equal? mode 'r) (open-output-string)]
    [(equal? mode 'w) (open-input-string "")]
    [else (raise (format "不支持的管道模式: ~a" mode))]))