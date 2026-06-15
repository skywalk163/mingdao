# 明道语言类型推导设计文档

> **面向 AI 代理的工作者：** 此文档描述了如何将类型推导集成到语义分析器中，使变量/函数定义时自动推导类型，无需额外类型标注。

**状态**: 已批准
**日期**: 2026-06-15
**目标**: M2 里程碑 — 类型推导

---

## 一、目标

在语义分析过程中同时推导并注册类型，使以下代码无需显式类型标注即可获得类型信息：

```racket
定义 x 就是 5              ;; x 推导为 '整数
定义 名字 就是 "张三"       ;; 名字 推导为 '字符串
定义 求加 就是函 a, b：
    返回 a 加 b            ;; 求加 推导为 参数:整数→整数(默认)
```

**核心原则**：类型推导是语义分析器的**扩展**而非新模块。现有 `semantic.rkt` 已遍历 AST 并有 symbol-info 结构（含 `type` 字段），只需在注册符号前推导值/表达式的类型。

---

## 二、架构决策

| 方案 | 说明 | 决策 |
|------|------|------|
| **A: 在 semantic.rkt 中内联推导** | 在现有 `analyze-expr` 流程中，分析表达式时同时返回类型值 | **采用** |
| B: 单独 type-inference.rkt 模块 | 新文件，语义分析后单独 pass | 拒绝：语义分析和推导共享一个 AST 遍历即可完成 |
| C: 在 type-checker.rkt 中增强 infer-type | 保持 semantic 不变，check-types 做推导 | 拒绝：类型信息需要注册到 symbol-info，语义分析器才有 scope 树 |

**选择理由**：方案 A 改动最小（仅修改 `semantic.rkt` ~50 行），直接复用现有遍历流程和 scope 树。

---

## 三、核心规则

### 3.1 字面量到类型映射

| 字面量类型 | Racket 谓词 | 推导结果 |
|-----------|-------------|---------|
| 整数 | `exact-integer?` | `'整数` |
| 浮点数 | `inexact-real?` | `'浮点数` |
| 字符串 | `string?` | `'字符串` |
| 布尔 | `boolean?` | `'布尔` |
| 空值 | `null?` | `'空值` |
| 符号 | `symbol?` | `'任意`（上下文推断） |

### 3.2 复合表达式映射

| AST 形式 | 推导规则 |
|---------|---------|
| `(if cond then else)` | 如果 then 和 else 类型相同则取该类型，否则 `'任意` |
| `(列表 items...)` | 如果所有元素类型相同→`(列表 T)`，否则 `'列表` |
| `(加 a b)` / `(减 a b)` / `(乘 a b)` / `(模 a b)` / `(幂 a b)` | 任一参数为 `'浮点数` 则 `'浮点数`，否则 `'整数` |
| `(除 a b)` | `'浮点数` |
| `(大于 a b)` / `(小于 a b)` / `(等于 a b)` / `(大于等于 a b)` / `(小于等于 a b)` / `(不等 a b)` | `'布尔` |
| `(长度 lst)` | `'整数` |
| `(转整数 val)` | `'整数` |
| `(转浮点数 val)` | `'浮点数` |
| `(数字转字符串 val)` | `'字符串` |
| `(绝对值 val)` | 参数类型 |
| `(函数名 args...)` | 查函数注册时的 symbol-info.type |

### 3.3 内置函数返回类型表

从现有 `type-checker.rkt` 移入 `builtin-return-types` 哈希表，覆盖所有内置函数名。仅在 `symbol-info` 中未查到类型时使用。

---

## 四、API 变更

### 4.1 semantic.rkt exports（新增）

```racket
(provide ...
         infer-type       ;; 新增：推导表达式的类型
         type->string)    ;; 新增：格式化类型为中文可读字符串

;; 推导表达式的类型
;; expr: S-expression
;; scope: 当前作用域（查找符号类型）
;; 返回: 类型符号（'整数 / '字符串 / '(列表 整数) / ...）
(define (infer-type expr scope)
  ...)

;; 格式化类型为可读字符串
(define (type->string t)
  "整数" / "浮点数" / "列表<整数>" / ...)
```

### 4.2 analyze 内部增强

现有 `analyze-expr` 增加返回类型：

```racket
(define (analyze-expr expr current-scope)
  (match expr
    [`(define ,(? symbol? name) ,val)
     (define val-type (infer-type val current-scope))   ;; ← 新增
     (register-with-checks! (symbol-name name) name '变量 #t current-scope add-error!
                            val-type)                   ;; ← 新增参数
     (values)]
    ...))
