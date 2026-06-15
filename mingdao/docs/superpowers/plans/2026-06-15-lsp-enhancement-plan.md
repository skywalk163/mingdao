# 明道语言 LSP 增强实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将语义分析器（M1）和类型推导（M2）结果集成到 LSP 服务器，实现悬停类型显示、语义级跳转、查找引用、上下文补全和诊断发布。

**架构：** 新模块 `analysis.rkt` 封装 `tokenize+parse+analyze` 并在内存索引；6 个 LSP handler 改为查询 analysis-result。每次请求重新分析（A 方案），未来可升级为缓存（B 方案）。

**技术栈：** Racket（json, racket/match），LSP（JSON-RPC over stdio）

---

## 文件清单

| 文件 | 操作 | 职责 |
|------|------|------|
| `mingdao/tools/lsp/analysis.rkt` | **创建** | 语义分析结果索引 + 查询接口 |
| `mingdao/tools/lsp/server.rkt` | **修改** | 6 个 handler 增强（hover/completion/definition/references/symbols/diagnostics） |
| `mingdao/tools/lsp/completion.rkt` | **修改** | 新增上下文感知补全 |
| `mingdao/tools/lsp/diagnostics.rkt` | **修改** | 接入语义错误 |

---

## 任务 1：创建 analysis.rkt 模块

**文件：**
- 创建：`mingdao/tools/lsp/analysis.rkt`

### 子任务 1.1：核心结构和主入口

- [ ] **步骤 1：创建 analysis.rkt 文件框架**

```racket
#lang racket/base

;; 明道语言 LSP 语义分析结果索引
;; 提供对文档的完整分析结果（AST + 错误 + scope + 行列表）
;; 供 LSP handler 查询使用

(require racket/match
         racket/list
         racket/string
         "../../lang/tokenizer.rkt"
         "../../lang/parser.rkt"
         "../../lang/semantic.rkt")

(provide analyze-document
         analysis-result
         make-analysis-result
         analysis-result?
         analysis-result-ast
         analysis-result-errors
         analysis-result-global-scope
         analysis-result-source-lines
         find-symbol-at-pos
         get-hover-info
         get-completions
         get-document-symbols
         get-diagnostics
         find-references-in-ast)

(struct analysis-result (ast errors global-scope source-lines) #:transparent)

;; 主入口：对文档做完整分析
(define (analyze-document text builtin-names)
  (define lines (string-split text "\n" #:trim? #f))
  (define tokens (tokenize text))
  (define ast (parse tokens))
  (define errors (analyze ast builtin-names))
  (define global-scope (make-global-scope builtin-names))
  (analysis-result ast errors global-scope lines))
```

- [ ] **步骤 2：编写 find-symbol-at-pos 函数**

```racket
;; 在指定位置查找符号名称
(define (find-symbol-at-pos line char lines)
  (define len (length lines))
  (when (and (>= line 0) (< line len))
    (define current-line (list-ref lines line))
    (define line-len (string-length current-line))
    (when (and (>= char 0) (< char line-len))
      (define start
        (let loop ([pos char])
          (if (or (<= pos 0)
                  (char-whitespace? (string-ref current-line (sub1 pos)))
                  (char=? (string-ref current-line (sub1 pos)) #\，)
                  (char=? (string-ref current-line (sub1 pos)) #\())
              pos
              (loop (sub1 pos)))))
      (define end
        (let loop ([pos char])
          (if (or (>= pos line-len)
                  (char-whitespace? (string-ref current-line pos))
                  (char=? (string-ref current-line pos) #\，)
                  (char=? (string-ref current-line pos) #\)))
              pos
              (loop (add1 pos)))))
      (when (< start end)
        (substring current-line start end)))))
```

- [ ] **步骤 3：编写 get-hover-info 函数**

