# 明道语言 LSP 增强设计文档

> **面向 AI 代理的工作者：** 此文档描述了如何将 M1（语义分析器）+ M2（类型推导）集成到 LSP 服务器中，实现悬停类型显示、语义级跳转、查找引用、上下文补全等功能。

**状态**: 已批准
**日期**: 2026-06-15
**目标**: M3 里程碑 — LSP 增强

---

## 一、目标

将语义分析器（`semantic.rkt`）的结果接入 LSP 服务器，实现以下增强：

1. **Hover** — 显示变量/函数的推导类型 + 文档
2. **Completion** — 上下文感知补全（变量名、内置函数、关键字）
3. **Definition** — 基于 scope 树的语义级跳转（不再用正则）
4. **Find References** — 新增功能：查找符号全部引用位置
5. **DocumentSymbol** — 从 scope 树提取文档符号列表
6. **Diagnostics** — 发布语义分析错误为 LSP 诊断

---

## 二、架构决策

### 数据流

```
编辑器请求 (hover/completion/definition)
    │
    ▼
handle-*  →  analyze-document(text)  →  analysis-result  →  提取查询结果
                     │                        │
               tokenize+parse+analyze    ast / errors / scope / lines
                     │
              semantic.rkt (M1+M2)
```

### 分析模式

| 方案 | 说明 | 决策 |
|------|------|------|
| **A: 每次请求重新分析（当前）** | handle-* 中调用 analyze-document | **采用** |
| B: 缓存分析结果 | didChange 时异步分析，缓存到 state | 未来可升级 |

**选择理由**：analyze 是纯内存操作，读入文件+分析在毫秒级。A 方案更简单、无状态、无需处理缓存失效。

---

## 三、新模块 analysis.rkt

### 3.1 职责

封装对文档的完整分析，为 LSP handler 提供查询接口。一次分析返回所有需要的数据结构。

### 3.2 核心结构

```racket
(struct analysis-result (ast           ;; 解析后的 AST (S-expression 列表)
                         errors        ;; 语义错误列表 (listof semantic-error)
                         global-scope  ;; 全局作用域（内含所有符号类型）
                         source-lines) ;; 源文件行列表 (listof string)
  #:transparent)
```

### 3.3 API

```racket
(define (analyze-document text builtin-names) → analysis-result)
(define (find-symbol-at-pos line char lines) → (or/c string? #f))
(define (find-definition word result) → (or/c location? #f))
(define (find-references word result) → (listof location))
(define (get-completions line char result) → (hash 'items (listof completion-item)))
(define (get-document-symbols result) → (listof symbol-info))
(define (get-hover-info word result) → (hash 'contents ...))
```

---

## 四、LSP Handler 增强

### 4.1 Hover — 显示类型 + 文档

**当前行为**：显示关键字文档（硬编码字符串）
**增强行为**：查询 scope 树获取符号类型，与关键字文档合并

```
输入：光标在 `x` 上
输出：
  明道悬停:
  **`x`**
  
  **类型**: `整数`
  
  ---
  符号: x
```

实现：
```racket
(define (compute-hover text line char builtin-names)
  (define result (analyze-document text builtin-names))
  (define word (find-symbol-at-pos line char (analysis-result-source-lines result)))
  (when word
    (define found (lookup-symbol word (analysis-result-global-scope result)))
    (define type-str
      (if found
          (format "\n\n**类型**: `~a`" (type->string (symbol-info-type (car found))))
          ""))
    (define doc (get-hover-doc word))
    (hash 'contents
          (hash 'kind "markdown"
                'value (format "**`~a`**~a\n\n---\n~a" word type-str doc)))))
```

### 4.2 Completion — 上下文感知补全

**当前行为**：返回所有关键字列表
**增强行为**：融合语义分析结果，补全优先级为：

1. 当前作用域中可见的变量名（来自 scope 树的 symbol 名）
2. 内置函数名（`builtin-function-names`）
3. 关键字（`定义`、`如果`、`对于` 等）

```racket
(define (get-completions line char result)
  (define scope (analysis-result-global-scope result))
  (define symbols (hash-keys (scope-symbols scope)))
  ;; 变量/函数名（优先级 1-2）
  (define var-completions
    (for/list ([name symbols])
      (hash 'label name
            'kind 6   ;; Variable
            'detail (type->string ...))))
  ;; 关键字（优先级 3）
  (define keyword-completions ...)
  (hash 'isIncomplete #f
        'items (append var-completions keyword-completions)))
```

