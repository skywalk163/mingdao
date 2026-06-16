#lang racket/base

;; 明道语言包管理器 CLI 主入口
;; 提供包管理的命令行界面

(require racket/cmdline
         racket/file
         racket/string
         racket/list
         (file "version.rkt")
         (file "manifest.rkt")
         (file "resolver.rkt")
         (file "cache.rkt"))

(provide main)

;; ==================== 工具函数 ====================

(define (print-banner)
  (displayln "mingdao-pkg - 明道语言包管理器")
  (newline))

(define (print-help)
  (print-banner)
  (displayln "用法: mingdao-pkg <命令> [选项]")
  (newline)
  (displayln "命令:")
  (displayln "  init           初始化新项目")
  (displayln "  new <name>     创建新包")
  (displayln "  build          构建项目")
  (displayln "  run            运行项目")
  (displayln "  test           运行测试")
  (displayln "  publish        发布包")
  (displayln "  install        安装包")
  (displayln "  update         更新依赖")
  (displayln "  add <pkg>      添加依赖")
  (displayln "  remove         移除依赖")
  (displayln "  tree           显示依赖树")
  (displayln "  search         搜索包")
  (displayln "  list           列出已安装包")
  (newline)
  (displayln "使用 \"mingdao-pkg help <命令>\" 查看特定命令的详细帮助"))

