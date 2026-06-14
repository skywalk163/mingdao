# 明道语言语义分析器设计文档

**状态**: 已批准
**日期**: 2026-06-14
**目标**: M1 里程碑 — 语义分析器

---

## 一、目标

在 parser 和 type-checker 之间新增语义分析阶段，对 AST 做编译时检查：

- 变量未定义 / 重复定义检测
- 作用域链追踪
- 常量赋值检测
- 函数参数数量校验

语义分析器输出结构化错误列表，不阻断执行（类似 TypeScript 的警告模式）。

---

## 二、架构决策

### 方案选择

| 方案 | 说明 | 决策 |
|------|------|------|
| **A: 独立 AST 分析器** | 新文件 `semantic.rkt`，接收 parser 输出的 AST，一次遍历完成所有检查 | **采用** |
| B: 解析时内联分析 | 在 parser.rkt 内嵌检查逻辑 | 拒绝：parser 已有 1900+ 行，继续膨胀难以维护 |
| C: 规则引擎 + Visitor | 设计通用 AST Visitor，规则可插件化 | 拒绝：过度设计，M1 只需要确定性检查 |

**选择理由**：方案 A 符合现有 type-checker 的平行结构，LSP 可直接复用语义分析结果。

### 集成位置

```
Tokenizer → Parser → [Semantic Analyzer] → Type Checker → Runtime
                         ↑ 新增
```

---

## 三、核心数据结构

### 3.1 作用域节点 (scope)

```racket
(struct scope (parent    ;; 父作用域（#f 表示全局）
               symbols   ;; (hash symbol-name → symbol-info)
               children) ;; 子作用域列表
  #:transparent)
```

- 全局作用域是整个程序的根（parent = #f）
- 每个函数体创建新的子作用域
- `如果`/`对于`/`当满足`/`尝试` 的块也创建子作用域
- 作用域链用于名字解析：当前 → 父 → 祖父 → ... → 全局

### 3.2 符号信息 (symbol-info)

```racket
(struct symbol-info (kind     ;; '变量 '函数 '参数 '内置函数 '类型别名
                     type     ;; 类型标注（可选，symbol 或 #f）
                     line     ;; 定义行号
                     col      ;; 定义列号
                     mutable? ;; 是否可变（#t=变量 #f=常量）
                     defined?) ;; 是否已定义（用于前向引用检查）
  #:transparent)
```

### 3.3 语义错误 (semantic-error)

```racket
(struct semantic-error (type         ;; 'undefined-var 'redefined 'shadowed 'unused 'constant-assign 'undefined-fn
                        message      ;; 中文错误描述
                        line         ;; 错误行号
                        col          ;; 错误列号
                        suggestion)   ;; 修复建议（字符串或 #f）
  #:transparent)
```

### 3.4 错误类型对照表

| 错误类型 | 触发条件 | 示例 |
|---------|---------|------|
| `undefined-var` | 引用不在作用域链中的符号 | `(set! x 5)` 但 x 未定义 |
| `redefined` | 同一作用域内同名变量/函数 | `定义 x 就是 1` 后又 `定义 x 就是 2` |
| `shadowed` | 子作用域遮蔽父作用域变量 | 全局有 x，函数内又定义 x（警告） |
| `constant-assign` | 对 `常量` 定义的变量执行 `赋值` | `常量 x 就是 1` 后 `赋值 x 为 2` |
| `undefined-fn` | 调用未注册的函数 | `未知函数(1, 2)` |
| `wrong-arity` | 内置函数参数数量不匹配 | `打印(1, 2, 3)` 但打印只接受 1 个参数 |

---

## 四、API 设计

```racket
#lang racket/base

(provide analyze          ;; 主入口
         semantic-error   ;; 错误结构
         scope symbol-info  ;; 作用域/符号结构
         make-global-scope  ;; 构造全局作用域
         lookup-symbol      ;; 查找符号
         define-symbol!)    ;; 注册符号
```

### 4.1 主入口

```racket
;; 对 AST 做语义分析，返回错误列表
;; ast: parser 输出的 S-expression 列表
;; builtin-names: 内置函数名列表
;; 返回: (listof semantic-error)
(define (analyze ast builtin-names) ...)
```

### 4.2 作用域操作

```racket
;; 创建全局作用域
(define (make-global-scope builtin-names)
  (let ([scope (scope #f (make-hash) '())])
    (for ([name builtin-names])
      (hash-set! (scope-symbols scope) name
                 (symbol-info '内置函数 #f 0 0 #t #t)))
    scope))

;; 在作用域链中查找符号，返回 (cons symbol-info scope) 或 #f
(define (lookup-symbol name current-scope) ...)

;; 在当前作用域注册符号（不检查重复）
(define (define-symbol! name info current-scope) ...)
```

---

## 五、分析引擎

### 5.1 遍历策略

采用深度优先遍历 AST，对每类节点调用对应的分析函数：