### 4.3 Definition — 语义级跳转

**当前行为**：正则搜索 `定义 word 就`
**增强行为**：查 scope 树获取符号的定义位置

```racket
(define (compute-definition text uri line char builtin-names)
  (define result (analyze-document text builtin-names))
  (define word (find-symbol-at-pos line char ...))
  (define found (lookup-symbol word (analysis-result-global-scope result)))
  (when found
    (define info (car found))
    (hash 'uri uri
          'range (hash 'start (hash 'line (symbol-info-line info)
                                    'character (symbol-info-col info))
                       'end (hash 'line (symbol-info-line info)
                                  'character (+ (symbol-info-col info)
                                                (string-length word)))))))
```

### 4.4 Find References — 查找引用（新增）

遍历 AST 收集符号的所有引用位置：

```racket
(define (find-references word result)
  (define locations '())
  (define (walk expr)
    (match expr
      [(? symbol? s)
       (when (equal? (symbol->string s) word)
         (set! locations (cons ... locations)))]
      [`(,car . ,cdr) (walk car) (for ([e cdr]) (walk e))]
      [_ (void)]))
  (for ([expr (analysis-result-ast result)])
    (walk expr))
  ;; 返回 LSP 位置列表
  (map (λ (loc) (hash 'uri ... 'range ...)) locations))
```

### 4.5 DocumentSymbol — 从 scope 树提取

```racket
(define (get-document-symbols result)
  (define scope (analysis-result-global-scope result))
  (for/list ([(name info) (in-hash (scope-symbols scope))]
             #:unless (eq? (symbol-info-kind info) '内置函数))
    (hash 'name name
          'kind (match (symbol-info-kind info)
                  ['变量 13]     ;; Variable
                  ['函数 12]     ;; Function
                  ['参数 13]     ;; Variable
                  [_ 13])
          'range (hash 'start (hash 'line (symbol-info-line info)
                                    'character (symbol-info-col info))
                       'end (hash 'line (symbol-info-line info)
                                  'character (+ (symbol-info-col info)
                                                (string-length name)))))))
```

### 4.6 Diagnostics — 语义错误发布

```racket
;; 在 update-diagnostics 中集成语义分析结果
(define semantic-errs (analysis-result-errors result))
(define semantic-diags
  (for/list ([err semantic-errs])
    (hash 'range
          (hash 'start (hash 'line (semantic-error-line err)
                             'character (semantic-error-col err))
                'end (hash 'line (semantic-error-line err)
                          'character (+ (semantic-error-col err) 1)))
          'severity 2    ;; Warning
          'source "明道语义分析"
          'message (semantic-error-message err))))
```

---

## 五、影响范围

### 5.1 新增文件

| 文件 | 行数 | 职责 |
|------|------|------|
| `mingdao/tools/lsp/analysis.rkt` | ~200 行 | 语义分析结果索引 + 查询接口 |

### 5.2 修改文件

| 文件 | 行数变化 | 改动 |
|------|---------|------|
| `mingdao/tools/lsp/server.rkt` | +~120 行 | 增强 6 个 handler |
| `mingdao/tools/lsp/completion.rkt` | +~30 行 | 新增上下文感知补全 |
| `mingdao/tools/lsp/diagnostics.rkt` | +~20 行 | 接入语义错误 |
| `mingdao/tools/lsp/text-sync.rkt` | 无需修改 | — |

### 5.3 无需修改

| 文件 | 原因 |
|------|------|
| `lang/semantic.rkt` | M1/M2 API 已完整满足需求 |
| `lang/reader.rkt` | 与 LSP 集成无关 |
| `lang/tokenizer.rkt` / `lang/parser.rkt` | 经由 semantic.rkt 间接使用 |

---

## 六、扩展方向（未来）

- **缓存方案（方案 B）**：在 `lsp-server-state` 中增加 `analysis-cache` 哈希表（uri → analysis-result），`didChange` 时异步更新
- **签名帮助 （signature help）**：在函数调用括号内时显示参数类型列表
- **代码动作 （code actions）**：对未定义变量提供 `定义 xxx` 的快速修复
- **重命名 （rename）**：基于 scope 树实现符号重命名
- **代码格式化增强**：使用 parser 的 AST 做结构化格式化（而非当前的正则缩进）