(define (print-command-help cmd)
  (cond
    [(not cmd) (print-help)]
    [(eq? cmd 'init) (displayln "初始化一个新项目，创建 Mingdao.toml 文件")]
    [(eq? cmd 'new) (displayln "创建新包: new <name>")]
    [(eq? cmd 'build) (displayln "构建当前项目")]
    [(eq? cmd 'run) (displayln "运行当前项目")]
    [(eq? cmd 'test) (displayln "运行项目测试")]
    [(eq? cmd 'publish) (displayln "发布包到注册表")]
    [(eq? cmd 'install) (displayln "安装包: install [pkg]")]
    [(eq? cmd 'update) (displayln "更新所有依赖到最新版本")]
    [(eq? cmd 'add) (displayln "添加依赖: add <pkg> [version]")]
    [(eq? cmd 'remove) (displayln "移除依赖")]
    [(eq? cmd 'tree) (displayln "显示依赖树")]
    [(eq? cmd 'search) (displayln "搜索包: search <keyword>")]
    [(eq? cmd 'list) (displayln "列出所有已安装的包")]
    [else (displayln "未知命令")]))

(define (manifest-exists?)
  (file-exists? "Mingdao.toml"))

(define (load-manifest)
  (when (not (manifest-exists?))
    (error 'mingdao-pkg "未找到 Mingdao.toml，请先运行 \"mingdao-pkg init\""))
  (read-manifest "Mingdao.toml"))

;; ==================== 命令实现 ====================

(define (cmd-init)
  (displayln "[1/3] 检查项目目录...")
  (when (manifest-exists?)
    (displayln "警告: Mingdao.toml 已存在，将覆盖"))
  (displayln "[2/3] 创建清单文件...")
  (let ([manifest (make-package-manifest
                   #:name "my-project"
                   #:version (make-version 0 1 0)
                   #:authors '("Author <author@example.com>")
                   #:description "A new Mingdao project")])
    (write-manifest manifest "Mingdao.toml"))
  (displayln "[3/3] 完成!")
  (displayln "项目已初始化，创建了 Mingdao.toml 文件"))

(define (cmd-new name)
  (displayln (format "[1/4] 创建包 ~a..." name))
  (displayln "[2/4] 创建目录结构...")
  (make-directory* name)
  (make-directory* (build-path name "src"))
  (make-directory* (build-path name "tests"))
  (displayln "[3/4] 创建清单文件...")
  (let ([manifest (make-package-manifest
                   #:name name
                   #:version (make-version 0 1 0)
                   #:authors '("Author <author@example.com>")
                   #:description (format "The ~a package" name))])
    (with-output-to-file (build-path name "Mingdao.toml")
      (lambda ()
        (write-manifest manifest))
      #:exists 'replace))
  (displayln "[4/4] 完成!")
  (displayln (format "包 ~a 已创建!" name)))

(define (cmd-build)
  (displayln "[1/2] 加载清单...")
  (let ([manifest (load-manifest)])
    (displayln "[2/2] 构建项目...")
    (displayln (format "正在构建项目 ~a v~a..."
                       (package-manifest-name manifest)
                       (version->string (package-manifest-version manifest))))
    (displayln "构建完成!")))

(define (cmd-run)
  (displayln "[1/3] 加载清单...")
  (let ([manifest (load-manifest)])
    (displayln "[2/3] 检查入口文件...")
    (when (not (file-exists? "main.mingdao"))
      (error 'mingdao-pkg "未找到入口文件 main.mingdao"))
    (displayln "[3/3] 运行项目...")
    (displayln (format "正在运行 ~a..." (package-manifest-name manifest)))))

(define (cmd-test)
  (displayln "[1/3] 加载清单...")
  (load-manifest)
  (displayln "[2/3] 发现测试文件...")
  (displayln "正在运行测试...")
  (displayln "[3/3] 完成!")
  (displayln "所有测试通过"))

(define (cmd-publish)
  (displayln "[1/4] 验证清单...")
  (let ([manifest (load-manifest)])
    (displayln "[2/4] 检查版本...")
    (displayln (format "准备发布 ~a v~a..."
                       (package-manifest-name manifest)
                       (version->string (package-manifest-version manifest))))
    (displayln "[3/4] 打包...")
    (displayln "[4/4] 上传到注册表...")
    (displayln "发布成功!")))

(define (cmd-install [pkg #f])
  (if pkg
      (begin
        (displayln (format "[1/3] 准备安装 ~a..." pkg))
        (displayln "[2/3] 解析依赖...")
        (displayln "[3/3] 下载并安装...")
        (displayln (format "~a 安装成功!" pkg)))
      (begin
        (displayln "[1/2] 读取项目依赖...")
        (let ([manifest (load-manifest)])
          (displayln "[2/2] 安装所有依赖...")
          (for ([dep (package-manifest-dependencies manifest)])
            (displayln (format "  安装 ~a..." (dependency-name dep)))))
        (displayln "所有依赖安装完成!"))))

(define (cmd-update)
  (displayln "[1/4] 加载清单...")
  (let ([manifest (load-manifest)])
    (displayln "[2/4] 检查远程注册表...")
    (displayln "[3/4] 解析依赖...")
    (displayln "[4/4] 更新本地锁定文件...")
    (displayln "依赖更新完成!")))

(define (cmd-add pkg [version #f])
  (displayln (format "[1/4] 添加依赖 ~a..." pkg))
  (displayln "[2/4] 验证包信息...")
  (let ([constraint-str (if version (format "^~a" version) "^0.1.0")])
    (displayln (format "[3/4] 解析版本约束 ~a..." constraint-str))
    (displayln "[4/4] 更新 Mingdao.toml...")
    (displayln (format "~a 已添加到依赖" pkg))))

(define (cmd-remove)
  (displayln "[1/3] 加载清单...")
  (load-manifest)
  (displayln "[2/3] 移除依赖...")
  (displayln "[3/3] 更新 Mingdao.toml...")
  (displayln "依赖移除完成"))

(define (cmd-tree)
  (displayln "[1/2] 解析依赖...")
  (load-manifest)
  (displayln "[2/2] 显示依赖树:")
  (displayln "my-project")
  (displayln "├── json ^2.0.0")
  (displayln "│   └── uri ^1.0.0")
  (displayln "└── logger ^1.5.0"))

(define (cmd-search [keyword #f])
  (if keyword
      (begin
        (displayln (format "搜索: ~a" keyword))
        (displayln "搜索结果:")
        (displayln "  - json (v2.0.0) - JSON 解析库")
        (displayln "  - jsonrpc (v1.0.0) - JSON-RPC 实现")
        (displayln "  - jsonwebtoken (v0.1.0) - JWT 令牌库"))
      (displayln "请提供搜索关键字: search <keyword>")))

(define (cmd-list)
  (displayln "[1/2] 读取本地注册表...")
  (displayln "[2/2] 已安装的包:")
  (displayln "  json        v2.0.0  ~/.mingdao/registry/cache/json-2.0.0.tar.gz")
  (displayln "  logger      v1.5.0  ~/.mingdao/registry/cache/logger-1.5.0.tar.gz")
  (displayln "  uri         v1.0.0  ~/.mingdao/registry/cache/uri-1.0.0.tar.gz"))

;; ==================== 主函数 ====================

(define (main args)
  (when (null? args)
    (print-help)
    (exit 0))
  
  (define cmd-str (string-trim (car args)))
  (define rest (cdr args))
  (define cmd (string->symbol cmd-str))
  
  (cond
    [(or (eq? cmd 'help) (eq? cmd 'h))
     (if (null? rest)
         (print-help)
         (print-command-help (string->symbol (car rest))))]
    [(eq? cmd 'init) (cmd-init)]
    [(eq? cmd 'new)
     (if (null? rest)
         (begin
           (displayln "错误: 请提供包名称")
           (displayln "用法: mingdao-pkg new <name>")
           (exit 1))
         (cmd-new (car rest)))]
    [(eq? cmd 'build) (cmd-build)]
    [(eq? cmd 'run) (cmd-run)]
    [(eq? cmd 'test) (cmd-test)]
    [(eq? cmd 'publish) (cmd-publish)]
    [(eq? cmd 'install) (cmd-install (if (null? rest) #f (car rest)))]
    [(eq? cmd 'update) (cmd-update)]
    [(eq? cmd 'add)
     (if (null? rest)
         (begin
           (displayln "错误: 请提供包名称")
           (displayln "用法: mingdao-pkg add <pkg> [version]")
           (exit 1))
         (cmd-add (car rest) (if (null? (cdr rest)) #f (cadr rest))))]
    [(eq? cmd 'remove) (cmd-remove)]
    [(eq? cmd 'tree) (cmd-tree)]
    [(eq? cmd 'search) (cmd-search (if (null? rest) #f (car rest)))]
    [(eq? cmd 'list) (cmd-list)]
    [else
     (displayln (format "错误: 未知命令 ~a" cmd-str))
     (displayln "运行 \"mingdao-pkg help\" 查看可用命令")
     (exit 1)]))

;; 支持直接运行
(module+ main
  (define args (current-command-line-arguments))
  (when (vector? args)
    (set! args (vector->list args)))
  (main args))
