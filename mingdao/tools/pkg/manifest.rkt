#lang racket/base

;; 清单解析模块 - Mingdao.toml 文件解析和序列化
;; 参考 Cargo 的清单和锁定文件实现

(require racket/base
         racket/string
         racket/hash
         racket/file
         racket/list
         (file "version.rkt"))

(provide
 ;; 清单结构
 make-package-manifest package-manifest?
 package-manifest-name package-manifest-version package-manifest-authors
 package-manifest-description
 package-manifest-dependencies package-manifest-dev-dependencies
 package-manifest-features package-manifest-license package-manifest-repository
 ;; 依赖结构
 make-dependency dependency?
 dependency-name dependency-version dependency-git dependency-tag
 dependency-branch dependency-rev dependency-optional
 parse-dependency
 ;; 解析和序列化
 parse-manifest serialize-manifest
 read-manifest write-manifest
 ;; 锁定文件结构
 make-lock-entry lock-entry?
 lock-entry-name lock-entry-version lock-entry-source
 lock-entry-checksum lock-entry-dependencies
 read-lock-file write-lock-file
 ;; 包结构 (用于解析器)
 package dep
 make-package package? package-name package-version package-deps
 make-basic-package
 make-dep dep? dep-name dep-constraints)

;; ==================== 清单结构 ====================

