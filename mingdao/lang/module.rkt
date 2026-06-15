#lang racket/base

;; 明道语言模块系统核心
;; 提供模块加载、依赖检测、导入/导出处理功能

(require racket/match
         racket/hash
         racket/set
         racket/path
         racket/string
         racket/file
         "tokenizer.rkt"
         "parser.rkt")

(provide module-info
         import-spec
         module-info?
         module-info-name
         module-info-path
         module-info-exports
         module-info-scope
         module-info-dependencies
         import-spec?
         import-spec-path
         import-spec-alias
         import-spec-symbols
         import-spec-version
         load-module
         resolve-package
         detect-circular-deps
         handle-import
         handle-export
         extract-exports
         extract-dependencies
         builtin-names)

;; 内置函数名列表（用于语义分析）
(define builtin-names
  '("打印" "长度" "索引" "列表" "列表修改" "消息拼接" "生成" "捕获" "任意" "新建"
    "定义类" "异步" "等待" "加" "减" "乘" "除" "模" "幂"
    "大于" "小于" "等于" "不等" "大于等于" "小于等于" "非" "与" "或"
    "转整数" "转浮点数" "数字转字符串" "字符串长度" "正弦" "余弦" "阶乘" "随机整数"
    "绝对值" "最大值" "最小值" "是整数" "是浮点数" "是字符串" "是数" "是空" "获取类型"
    "范围" "映射" "过滤" "追加" "拼接" "反转" "包含" "切片"))

;; ============================================================
;; 数据结构
;; ============================================================

(struct module-info (name path exports scope dependencies) #:transparent)

(struct import-spec (path alias symbols version) #:transparent)

;; 已加载模块缓存
(define loaded-modules (make-hash))

;; 命名空间别名表
(define namespace-aliases (make-hash))

;; ============================================================
;; 包版本解析
;; ============================================================

(define (resolve-package pkg-name version)
  (cond
    [(string-prefix? pkg-name "./") pkg-name]
    [(string-prefix? pkg-name "../") pkg-name]
    [(string-prefix? pkg-name "/") pkg-name]
    [else
     (define pkg-dir (find-in-package-repo pkg-name version))
     (and pkg-dir (build-path pkg-dir "main.mingdao"))]))

(define (find-in-package-repo pkg-name version)
  (define repo-path (build-path (find-system-path 'home-dir) ".mingdao" "packages" pkg-name))
  (define specific-path (if version (build-path repo-path version) repo-path))
  (and (directory-exists? specific-path) specific-path))

;; ============================================================
;; 循环依赖检测（DFS 着色算法）
;; ============================================================

(define (detect-circular-deps modules)
  (define visited (make-hash))
  (define cycles '())
  
  (define (dfs mod-name path)
    (hash-set! visited mod-name #t)
    (for ([dep (hash-ref modules mod-name '())])
      (define dep-visited (hash-ref visited dep #f))
      (cond
        [(eq? dep-visited #t)
         (set! cycles (cons (reverse (cons mod-name path)) cycles))]
        [(not dep-visited)
         (dfs dep (cons mod-name path))]))
    (hash-set! visited mod-name 'done))
  
  (for ([mod (hash-keys modules)])
    (unless (hash-ref visited mod #f)
      (dfs mod '())))
  cycles)

;; ============================================================
;; 模块加载
;; ============================================================

(define (load-module path-str)
  (define path (if (string? path-str) (string->path path-str) path-str))
  (define abs-path (if (absolute-path? path)
                       path
                       (build-path (current-directory) path)))
  
  (cond
    [(hash-ref loaded-modules (path->string abs-path) #f)
     => values]
    [else
     (define content (file->string abs-path))
     (define tokens (tokenize content))
     (define ast (parse tokens))
     (define module-name (extract-module-name ast))
     (define deps (extract-dependencies ast))
     
     (for ([dep deps])
       (load-module dep))
     
     (define exports (extract-exports ast))
     
     (define mod-info (module-info module-name
                                    (path->string abs-path)
                                    exports
                                    (hash)  ;; 简化：空 scope，后续由 semantic.rkt 填充
                                    deps))
     (hash-set! loaded-modules (path->string abs-path) mod-info)
     mod-info]))

(define (extract-module-name ast)
  (for/or ([expr ast])
    (match expr
      [`(mingdao-module ,(? string? name)) name]
      [`(mingdao-module ,(? symbol? name)) (symbol->string name)]
      [_ #f])))

(define (extract-dependencies ast)
  (define deps '())
  (for ([expr ast])
    (match expr
      [`(mingdao-import ,(? string? path))
       (set! deps (cons path deps))]
      [`(mingdao-import ,(? string? path) #:as ,_)
       (set! deps (cons path deps))]
      [`(mingdao-import ,(? string? path) #:version ,_)
       (set! deps (cons path deps))]
      [`(mingdao-import/using ,(? string? path) ,_)
       (set! deps (cons path deps))]
      [_ (void)]))
  (reverse deps))

(define (extract-exports ast)
  (define exports '())
  (for ([expr ast])
    (match expr
      [`(mingdao-export ,names ...)
       (set! exports (append (map (lambda (n)
                                     (if (symbol? n) n (string->symbol n)))
                                   names)
                              exports))]
      [_ (void)]))
  exports)

;; ============================================================
;; 导入/导出处理
;; ============================================================

(define (handle-import spec current-scope)
  (define mod-info (load-module (import-spec-path spec)))
  (when mod-info
    (if (import-spec-alias spec)
        (hash-set! namespace-aliases (import-spec-alias spec) mod-info)
        (when (import-spec-symbols spec)
          (for ([sym (import-spec-symbols spec)])
            (when (member sym (module-info-exports mod-info))
              (void)))))))  ;; 简化：只检查导出列表

(define (handle-export names current-scope)
  (for ([name names])
    (when (symbol? name)
      (void))))  ;; 简化：导出标记，后续由 semantic.rkt 处理可见性