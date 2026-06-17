#lang racket/base

(require racket/cmdline
         racket/string
         racket/format
         racket/path
         racket/file
         "../formatter.rkt"
         "../debugger.rkt"
         "../package-manager.rkt"
         "./ai/config.rkt"
         "./ai/adapter.rkt")

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
   [("--ai" "-a") "AI 代码生成"
    (ai-command)]
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

;; AI 代码生成命令
(define (ai-command)
  (printf "=== 明道 AI 代码生成 ===\n")
  (printf "可用提供商: ~a\n" (string-join (map ~a (ai获取提供者列表)) ", "))
  (printf "用法:\n")
  (printf "  mingdao-tools --ai 列出提供商和当前配置\n")
  (printf "\n")
  (printf "环境变量:\n")
  (printf "  请设置相应的 API Key 环境变量（如 DEEPSEEK_API_KEY）\n")
  (newline)
  ;; 简单的交互式生成
  (display "请用中文描述你的需求（输入 quit 退出）: ")
  (flush-output)
  (define demand (read-line))
  (when (and (not (eof-object? demand))
             (not (member (string-trim demand) '("quit" "退出" "") string-ci=?)))
    (printf "\n正在生成代码...\n\n")
    (define code (ai生成代码 demand))
    (printf "=== 生成的代码 ===\n")
    (displayln code)
    (newline)
    ;; 询问是否验证代码
    (display "是否验证代码? (y/n): ")
    (flush-output)
    (define ans (read-line))
    (when (or (string-ci=? ans "y") (string-ci=? ans "是"))
      (define vr (ai验证代码 code))
      (printf "验证结果: ~a\n" (hash-ref vr '状态 "未知"))
      (when (not (empty? (hash-ref vr '错误 '())))
        (printf "发现的问题:\n")
        (for-each (lambda (e) (printf "  - ~a\n" e)) (hash-ref vr '错误 '()))))))

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