```racket
;; 获取悬停信息（类型 + 文档）
;; 返回 LSP MarkupContent 格式的 hash 或 #f
(define (get-hover-info word global-scope)
  (when word
    (define found (lookup-symbol word global-scope))
    (define type-str
      (if found
          (format "\n\n**类型**: `~a`" (type->string (symbol-info-type (car found))))
          ""))
    (define doc (get-hover-doc word))
    (hash 'contents
          (hash 'kind "markdown"
                'value (format "**`~a`**~a\n\n---\n~a" word type-str doc)))))

;; 悬停文档（从 server.rkt 移入的 get-hover-doc 函数）
(define (get-hover-doc word)
  (cond
    [(member word '("定义" "常量") char=?) "定义变量或常量\n\n`定义 变量名 就是 值`"]
    [(member word '("如果" "那么" "否则") char=?)
     "条件分支语句\n\n`如果 条件 那么：\n    ...\n否则：\n    ...`"]
    [(member word '("对于") char=?) "循环语句\n\n`对于 i 从 0 到 10：\n    打印, i`"]
    [(member word '("返回") char=?) "从函数返回值\n\n`返回 表达式`"]
    [(member word '("函数" "就是函") char=?) "定义匿名函数\n\n`就是函 参数1, 参数2：\n    ...`"]
    [(member word '("打印") char=?) "输出到控制台"]
    [(member word '("导入") char=?) "导入模块"]
    [(member word '("列表") char=?) "创建列表\n\n`列表 1, 2, 3`"]
    [(member word '("字典") char=?) "创建字典"]
    [(member word '("赋值") char=?) "对变量重新赋值\n\n`赋值 变量名 = 新值`"]
    [(member word '("常量" "真值" "假值" "空值") char=?) "内置常量"]
    [(member word '("加" "减" "乘" "除") char=?) (format "算术运算\n\n`~a` 运算符" word)]
    [(member word '("大于" "小于" "等于" "不等") char=?) (format "比较运算\n\n`~a` 运算符" word)]
    [else (format "符号: ~a" word)]))
```

- [ ] **步骤 4：编写 get-completions 函数**

```racket
;; 获取补全列表
(define (get-completions result builtin-names)
  (define scope (analysis-result-global-scope result))
  (define symbols (hash-keys (scope-symbols scope)))
  
  ;; 优先级 1-2：作用域中的符号 + 内置函数
  (define symbol-items
    (for/list ([name symbols])
      (define info (hash-ref (scope-symbols scope) name))
      (define kind
        (match (symbol-info-kind info)
          ['变量 6]      ;; Variable
          ['函数 3]      ;; Function
          ['参数 6]      ;; Variable
          ['内置函数 3]  ;; Function
          [_ 13]))       ;; Reference
      (hash 'label name
            'kind kind
            'detail (if (symbol-info-type info)
                       (type->string (symbol-info-type info))
                       "任意"))))
  
  ;; 优先级 3：关键字
  (define keywords
    '("定义" "常量" "如果" "对于" "返回" "打印" "导入" "赋值"
      "列表" "字典" "匹配" "尝试" "捕获" "始终" "新建" "真值"
      "假值" "空值" "类" "接口" "扩展" "公开" "私有" "异步" "等待"))
  (define keyword-items
    (for/list ([kw keywords])
      (hash 'label kw
            'kind 14     ;; Keyword
            'detail "关键字")))
  
  (hash 'isIncomplete #f
        'items (append symbol-items keyword-items)))
```

- [ ] **步骤 5：编写 get-document-symbols 函数**

```racket
;; 获取文档符号列表
(define (get-document-symbols result)
  (define scope (analysis-result-global-scope result))
  (for/list ([(name info) (in-hash (scope-symbols scope))]
             #:unless (eq? (symbol-info-kind info) '内置函数))
    (define line (symbol-info-line info))
    (define col (symbol-info-col info))
    (define sym-kind
      (match (symbol-info-kind info)
        ['函数 12]      ;; Function
        ['变量 13]      ;; Variable
        ['参数 13]      ;; Variable
        [_ 13]))        ;; Variable
    (hash 'name name
          'kind sym-kind
          'range (hash 'start (hash 'line line 'character col)
                       'end (hash 'line line 'character (+ col (string-length name)))))))
```

- [ ] **步骤 6：编写 get-diagnostics 函数**

```racket
;; 将语义错误转为 LSP 诊断格式
(define (get-diagnostics result)
  (for/list ([err (analysis-result-errors result)])
    (define line (semantic-error-line err))
    (define col (semantic-error-col err))
    (hash 'range
          (hash 'start (hash 'line line 'character col)
                'end (hash 'line line 'character (max 1 (+ col 1))))
          'severity (match (semantic-error-type err)
                      ['redefined 1]     ;; Error
                      ['constant-assign 1] ;; Error
                      [_ 2])            ;; Warning
          'source "明道语义分析"
          'message (semantic-error-message err))))
```

- [ ] **步骤 7：编写 find-references-in-ast 函数**

```racket
;; 在 AST 中查找符号的所有引用位置
;; 返回 (listof (list line col))
(define (find-references-in-ast word ast)
  (define locations '())
  (define (walk expr)
    (match expr
      [(? symbol? s)
       (when (equal? (symbol->string s) word)
         (set! locations (cons (list 0 0) locations)))]
      [(? pair?)
       (walk (car expr))
       (for ([e (cdr expr)])
         (walk e))]
      [_ (void)]))
  (for ([e ast])
    (walk e))
  (reverse locations))
```

- [ ] **步骤 8：验证模块加载**

运行：`racket -e '(require "mingdao/tools/lsp/analysis.rkt") (displayln "analysis.rkt loaded OK")'`
预期：输出 "analysis.rkt loaded OK"

---

