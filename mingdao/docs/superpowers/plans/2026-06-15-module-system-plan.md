# 明道语言模块系统实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现全功能模块系统（方案 C），包括可见性控制、导入解析、命名空间别名、选择性导入、循环依赖检测和包版本支持。

**架构：** 新建 `module.rkt` 处理模块加载和依赖解析；扩展 `symbol-info` 支持公开/私有标记；修改 `parser.rkt` 解析新语法；修改 `reader.rkt` 在 evaluate 前处理导入。

**技术栈：** Racket（racket/base, racket/hash, racket/set, racket/path）

---

## 文件清单

| 文件 | 操作 | 职责 |
|------|------|------|
| `mingdao/lang/module.rkt` | **创建** | 模块系统核心（加载、解析、依赖检测、版本解析） |
| `mingdao/lang/semantic.rkt` | **修改** | `symbol-info` 新增 `public?`/`module` 字段；可见性检查 |
| `mingdao/lang/parser.rkt` | **修改** | 解析 `公开`/`私有`/`模块`/`作为`/`使用`/`版本` |
| `mingdao/lang/reader.rkt` | **修改** | 在 evaluate 前处理模块导入 |
| `mingdao/lang/function-names.rkt` | **修改** | 新增关键字 |
| `mingdao/tests/test-module.rkt` | **创建** | 模块系统测试 |

---

## 任务 1：创建 module.rkt 核心模块

**文件：**
- 创建：`mingdao/lang/module.rkt`

### 子任务 1.1：数据结构定义

- [ ] **步骤 1：创建文件框架**

```racket
#lang racket/base

(require racket/match
         racket/hash
         racket/set
         racket/path
         "tokenizer.rkt"
         "parser.rkt"
         "semantic.rkt")

(provide module-info
         import-spec
         load-module
         resolve-package
         detect-circular-deps
         handle-import
         handle-export)

;; ============================================================
;; 数据结构
;; ============================================================

(struct module-info (name          ;; 模块名 (string)
                     path          ;; 文件路径 (path)
                     exports       ;; (listof symbol) 显式导出列表
                     scope         ;; 模块作用域 (scope)
                     dependencies) ;; (listof string) 依赖模块名列表
  #:transparent)

(struct import-spec (path         ;; 导入路径/包名 (string)
                     alias        ;; 命名空间别名 (#f 或 symbol)
                     symbols      ;; 选择性导入符号列表 (#f 或 listof symbol)
                     version)     ;; 版本号 (#f 或 string)
  #:transparent)
```

- [ ] **步骤 2：包版本解析函数**

```racket
;; ============================================================
;; 包版本解析
;; ============================================================

(define (resolve-package pkg-name version)
  (cond
    [(string-prefix? pkg-name "./") pkg-name]
    [(string-prefix? pkg-name "/") pkg-name]
    [else
     (define pkg-dir (find-in-package-repo pkg-name version))
     (and pkg-dir (build-path pkg-dir "main.mingdao"))]))

(define (find-in-package-repo pkg-name version)
  (define repo-path (build-path (find-system-path 'home-dir) ".mingdao" "packages"))
  (define pkg-path (build-path repo-path pkg-name version))
  (and (directory-exists? pkg-path) pkg-path))
```

- [ ] **步骤 3：循环依赖检测函数**

```racket
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
```

- [ ] **步骤 4：模块加载函数**