(struct package-manifest
  (name version authors description dependencies dev-dependencies
   features license repository)
  #:transparent)

(define (make-package-manifest
         #:name [name ""]
         #:version [version (make-version 0 0 0)]
         #:authors [authors '()]
         #:description [description ""]
         #:dependencies [dependencies '()]
         #:dev-dependencies [dev-dependencies '()]
         #:features [features '()]
         #:license [license #f]
         #:repository [repository #f])
  (package-manifest name version authors description
                    dependencies dev-dependencies
                    features license repository))

;; ==================== 依赖结构 ====================

(struct dependency
  (name version git tag branch rev optional)
  #:transparent)

(define (make-dependency
         #:name [name ""]
         #:version [version #f]
         #:git [git #f]
         #:tag [tag #f]
         #:branch [branch #f]
         #:rev [rev #f]
         #:optional [optional #f])
  (dependency name version git tag branch rev optional))

(define (parse-dependency dep)
  ;; 解析依赖：支持字符串 "json ^2.0" 和哈希表 #hash('name "json", 'version "^2.0")
  (define (normalize-version str)
    ;; 将简写版本 "2.0" 转换为 "2.0.0"，支持带操作符的版本如 "^2.0"
    (define re #rx"^(\\^|~|>=|<=|>|<|=)?(.+)$")
    (define m (regexp-match re str))
    (if m
        (let* ([op (or (list-ref m 1) "")]
               [ver (list-ref m 2)]
               [normalized-ver (if (regexp-match? #rx"^[0-9]+\\.[0-9]+$" ver)
                                   (string-append ver ".0")
                                   ver)])
          (string-append op normalized-ver))
        str))
  
  (cond
    [(string? dep)
     (let* ([parts (string-split dep)]
            [name (car parts)]
            [version-str (if (null? (cdr parts)) #f (cadr parts))]
            [normalized (and version-str (normalize-version version-str))])
       (dependency name
                   (and normalized (parse-constraint normalized))
                   #f #f #f #f #f))]
    [(hash? dep)
     (dependency
      (hash-ref dep 'name (lambda () ""))
      (let ([v (hash-ref dep 'version #f)])
        (if v (parse-constraint (normalize-version v)) #f))
      (hash-ref dep 'git #f)
      (hash-ref dep 'tag #f)
      (hash-ref dep 'branch #f)
      (hash-ref dep 'rev #f)
      (hash-ref dep 'optional #f))]
    [else
     (error 'parse-dependency "无效的依赖格式: ~a" dep)]))

;; ==================== 解析函数 ====================

(define (parse-manifest ht)
  ;; 从哈希表解析清单
  (package-manifest
   (hash-ref ht 'name "")
   (let ([v (hash-ref ht 'version #f)])
     (if v (parse-version v) (make-version 0 0 0)))
   (let ([a (hash-ref ht 'authors '())])
     (if (list? a) a (list a)))
   (hash-ref ht 'description "")
   (map parse-dependency (hash-ref ht 'dependencies '()))
   (map parse-dependency (hash-ref ht 'dev-dependencies '()))
   (hash-ref ht 'features '())
   (hash-ref ht 'license #f)
   (hash-ref ht 'repository #f)))

(define (read-manifest [path "Mingdao.toml"])
  ;; 从文件读取清单
  (define content (file->string path))
  (define ht (parse-toml content))
  (parse-manifest ht))

;; ==================== 序列化函数 ====================

(define (serialize-manifest manifest)
  ;; 将清单序列化为哈希表
  (define deps-list
    (map (lambda (d)
           (if (dependency-version d)
               (format "~a ^~a"
                       (dependency-name d)
                       (version->string (version-constraint-version (dependency-version d))))
               (dependency-name d)))
         (package-manifest-dependencies manifest)))
  
  (define dev-deps-list
    (map (lambda (d)
           (if (dependency-version d)
               (format "~a ^~a"
                       (dependency-name d)
                       (version->string (version-constraint-version (dependency-version d))))
               (dependency-name d)))
         (package-manifest-dev-dependencies manifest)))
  
  (hasheq 'name (package-manifest-name manifest)
          'version (version->string (package-manifest-version manifest))
          'authors (package-manifest-authors manifest)
          'description (package-manifest-description manifest)
          'dependencies deps-list
          'dev-dependencies dev-deps-list
          'features (package-manifest-features manifest)
          'license (or (package-manifest-license manifest) "")
          'repository (or (package-manifest-repository manifest) "")))

(define (serialize-toml-string ht)
  ;; 将哈希表序列化为 TOML 字符串
  (define lines '())
  
  (define (add-line! k v)
    (set! lines (cons (format "~a = ~a" k v) lines)))
  
  (hash-for-each ht (lambda (k v)
    (cond
      [(list? v)
       (set! lines (cons (format "~a = [" k) lines))
       (for-each (lambda (item)
                   (set! lines (cons (format "  ~a" item) lines)))
                 (reverse v))
       (set! lines (cons "]" lines))]
      [(string? v)
       (add-line! k (format "\"~a\"" v))]
      [(version? v)
       (add-line! k (format "\"~a\"" (version->string v)))]
      [else
       (add-line! k (format "~a" v))])))
  
  (string-join (reverse lines) "\n"))

(define (write-manifest manifest [path "Mingdao.toml"])
  ;; 将清单写入文件
  (define content (serialize-toml-string (serialize-manifest manifest)))
  (displayln content))

;; ==================== 锁定文件结构 ====================

(struct lock-entry
  (name version source checksum dependencies)
  #:transparent)

(define (make-lock-entry
         #:name [name ""]
         #:version [version (make-version 0 0 0)]
         #:source [source #f]
         #:checksum [checksum #f]
         #:dependencies [dependencies '()])
  (lock-entry name version source checksum dependencies))

(define (read-lock-file [path "Mingdao.lock"])
  ;; 从文件读取锁定文件
  (define content (file->string path))
  (define entries (parse-lock-toml content))
  entries)

(define (write-lock-file entries [path "Mingdao.lock"])
  ;; 将锁定条目写入文件
  (define lines '("[[package]]"))
  (for-each
   (lambda (entry)
     (set! lines (cons (format "name = \"~a\"" (lock-entry-name entry)) lines))
     (set! lines (cons (format "version = \"~a\"" (version->string (lock-entry-version entry))) lines))
     (when (lock-entry-source entry)
       (set! lines (cons (format "source = \"~a\"" (lock-entry-source entry)) lines)))
     (when (lock-entry-checksum entry)
       (set! lines (cons (format "checksum = \"~a\"" (lock-entry-checksum entry)) lines)))
     (set! lines (cons "" lines)))
   (reverse entries))
  (displayln (string-join lines "\n")))

;; ==================== TOML 解析辅助函数 ====================

(define (parse-toml content)
  ;; 简单的 TOML 解析器 - 支持基本类型
  (define ht (make-hash))
  (define current-section #f)
  
  (for-each
   (lambda (line)
     (define trimmed (string-trim line))
     (cond
       [(or (string=? "" trimmed) (string-prefix? trimmed "#"))
        (void)]
       [(string-prefix? trimmed "[")
        (let* ([section (substring trimmed 1 (- (string-length trimmed) 1))]
               [section-name (string-trim section)])
          (set! current-section section-name))]
       [(string-contains? trimmed "=")
        (let* ([parts (string-split trimmed "=")]
               [key (string-trim (car parts))]
               [value (string-trim (cadr parts) "\"")])
          (hash-set! ht (string->symbol key) value))]
       [else
        (void)]))
   (string-split content "\n"))
  
  ht)

(define (parse-lock-toml content)
  ;; 解析锁定文件的 TOML
  (define entries '())
  (define current-entry (make-hash))
  (define in-package #f)
  
  (for-each
   (lambda (line)
     (define trimmed (string-trim line))
     (cond
       [(or (string=? "" trimmed) (string-prefix? trimmed "#"))
        (void)]
       [(string=? trimmed "[[package]]")
        (when (and in-package (not (hash-empty? current-entry)))
          (set! entries (cons (hasheq 'name (hash-ref current-entry 'name "")
                                       'version (hash-ref current-entry 'version "0.0.0")
                                       'source (hash-ref current-entry 'source #f)
                                       'checksum (hash-ref current-entry 'checksum #f)
                                       'dependencies '())
                             entries)))
        (set! current-entry (make-hash))
        (set! in-package #t)]
       [(string-contains? trimmed "=")
        (let* ([parts (string-split trimmed "=")]
               [key (string-trim (car parts) "\"")]
               [value (string-trim (cadr parts) "\"")])
          (hash-set! current-entry (string->symbol key) value))]
       [else
        (void)]))
   (string-split content "\n"))
  
  (when (and in-package (not (hash-empty? current-entry)))
    (set! entries (cons (hasheq 'name (hash-ref current-entry 'name "")
                                 'version (hash-ref current-entry 'version "0.0.0")
                                 'source (hash-ref current-entry 'source #f)
                                 'checksum (hash-ref current-entry 'checksum #f)
                                 'dependencies '())
                       entries)))
  
  (reverse entries))

;; ==================== 包结构 (用于解析器) ====================

(struct package (name version deps) #:transparent)

(define (make-package name version [deps '()])
  (package name version deps))

(struct dep (name constraints) #:transparent)

(define (make-dep name constraints)
  (dep name constraints))

(define (make-basic-package name version [deps '()])
  (package name version deps))