```

---

## 五、实现策略

### 5.1 infer-type 实现路径

```racket
(define (infer-type expr scope)
  (match expr
    ;; 字面量
    [(? exact-integer?) '整数]
    [(? inexact-real?) '浮点数]
    [(? string?) '字符串]
    [(? boolean?) '布尔]
    [(? null?) '空值]
    ;; 符号引用
    [(? symbol? s)
     (define name (symbol->string s))
     (define found (lookup-symbol name scope))
     (if found
         (or (symbol-info-type (car found)) '任意)
         '任意)]
    ;; 二元运算
    [`(,op ,a ,b)
     (cond
       [(member op '(加 减 乘 模 幂))
        (let ([ta (infer-type a scope)]
              [tb (infer-type b scope)])
          (if (or (eq? ta '浮点数) (eq? tb '浮点数)) '浮点数 '整数))]
       [(eq? op '除) '浮点数]
       [(member op '(大于 小于 等于 不等 大于等于 小于等于 equal?))
        '布尔]
       [else (infer-builtin-return op scope)])]
    ;; if
    [`(if ,_ ,then ,else)
     (let ([tt (infer-type then scope)]
           [te (infer-type else scope)])
       (if (equal? tt te) tt '任意))]
    ;; 函数调用
    [`(,(? symbol? fn) . ,args)
     (infer-builtin-return fn scope)]
    ;; 列表字面量
    [`(列表 . ,items)
     (if (null? items)
         '列表
         (let ([ts (map (λ (e) (infer-type e scope)) items)])
           (if (for/and ([t ts]) (equal? t (car ts)))
               `(列表 ,(car ts))
               '列表)))]
    ;; return / set! / 赋值引用右值
    [`(return ,val) (infer-type val scope)]
    [`(= ,_ ,val) (infer-type val scope)]
    [`(set! ,_ ,val) (infer-type val scope)]
    [_ '任意]))
```

### 5.2 函数返回类型推导

函数定义 `(define (fn p1 p2) body... )` 的返回类型：
- 如果 body 中有 `(return val)` → 取返回值类型
- 否则取 body 最后一条表达式的类型
- 如果推导不出 → `'任意`

```racket
;; 在 analyze-expr 的 define (fn . params) . body) 分支中：
(define return-type
  ;; body 中找 return 语句
  (let loop ([b body])
    (cond
      [(null? b) '任意]
      [(pair? (car b))
       (let ([tag (car (car b))])
         (cond
           [(eq? tag 'return) (infer-type (cadr (car b)) child-scope)]
           [else (loop (cdr b))]))]
      [else (loop (cdr b))])))
;; 如果没找到 return，取最后一条表达式的类型
(if (eq? return-type '任意)
    (and (pair? body) (infer-type (last body) child-scope))
    return-type)
;; 注册函数时附带返回类型
(define-symbol! fn-str
  (symbol-info '函数 (or return-type '任意) line col #f #t)
  scope)
```

### 5.3 参数类型默认规则

函数参数在没有显式类型标注时默认推导为 `'任意`。未来可通过 `参数：整数` 语法增强。

---

## 六、测试设计

新建 `tests/test-type-inference.rkt`（或合并到 `test-semantic.rkt`）：

| 测试 | 代码 | 预期类型 |
|------|------|---------|
| 整数推导 | `定义 x 就是 5` → 检查 x 类型 | `'整数` |
| 字符串推导 | `定义 s 就是 "hello"` → 检查 s 类型 | `'字符串` |
| 布尔推导 | `定义 b 就是 真值` → 检查 b 类型 | `'布尔` |
| 算术运算推导 | `定义 r 就是 5 加 3` → 检查 r 类型 | `'整数` |
| 除法推导 | `定义 r 就是 5 除 2` → 检查 r 类型 | `'浮点数` |
| 条件推导 | `定义 r 就是 如果 真值 那么 1 否则 0` → 检查 r 类型 | `'整数` |
| 函数返回推导 | `定义 双倍 就是函 x：返回 x 加 x` → 检查 双倍 类型 | `'任意`（暂时） |
| 列表推导 | `定义 lst 就是 列表 1, 2, 3` → 检查 lst 类型 | `'(列表 整数)` |

---

## 七、文件清单

| 文件 | 变更 | 说明 |
|------|------|------|
| `mingdao/lang/semantic.rkt` | ~+50 行 | 新增 infer-type、type->string；analyze-expr 增加类型推导 |
| `mingdao/tests/test-semantic.rkt` | ~+80 行（或新建） | 新增类型推导测试用例 |

---

## 八、扩展方向（未来）

- **参数类型标注**: `函(a：整数, b：字符串)：布尔 → body`
- **递归函数类型**: 函数体内引用自身的类型传播
- **联合类型推导**: 条件分支类型合并（if, match）
- **泛型函数**: `fn<T>(x: T) → T`