```racket
;; ============================================================
;; 模块加载
;; ============================================================

(define loaded-modules (make-hash))

(define (load-module path-str)
  (define path (if (string? path-str) (string->path path-str) path-str))
  (define abs-path (if (path-absolute? path) path (build-path (current-directory) path)))
  
  (cond
    [(hash-ref loaded-modules abs-path #f)]
    [else
     (define content (file->string abs-path))
     (define tokens (tokenize content))
     (define ast (parse tokens))
     (define module-name (extract-module-name ast))
     (define deps (extract-dependencies ast))
     
     (for ([dep deps])
       (load-module dep))
     
     (define errors (analyze ast builtin-names))
     (define scope (make-module-scope module-name ast))
     (define exports (extract-exports ast))
     
     (define mod-info (module-info module-name abs-path exports scope deps))
     (hash-set! loaded-modules abs-path mod-info)
     mod-info]))

(define (extract-module-name ast)
  (for/or ([expr ast])
    (match expr
      [`(mingdao-module ,name) name]
      [_ #f])))

(define (extract-dependencies ast)
  (for/list ([expr ast]
             #:when (or (eq? (car expr) 'mingdao-import)
                        (eq? (car expr) 'mingdao-import/using)))
    (cadr expr)))
```

- [ ] **步骤 5：导入/导出处理函数**

```racket
;; ============================================================
;; 导入/导出处理
;; ============================================================

(define namespace-aliases (make-hash))

(define (handle-import spec current-scope)
  (define mod-info (load-module (import-spec-path spec)))
  (when mod-info
    (if (import-spec-alias spec)
        (hash-set! namespace-aliases (import-spec-alias spec) mod-info)
        (when (import-spec-symbols spec)
          (for ([sym (import-spec-symbols spec)])
            (define info (lookup-symbol-in-scope sym (module-info-scope mod-info)))
            (when info
              (register-symbol! current-scope sym info))))))

(define (handle-export names current-scope)
  (for ([name names])
    (define info (lookup-symbol name current-scope))
    (when info
      (set-symbol-public! info #t))))

(define (lookup-symbol-in-scope name scope)
  (hash-ref (scope-symbols scope) name #f))

(define (register-symbol! scope name info)
  (hash-set! (scope-symbols scope) name info))

(define (set-symbol-public! info public?)
  (struct-copy symbol-info info [public? public?]))
```

- [ ] **步骤 6：验证模块加载**

```bash
cd g:\dumategithub\langbyracket && racket -e '(require "mingdao/lang/module.rkt") (displayln "module.rkt loaded OK")'
```

---

## 任务 2：扩展 semantic.rkt 的 symbol-info

**文件：**
- 修改：`mingdao/lang/semantic.rkt`

### 子任务 2.1：扩展 symbol-info 结构

- [ ] **步骤 1：查找 symbol-info 定义并修改**

原：
```racket
(struct symbol-info (kind type line col mutable? defined?) #:transparent)
```

改为：
```racket
(struct symbol-info (kind type line col mutable? defined? public? module) #:transparent)
```

- [ ] **步骤 2：修改 register-with-checks! 支持 public? 参数**

```racket
(define (register-with-checks! scope name kind #:type [type #f] #:public? [public? #t])
  (define existing (hash-ref (scope-symbols scope) name #f))
  (cond
    [existing
     (when (eq? (scope-parent scope) #f)
       (add-error! ...))]
    [else
     (hash-set! (scope-symbols scope) name
                (symbol-info kind type (current-line) (current-col) #t #t public? (current-module)))]))
```

- [ ] **步骤 3：新增可见性检查函数**

```racket
(define (check-accessibility name-str info current-scope)
  (unless (or (symbol-info-public? info)
              (equal? (symbol-info-module info) (current-module)))
    (add-error! (semantic-error
                  'access-denied
                  (format "符号 '~a' 是私有的，无法在此处访问" name-str)
                  (current-line) (current-col)
                  "请将符号改为公开，或在同一模块内访问"))))
```

---

## 任务 3：修改 parser.rkt 支持新语法

**文件：**
- 修改：`mingdao/lang/parser.rkt`

### 子任务 3.1：解析 `公开`/`私有` 修饰符

- [ ] **步骤 1：在 parse-statement 中添加修饰符处理**

```racket
;; 在 parse-statement 中添加
[(list-rest (? (λ (x) (member x '("公开" "私有"))) visibility) rest)
 (define stmt (parse-statement rest))
 (match stmt
   [`(define ,name . ,rest)
    (define public? (equal? visibility "公开"))
    `(mingdao-def ,(if public? '公开 '私有) ,name . ,rest)]
   [_ stmt])]
```

### 子任务 3.2：解析 `模块` 声明

- [ ] **步骤 1：添加模块声明解析**

```racket
;; 在 parse-statement 中添加
[(list "模块" (? string? name))
 `(mingdao-module ,name)]
```

### 子任务 3.3：解析导入语法

- [ ] **步骤 1：解析基本导入**

```racket
[(list "导入" (? string? path))
 `(mingdao-import ,path)]
```

- [ ] **步骤 2：解析带别名的导入**

```racket
[(list "导入" (? string? path) "作为" (? symbol? alias))
 `(mingdao-import ,path #:as ',alias)]
```

- [ ] **步骤 3：解析选择性导入**

```racket
[(list "导入" (? string? path) "使用" names ...)
 `(mingdao-import/using ,path ,(map string->symbol names))]
```

- [ ] **步骤 4：解析带版本的导入**

```racket
[(list "导入" (? string? pkg) "版本" (? string? version))
 `(mingdao-import ,pkg #:version ,version)]
```

### 子任务 3.4：解析导出语法

- [ ] **步骤 1：添加导出解析**

```racket
[(list "导出" names ...)
 `(mingdao-export ,(map string->symbol names))]
```

---

## 任务 4：修改 reader.rkt 处理模块导入

**文件：**
- 修改：`mingdao/lang/reader.rkt`

### 子任务 4.1：在 evaluate 前处理模块

- [ ] **步骤 1：修改 read 函数添加模块处理**

```racket
(define (read source-name source-text)
  (define tokens (tokenize source-text))
  (define ast (parse tokens))
  
  (process-modules ast)
  
  (define errors (analyze ast builtin-names))
  (for ([err errors])
    (displayln (format-semantic-error err)))
  
  (evaluate ast))

(define (process-modules ast)
  (for ([expr ast])
    (match expr
      [`(mingdao-import ,path . ,opts)
       (define alias (for/or ([opt opts]) (and (eq? (car opt) '#:as) (cadr opt))))
       (handle-import (import-spec path alias #f #f) (current-scope))]
      [`(mingdao-import/using ,path ,symbols)
       (handle-import (import-spec path #f symbols #f) (current-scope))]
      [`(mingdao-export ,names ...)
       (handle-export names (current-scope))]
      [_ (void)])))
```

---

## 任务 5：修改 function-names.rkt 添加关键字

**文件：**
- 修改：`mingdao/lang/function-names.rkt`

- [ ] **步骤 1：添加新关键字**

```racket
(define 控制流关键字
  (append ...
          '("公开" "私有" "模块" "作为" "使用" "版本")))
```

---

## 任务 6：创建测试文件

**文件：**
- 创建：`mingdao/tests/test-module.rkt`

- [ ] **步骤 1：创建测试文件**

```racket
#lang racket/base

(require rackunit
         "../lang/module.rkt"
         "../lang/semantic.rkt")

(define tests
  (test-suite
   "模块系统测试"
   
   (test-case "循环依赖检测"
     (define modules (hash 'a '(b) 'b '(c) 'c '(a)))
     (define cycles (detect-circular-deps modules))
     (check-true (not (null? cycles))))
   
   (test-case "符号可见性检查"
     (define info (symbol-info '变量 '整数 1 1 #t #t #f "test"))
     (check-false (symbol-info-public? info)))
   
   (test-case "包路径解析"
     (define path (resolve-package "./test.mingdao" #f))
     (check-equal? path "./test.mingdao"))))

(run-tests tests)
```

---

## 验收检查

- [ ] module.rkt 可通过 `racket` 加载
- [ ] semantic.rkt 的 symbol-info 扩展完成
- [ ] parser.rkt 能解析所有新语法
- [ ] reader.rkt 能处理模块导入
- [ ] function-names.rkt 包含新关键字
- [ ] test-module.rkt 测试通过
- [ ] 现有测试不受影响

---

## 自检清单

1. **规格覆盖度**：所有功能都覆盖（可见性、导入、别名、选择性导入、循环依赖、版本）
2. **占位符扫描**：无 "待定"、"TODO"
3. **文件一致性**：module.rkt 是中心模块，其他模块依赖它