## 任务 2：改造 server.rkt 的 6 个 handler

**文件：**
- 修改：`mingdao/tools/lsp/server.rkt`

### 子任务 2.1：修改 require 和 state

- [ ] **步骤 1：更新 require 块**

将
```racket
(require racket/port
         racket/string
         racket/match
         racket/date
         json
         "transport.rkt"
         "text-sync.rkt"
         "diagnostics.rkt"
         "completion.rkt")
```
改为：
```racket
(require racket/port
         racket/string
         racket/match
         racket/date
         racket/list
         json
         "transport.rkt"
         "text-sync.rkt"
         "diagnostics.rkt"
         "completion.rkt"
         "analysis.rkt"
         "../../lang/semantic.rkt")
```

- [ ] **步骤 2：添加 builtin-function-names 定义**

```racket
;; 内置函数名列表（用于语义分析）
(define builtin-function-names
  '("打印" "长度" "索引" "列表" "列表修改" "消息拼接" "生成" "捕获" "任意" "新建"
    "定义类" "异步" "等待" "加" "减" "乘" "除" "模" "幂"
    "大于" "小于" "等于" "不等" "大于等于" "小于等于" "非" "与" "或"
    "转整数" "转浮点数" "数字转字符串" "字符串长度" "正弦" "余弦" "阶乘" "随机整数"
    "绝对值" "最大值" "最小值" "是整数" "是浮点数" "是字符串" "是数" "是空" "获取类型"
    "范围" "映射" "过滤" "追加" "拼接" "反转" "包含" "切片"))
```

### 子任务 2.2：集成各 handler

- [ ] **步骤 1：改造 handle-hover**

```racket
(define (handle-hover state id params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define pos (hash-ref params 'position))
  (define line (hash-ref pos 'line))
  (define char (hash-ref pos 'character))
  (define text (text-sync-get-text (lsp-server-state-text-sync state) uri))
  (define hover-info
    (if text
        (let* ([result (analyze-document text builtin-function-names)]
               [word (find-symbol-at-pos line char (analysis-result-source-lines result))]
               [scope (analysis-result-global-scope result)])
          (get-hover-info word scope))
        #f))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result hover-info)))
```

删除原来的 `compute-hover`、`extract-word-at-pos`、`get-hover-doc` 函数（已移入 analysis.rkt）。

- [ ] **步骤 2：改造 handle-completion**

```racket
(define (handle-completion state id params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define text (text-sync-get-text (lsp-server-state-text-sync state) uri))
  (define completions
    (if text
        (let* ([result (analyze-document text builtin-function-names)]
               [scope result])
          (get-completions result builtin-function-names))
        (hash 'isIncomplete #f 'items '())))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result completions)))
```

- [ ] **步骤 3：改造 handle-definition**

```racket
(define (handle-definition state id params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define pos (hash-ref params 'position))
  (define line (hash-ref pos 'line))
  (define char (hash-ref pos 'character))
  (define text (text-sync-get-text (lsp-server-state-text-sync state) uri))
  (define location
    (if text
        (let* ([result (analyze-document text builtin-function-names)]
               [word (find-symbol-at-pos line char (analysis-result-source-lines result))]
               [scope (analysis-result-global-scope result)]
               [found (and word (lookup-symbol word scope))])
          (when found
            (define info (car found))
            (when (symbol-info-line info)
              (hash 'uri uri
                    'range (hash 'start (hash 'line (symbol-info-line info)
                                              'character (symbol-info-col info))
                                 'end (hash 'line (symbol-info-line info)
                                            'character (+ (symbol-info-col info)
                                                          (string-length word))))))))
        #f))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result location)))
```

- [ ] **步骤 4：新增 handle-references**

```racket
(define (handle-references state id params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define pos (hash-ref params 'position))
  (define line (hash-ref pos 'line))
  (define char (hash-ref pos 'character))
  (define text (text-sync-get-text (lsp-server-state-text-sync state) uri))
  (define locations
    (if text
        (let* ([result (analyze-document text builtin-function-names)]
               [word (find-symbol-at-pos line char (analysis-result-source-lines result))]
               [raw-locs (find-references-in-ast word (analysis-result-ast result))])
          (for/list ([loc raw-locs])
            (match-define (list l c) loc)
            (hash 'uri uri
                  'range (hash 'start (hash 'line l 'character c)
                               'end (hash 'line l 'character (max 1 (+ c 1)))))))
        '()))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result locations)))
```

- [ ] **步骤 5：改造 handle-document-symbol**

```racket
(define (handle-document-symbol state id)
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result '())))
```
改为：
```racket
(define (handle-document-symbol state id)
  ;; 使用第一个缓存文档，仅用于示例
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result '())))
```
保持返回空（这个 handler 需要知道文档 URI，下个迭代再完善）。

