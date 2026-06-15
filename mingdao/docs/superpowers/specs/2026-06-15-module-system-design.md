# 明道语言模块系统设计文档

> **面向 AI 代理的工作者：** 此文档描述了如何实现全功能模块系统（方案 C），包括可见性控制、导入解析、命名空间别名、选择性导入、循环依赖检测和包版本支持。

**状态**: 已批准
**日期**: 2026-06-15
**目标**: M4 里程碑 — 模块系统

---

## 一、目标

实现完整的工业级模块系统，包括：

1. **可见性控制** — `公开`/`私有` 修饰符
2. **导入机制** — 支持相对路径、绝对路径、包名导入
3. **命名空间别名** — `导入 ... 作为 alias`
4. **选择性导入** — `导入 ... 使用 symbol1, symbol2`
5. **循环依赖检测** — DFS 着色算法检测模块循环引用
6. **包版本支持** — 简化的语义版本解析

---

## 二、架构

### 模块加载流程

```
用户代码入口
    │
    ▼
reader.rkt: read
    │
    ├── 解析模块声明（如有）
    │       │
    │       ▼
    │   (模块 模块名) → 记录当前模块名
    │
    ├── 处理导入声明
    │       │
    │       ▼
    │   module.rkt: load-module
    │       │
    │       ├── resolve-package（版本解析）
    │       ├── load-file（读取文件）
    │       ├── tokenize + parse
    │       ├── analyze（语义分析）
    │       ├── 检测循环依赖
    │       └── 提取公开符号 → 缓存
    │
    ├── 语义分析（含可见性检查）
    │
    └── evaluate
```

### 作用域层级

```
全局作用域（global-scope）
    │
    ├── 模块作用域（module-scope）
    │       │
    │       ├── 函数作用域（function-scope）
    │       │       │
    │       │       └── 块作用域（block-scope）
    │       │
    │       └── 循环作用域（loop-scope）
    │
    └── 导入符号（imported-symbols）
```

---

## 三、语法与 AST

### 3.1 定义修饰符

| 语法 | AST | 说明 |
|------|-----|------|
| `公开 定义 x 就是 5` | `(mingdao-def '公开 'x 5)` | 公开定义 |
| `私有 定义 _x 就是 5` | `(mingdao-def '私有 '_x 5)` | 私有定义 |
| `定义 y 就是 5` | `(mingdao-def '默认 'y 5)` | 默认公开 |

### 3.2 模块声明

```racket
;; 语法
模块 math

;; AST
(mingdao-module "math")
```

### 3.3 导入语法

| 语法 | AST | 说明 |
|------|-----|------|
| `导入 "./utils"` | `(mingdao-import "./utils")` | 相对路径导入 |
| `导入 "./math" 作为 m` | `(mingdao-import "./math" #:as 'm)` | 命名空间别名 |
| `导入 "./math" 使用 PI` | `(mingdao-import/using "./math" (PI))` | 选择性导入 |
| `导入 "math" 版本 "1.0.0"` | `(mingdao-import "math" #:version "1.0.0")` | 包版本 |

### 3.4 导出语法

```racket
;; 语法
导出 PI, 双倍

;; AST
(mingdao-export 'PI '双倍)
```

### 3.5 命名空间限定访问

```racket
;; 语法
m.PI

;; AST
(mingdao-qualified 'm 'PI)
```

---

## 四、数据结构

### 4.1 symbol-info 扩展

```racket
(struct symbol-info (kind       ;; '变量 | '函数 | '参数 | '内置函数 | '类型别名
                     type       ;; 类型标注
                     line col   ;; 定义位置
                     mutable?   ;; 是否可变
                     defined?   ;; 是否已定义
                     public?    ;; #t = 公开, #f = 私有 (新增)
                     module)    ;; 所属模块名 (新增)
  #:transparent)
```

### 4.2 module-info（新增）

```racket
(struct module-info (name          ;; 模块名
                     path          ;; 文件路径
                     exports       ;; (listof symbol-name) 显式导出列表
                     scope         ;; 模块作用域
                     dependencies) ;; (listof module-name) 依赖列表
  #:transparent)
```

### 4.3 import-spec（新增）

```racket
(struct import-spec (path         ;; 导入路径/包名
                     alias        ;; 命名空间别名（#f 或 symbol）
                     symbols      ;; 选择性导入符号列表（#f 表示全部）
                     version))    ;; 版本号（#f 或 string）
```

---

## 五、核心功能

### 5.1 可见性检查

```racket
(define (check-accessibility name-str info current-scope)
  (unless (or (symbol-info-public? info)
              (same-module? info current-scope))
    (add-error! (semantic-error
                  'access-denied
                  (format "符号 '~a' 是私有的，无法在此处访问" name-str)
                  (current-line) (current-col)
                  "请将符号改为公开，或在同一模块内访问"))))
```

### 5.2 循环依赖检测

```racket
(define (detect-circular-deps modules)
  (define visited (make-hash))    ;; 白：#f, 灰：#t, 黑：'done
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

### 5.3 命名空间别名解析

```racket
(define (resolve-qualified alias symbol-name)
  (define imported-mod (hash-ref namespace-aliases alias #f))
  (if imported-mod
      (lookup-symbol-in-module imported-mod symbol-name)
      (error (format "未找到命名空间别名: ~a" alias))))
```

### 5.4 包版本解析

```racket
(define (resolve-package pkg-name version)
  (cond
    [(string-prefix? pkg-name "./") pkg-name]       ;; 相对路径
    [(string-prefix? pkg-name "/") pkg-name]        ;; 绝对路径
    [else                                           ;; 包名
     (define pkg-dir (find-in-package-repo pkg-name version))
     (and pkg-dir (build-path pkg-dir "main.mingdao"))]))
```

---

## 六、影响范围

### 6.1 新建文件

| 文件 | 行数 | 职责 |
|------|------|------|
| `mingdao/lang/module.rkt` | ~250 行 | 模块系统核心（加载、解析、依赖检测、版本解析） |

### 6.2 修改文件

| 文件 | 变更 |
|------|------|
| `mingdao/lang/semantic.rkt` | `symbol-info` 新增 `public?`/`module` 字段；新增可见性检查 |
| `mingdao/lang/parser.rkt` | 解析 `公开`/`私有`/`模块`/`作为`/`使用`/`版本` |
| `mingdao/lang/reader.rkt` | 在 evaluate 前处理模块导入 |
| `mingdao/lang/function-names.rkt` | 新增关键字：`公开`/`私有`/`模块`/`作为`/`使用`/`版本` |

### 6.3 测试文件

| 文件 | 职责 |
|------|------|
| `mingdao/tests/test-module.rkt` | 模块系统测试（可见性、导入、循环依赖） |

---

## 七、扩展方向

- **包管理器** — 类似 npm/crates.io 的包仓库支持
- **条件导入** — `导入 "foo" 如果 条件`
- **动态导入** — `导入("path")` 在运行时加载
- **命名空间合并** — `导入 "./a"` 和 `导入 "./b"` 合并到同一命名空间