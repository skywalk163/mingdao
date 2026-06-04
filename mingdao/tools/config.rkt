#lang racket/base

(require racket/file
         racket/path
         racket/string)

(provide load-config
         save-config
         get-config-value
         default-config)

;; 默认配置
(define default-config
  (hash 'formatter (hash 'indent-size 4
                          'use-tabs #f
                          'max-line-length 80)
        'lsp (hash 'enabled #t
                    'port 8080
                    'log-level 'info)
        'debugger (hash 'break-on-entry #f
                        'show-stack-trace #t)
        'package-manager (hash 'cache-dir "~/.mingdao/packages"
                               'registry-url "https://registry.mingdao-lang.org")))

;; 配置文件路径
(define config-file-name ".mingdao-config")

;; 加载配置
(define (load-config [project-dir (current-directory)])
  (define config-path (build-path project-dir config-file-name))
  (if (file-exists? config-path)
      (let ([config-data (file->string config-path)])
        (parse-config config-data))
      default-config))

;; 解析配置（简化版本）
(define (parse-config config-string)
  ;; 这里可以实现更复杂的配置解析
  default-config)

;; 保存配置
(define (save-config config [project-dir (current-directory)])
  (define config-path (build-path project-dir config-file-name))
  (define config-string (format-config config))
  (display-to-file config-string config-path #:exists 'truncate))

;; 格式化配置为字符串
(define (format-config config)
  (format "# 明道语言配置文件\n\n~a" 
          (hash->string config)))

;; 将hash转换为字符串（简化版本）
(define (hash->string h)
  (let ([result ""])
    (for ([(key value) h])
      (set! result (string-append result 
                                  (format "~a: ~a\n" key value))))
    result))

;; 获取配置值
(define (get-config-value config section key)
  (let ([section-config (hash-ref config section #f)])
    (if section-config
        (hash-ref section-config key #f)
        #f)))

;; 示例配置文件内容
(define example-config-content
  "# 明道语言配置文件

formatter:
  indent-size: 4
  use-tabs: false
  max-line-length: 80

lsp:
  enabled: true
  port: 8080
  log-level: info

debugger:
  break-on-entry: false
  show-stack-trace: true

package-manager:
  cache-dir: ~/.mingdao/packages
  registry-url: https://registry.mingdao-lang.org
")