```
analyze(ast, scope)
  └── analyze-statement(expr, scope)
        ├── define      → 注册变量，递归分析值
        ├── set!        → 检查变量存在，递归分析值
        ├── if          → 递归分析条件，真分支，假分支
        ├── for         → 创建子作用域，递归分析循环体
        ├── fn 调用      → 递归分析参数
        └── ...
```

### 5.2 AST 节点类型映射

| AST 形式 | 分析函数 |
|---------|---------|
| `(define name val)` | 注册变量到当前作用域 |
| `(define (fn . params) . body)` | 创建子作用域，注册参数，递归分析 body |
| `(set! var val)` | 检查 var 在作用域链中存在且可变 |
| `(= var val)` | 同上（赋值语法） |
| `(if cond then else)` | 分析条件，创建子作用域分析分支 |
| `(for var from to body)` | 创建子作用域分析循环体 |
| `(for-each var lst body)` | 创建子作用域分析循环体 |
| `(let/ec . body)` | 创建子作用域（do-while 循环） |
| `(匹配 val . clauses)` | 分析各分支 |
| `(尝试 body . handlers)` | 分析 body 和各 handler |
| `(,(? symbol?) . args)` | 检查函数是否定义，递归分析参数 |
| `(? symbol?)` | 检查变量在作用域链中存在 |
| `(导入 .)` | 跳过（模块系统未来扩展） |
| `(mingdao-export .)` | 跳过 |

---

## 六、错误消息示例

```racket
;; 未定义变量
(semantic-error
  'undefined-var
  "未定义的变量 'x'（第 5 行第 3 列）"
  5 3
  "是否忘记用「定义」声明？")

;; 重复定义
(semantic-error
  'redefined
  "变量 'count' 重复定义（首次定义在第 2 行）"
  10 1
  "可以重命名其中一个变量，或者移除旧的定义")

;; 常量赋值
(semantic-error
  'constant-assign
  "常量 'PI' 不可赋值修改（定义在第 1 行）"
  8 1
  "用「常量」定义的变量不可修改，请使用「定义」")
```

---

## 七、与现有模块的集成

### 7.1 reader.rkt 集成

```racket
;; 在 read 函数中，parse 之后调用 analyze
(let* ([tokens (tokenize content)]
       [ast (parse tokens)]
       [semantic-errors (analyze ast builtin-function-names)])
  ;; 显示警告但不阻断执行
  (for ([err semantic-errors])
    (displayln (format-semantic-error err content)))
  ...)
```

### 7.2 LSP 集成

`tools/lsp/server.rkt` 可直接调用 `semantic.rkt` 的 `analyze` 函数获取诊断信息，无需重复解析 AST。

### 7.3 类型检查器集成

语义分析输出的符号表（scope tree）可被 type-checker 复用，用于：
- 获取变量/参数的类型标注
- 追踪作用域链以解析名字引用

---

## 八、测试设计

新建 `tests/test-semantic.rkt`，使用 rackunit 框架：

| 测试用例 | 输入代码 | 期望结果 |
|---------|---------|---------|
| `test-undefined-var` | `赋值 x 为 5` | 1 个 `undefined-var` 错误 |
| `test-redefined` | `定义 x 就是 1` + `定义 x 就是 2` | 1 个 `redefined` 错误 |
| `test-correct-usage` | `定义 x 就是 1` + `x, 打印` | 0 个错误 |
| `test-scope-chain` | 全局定义 x，函数内引用 x | 0 个错误 |
| `test-constant-assign` | `常量 x 就是 1` + `赋值 x 为 2` | 1 个 `constant-assign` 错误 |
| `test-undefined-fn` | `未知函数(1, 2)` | 1 个 `undefined-fn` 错误 |
| `test-shadowing` | 全局 x，函数参数也 x | 1 个 `shadowed` 警告 |
| `test-function-body` | 函数内定义局部变量，函数外引用 | 1 个 `undefined-var` 错误 |

---

## 九、文件清单

| 文件 | 行数估算 | 说明 |
|------|---------|------|
| `mingdao/lang/semantic.rkt` | ~300 行 | 语义分析器核心 |
| `mingdao/tests/test-semantic.rkt` | ~200 行 | 测试用例 |

---

## 十、扩展方向（未来）

- **返回语句检查**: 检查函数是否有无效的返回（如死代码）
- **未使用变量检测**: 检测声明但未使用的变量
- **类型推导**: 结合现有 type-checker 实现 Hindley-Milner 类型推导
- **跨模块分析**: 符号表支持导出/导入，实现模块间的语义分析

---

## 十一、验收标准

1. `tests/test-semantic.rkt` 所有测试通过
2. 以下代码能正确检测语义错误：
   - 使用未定义变量 → `undefined-var`
   - 重复定义变量 → `redefined`
   - 赋值常量 → `constant-assign`
   - 调用未定义函数 → `undefined-fn`
3. `reader.rkt` 集成 `analyze` 函数，显示错误但不阻断执行
4. 现有 `tests/test-basic.rkt` 等测试文件不受影响