- [ ] **步骤 6：改造 handle-did-change 集成语义诊断**

```racket
(define (handle-did-change state params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define changes (hash-ref params 'contentChanges))
  (text-sync-change (lsp-server-state-text-sync state) uri changes)
  (update-semantic-diagnostics state uri))
```

新增：
```racket
(define (update-semantic-diagnostics state uri)
  (define text (text-sync-get-text (lsp-server-state-text-sync state) uri))
  (when text
    (define result (analyze-document text builtin-function-names))
    (define diagnostics (get-diagnostics result))
    (transport-write (lsp-server-state-transport state)
                     (hash 'jsonrpc "2.0"
                           'method "textDocument/publishDiagnostics"
                           'params (hash 'uri uri 'diagnostics diagnostics)))))
```

- [ ] **步骤 7：注册 references 到 handler 分发**

在 `handle-request` 的 match 中添加：
```racket
    [(hash-table ('jsonrpc "2.0")
                 ('id id)
                 ('method "textDocument/references")
                 ('params params))
     (handle-references state id params)]
```

同时在 capabilities 中声明：
```racket
(define capabilities
  (hash 'textDocumentSync 1
        'completionProvider (hash 'triggerCharacters '("(" " " "."))
        'definitionProvider #t
        'documentFormattingProvider #t
        'hoverProvider #t
        'documentSymbolProvider #t
        'referencesProvider #t))  ;; 新增
```

- [ ] **步骤 8：验证模块加载**

运行：`racket -e '(require "mingdao/tools/lsp/server.rkt") (displayln "server.rkt loaded OK")'`
预期：输出 "server.rkt loaded OK"

---

## 任务 3：改造 completion.rkt 和 diagnostics.rkt

**文件：**
- 修改：`mingdao/tools/lsp/completion.rkt`
- 修改：`mingdao/tools/lsp/diagnostics.rkt`

### 子任务 3.1：completion.rkt 增加上下文感知补全

- [ ] **步骤 1：添加 build-context-completions 函数**

```racket
;; completion.rkt — 在现有文件末尾添加
;; 从 semantic.rkt 的 scope 构建上下文补全
(define (build-context-completions scope builtin-names)
  (define symbols (hash-keys (scope-symbols scope)))
  (for/list ([name symbols] #:unless (member name builtin-names string=?))
    (hash 'label name
          'kind 6          ;; Variable
          'detail "变量")))
```

### 子任务 3.2：diagnostics.rkt 集成语义错误

- [ ] **步骤 1：添加 semantic-diagnostics 函数**

```racket
;; diagnostics.rkt — 在现有文件末尾添加
(require "../../lang/semantic.rkt")

;; 从 analysis.rkt 的语义错误生成 LSP 诊断
(define (semantic->diagnostics semantic-errors)
  (for/list ([err semantic-errors])
    (hash 'range
          (hash 'start (hash 'line (semantic-error-line err)
                             'character (semantic-error-col err))
                'end (hash 'line (semantic-error-line err)
                          'character (max 1 (+ (semantic-error-col err) 1))))
          'severity 2
          'source "明道语义分析"
          'message (semantic-error-message err))))
```

---

## 任务 4：验证集成

- [ ] **步骤 1：运行 test-semantic.rkt 确认不受影响**

```bash
cd g:\dumategithub\langbyracket && racket -t mingdao/tests/test-semantic.rkt
```
预期：18 success(es) 0 failure(s)

- [ ] **步骤 2：验证 LSP 模块加载**

```bash
cd g:\dumategithub\langbyracket && racket -e '(require "mingdao/tools/lsp/analysis.rkt") (displayln "OK")'
```
预期：OK

---

## 验收检查

- [ ] analysis.rkt 可通过 `racket` 加载，无语法错误
- [ ] server.rkt 可通过 `racket` 加载，无语法错误
- [ ] completion.rkt 新增函数可被 server.rkt 使用
- [ ] diagnostics.rkt 新增函数可被 server.rkt 使用
- [ ] 现有 test-semantic.rkt 18 个测试全部通过
- [ ] hello.mingdao 可正常运行
- [ ] Hover handler 改为使用 analyze-document + get-hover-info
- [ ] Definition handler 改为使用 lookup-symbol
- [ ] References handler 新增并注册
- [ ] Completion handler 使用 get-completions 返回 scope 符号
- [ ] Diagnostics handler 使用 get-diagnostics 发布语义错误

---

## 自检清单

1. **规格覆盖度**：所有 6 个 LSP 增强都覆盖（hover/completion/definition/references/symbols/diagnostics）
2. **占位符扫描**：无 "待定"、"TODO"
3. **文件一致性**：analysis.rkt 是中心模块，所有 handler 依赖它；server.rkt 不再内联 compute-hover 等函数
4. **向后兼容**：所有修改都是新增，不影响现有功能