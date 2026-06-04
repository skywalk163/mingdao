#lang racket/base

(require racket/cmdline
         racket/string
         racket/path
         racket/file
         "../formatter.rkt"
         "../debugger.rkt"
         "../package-manager.rkt")

;; 命令行工具主函数
(define (main)
  (command-line
   #:program "mingdao-tools"
   #:usage-help "明道语言开发工具集"
   #:once-each
   [("--format" "-f") "格式化代码文件"
    (format-command)]
   [("--debug" "-d") "启动调试器"
    (debug-command)]
   [("--package" "-p") "包管理器"
    (package-command)]
   #:args files
   (when (not (null? files))
     (process-files files))))

;; 格式化命令
(define (format-command)
  (printf "=== 明道代码格式化工具 ===\n")
  (printf "用法: mingdao-tools --format <文件路径>\n"))

;; 调试器命令
(define (debug-command)
  (printf "=== 明道调试器 ===\n")
  (define dbg (make-debugger))
  (printf "调试器已创建\n")
  (printf "可用命令:\n")
  (printf "  - break <行号>: 设置断点\n")
  (printf "  - continue: 继续执行\n")
  (printf "  - step: 单步执行\n")
  (printf "  - vars: 查看变量\n"))

;; 包管理器命令
(define (package-command)
  (printf "=== 明道包管理器 ===\n")
  (printf "可用命令:\n")
  (printf "  - install <包名>: 安装包\n")
  (printf "  - uninstall <包名>: 卸载包\n")
  (printf "  - list: 列出已安装的包\n")
  (printf "  - search <关键词>: 搜索包\n"))

;; 处理文件
(define (process-files files)
  (for ([file files])
    (when (file-exists? file)
      (printf "处理文件: ~a\n" file)
      (when (string-suffix? (path->string file) ".mingdao")
        (format-file file)))))

;; 运行主函数
(module+ main
  (main))