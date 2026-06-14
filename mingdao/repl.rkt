#lang racket/base
;; 明道语言 REPL — 交互式命令行环境

(require "lang/tokenizer.rkt"
         "lang/parser.rkt"
         "lang/error.rkt"
         "lang/debug.rkt"
         racket/string
         racket/port
         racket/file
         racket/pretty)

;; 创建独立的命名空间，通过 eval 加载主模块（含 导入 函数）
(define ns
  (let ([ns (make-base-namespace)])
    (parameterize ([current-namespace ns])
      (define main-path (path->string (build-path (current-directory) "mingdao" "main.rkt")))
      (eval `(require (file ,main-path) racket/control))
      (void))
    ns))

;; 在命名空间中求值 S-表达式，捕获输出
(define (eval-and-capture expr)
  (define output-port (open-output-string))
  (parameterize ([current-output-port output-port]
                 [current-error-port output-port]
                 [current-namespace ns])
    (with-handlers ([exn:fail?
                     (λ (e)
                       (displayln (format-exception e)))])
      (call-with-values
        (λ () (eval expr))
        (λ results
          (when (and (pair? results) (not (void? (car results))))
            (displayln (car results)))))))
  (define output (get-output-string output-port))
  (close-output-port output-port)
  output)

;; 加载并执行明道文件（使用运行时的 导入 函数）
(define (mingdao-load-file filepath)
  (parameterize ([current-namespace ns])
    (with-handlers ([exn:fail?
                     (λ (e) (displayln (格式化异常 e)))])
      (eval `(导入 ,filepath)))))

;; 尝试求值一段明道代码
(define (eval-mingdao code)
  (with-handlers ([exn:fail?
                   (λ (e) (格式化异常 e))])
    (define tokens (tokenize code))
    (define ast (parse tokens))
    (string-join
     (for/list ([expr ast])
       (cond
         [(and (list? expr) (eq? (car expr) 'mingdao-export))
          ""]
         [else (eval-and-capture expr)]))
     "")))

;; 检查一行是否以冒号结尾（表示后面有缩进块）
(define (line-ends-with-colon? line)
  (define trimmed (string-trim line))
  (or (string-suffix? trimmed ":")
      (string-suffix? trimmed "：")))

;; 读取一个完整的明道语句块（处理多行缩进）
(define (read-block)
  (display "明道> ")
  (flush-output)
  (define first-line (read-line))
  (when (eof-object? first-line)
    (newline)
    (exit))
  (define lines (list first-line))
  
  (when (line-ends-with-colon? first-line)
    (define base-indent 0)
    (define in-block #f)
    (let loop ()
      (display "  · ")
      (flush-output)
      (define next-line (read-line))
      (when (eof-object? next-line)
        (newline)
        (exit))
      (define trimmed (string-trim next-line))
      (cond
        [(string=? trimmed "")
         (when in-block
           (set! lines (cons next-line lines))
           (loop))]
        [(not in-block)
         (define indent (string-length (car (regexp-match #px"^ *" next-line))))
         (set! base-indent indent)
         (set! in-block #t)
         (set! lines (cons next-line lines))
         (loop)]
        [else
         (define indent (string-length (car (regexp-match #px"^ *" next-line))))
         (if (> indent (sub1 base-indent))
             (begin
               (set! lines (cons next-line lines))
               (loop))
             (void))])))
  
  (string-join (reverse lines) "\n"))

;; 打印欢迎信息
(define (print-welcome)
  (displayln "╔══════════════════════════════════╗")
  (displayln "║       明道语言 REPL v2.0         ║")
  (displayln "║  明明白白写代码，探索编程之道。   ║")
  (displayln "╠══════════════════════════════════╣")
  (displayln "║  输入 '退出' 或 Ctrl+C 退出      ║")
  (displayln "║  输入 '帮助' 查看语法速查        ║")
  (displayln "║  输入 '调试' 开启/关闭调试模式   ║")
  (displayln "╚══════════════════════════════════╝")
  (newline))

;; 显示帮助
(define (print-help)
  (displayln "╔══ 明道语法速查 ══╗")
  (displayln "║ 定义 x 就是 42           变量定义")
  (displayln "║ 定义 f 就是函 a, b：     函数定义")
  (displayln "║     返回 a 加 b")
  (displayln "║ 42, f, 打印              主谓宾语序调用")
  (displayln "║ 如果 x 大于 0 那么：     条件")
  (displayln "║     打印, x")
  (displayln "║ 否则：")
  (displayln "║     打印, 0")
  (displayln "║ 对于 i 从 1 到 10：      for 循环")
  (displayln "║     打印, i")
  (displayln "║ 当满足 x 大于 0 那么：   while 循环")
  (displayln "║     打印, x")
  (displayln "║     跳出 / 继续          循环控制")
  (displayln "║ 列表 1, 2, 3             创建列表")
  (displayln "║ 3 乘 4                   算术运算")
  (displayln "║ 导入 \"file.mingdao\"     加载明道模块")
  (displayln "╚══════════════════════════╝")
  (newline)
  (displayln "╔══ 调试命令 ══╗")
  (displayln "║ 调试            开启/关闭调试模式")
  (displayln "║ 断言, 条件      运行时断言检查")
  (displayln "║ 检查, 标签, 值  查看变量详细信息")
  (displayln "║ 断点            设置执行断点")
  (displayln "║ 记录            结构化日志")
  (displayln "╚══════════════════════╝")
  (newline))

;; 调试命令处理
(define (handle-debug-command line)
  (define trimmed (string-trim line))
  (cond
    [(string-ci=? trimmed "退出")
     (displayln "再见！明明白白写代码")
     (exit)]
    [(string-ci=? trimmed "帮助")
     (print-help)
     #t]
    [(string-ci=? trimmed "调试")
     (调试模式 (not (调试模式)))
     (if (调试模式)
         (displayln "✓ 调试模式已开启")
         (displayln "✗ 调试模式已关闭"))
     #t]
    [(string=? trimmed "")
     #t]
    [else #f]))

;; REPL 主循环
(define (repl-loop)
  (define code (read-block))
  (unless (handle-debug-command code)
    (define output (eval-mingdao code))
    (unless (string=? output "")
      (display output)))
  (repl-loop))

;; 启动 REPL
(print-welcome)
(repl-loop)