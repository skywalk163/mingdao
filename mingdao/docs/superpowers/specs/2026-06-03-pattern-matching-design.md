# 明道语言 - 模式匹配（`匹配`）设计规格

> 日期：2026-06-03
> 状态：已批准（待实现）

## 1. 动机

自举解析器（`std/parser.mingdao`）中用大量 `如果/是否相等` 嵌套来模拟模式匹配，导致代码冗长且难以维护。语言级别的模式匹配可以大幅简化此类代码。

## 2. 语法

### 2.1 完整语法

```
匹配 <表达式>:
  <模式1> 那么: <体1>
  <模式2> 那么: <体2>
  ...
  否则: <默认体>
```

`匹配` 是关键字，`那么` 是分支分隔符，`否则` 是兜底分支。

### 2.2 体语法

每个分支的体可以有两种形式：

```racket
;; 单行体
  0 那么: 返回 0

;; 缩进多行体
  [a, b] 那么:
    定义 sum 就是 加 a, b
    打印 sum
    sum
```

### 2.3 守卫语法

```
匹配 值:
  n 如果 (> n 0) 那么: 正数处理 n
  n 如果 (< n 0) 那么: 负数处理 n
  否则: 零处理
```

守卫条件支持任何表达式。

## 3. 模式类型（v1）

### 3.1 字面量模式

匹配精确值：

```racket
匹配 值:
  1 那么: "一"
  "hello" 那么: "问候"
  真值 那么: "真"
  空值 那么: "空"
```

支持的类型：数字、字符串、`真值`/`假值`、`空值`。

### 3.2 通配符模式

`_` 或 `任意` 匹配任何值，不绑定：

```racket
匹配 x:
  _ 那么: "任何值"
```

### 3.3 变量绑定模式

标识符匹配任何值并绑定到该变量，可在体中使用：

```racket
匹配 x:
  n 那么: 加 n, 1
```

注意：`_` 和 `任意` 是保留通配符，不产生绑定。其他单标识符都是变量绑定。

### 3.4 列表解构模式

`[模式1, 模式2, ...]` 匹配列表并解构元素：

```racket
匹配 lst:
  [a, b] 那么: 加 a, b
  [a] 那么: a
  _ 那么: 空值
```

- 列表模式要求列表长度严格匹配
- 元素本身可以是任意模式（支持嵌套：`[[a, b], c]`）

### 3.5 守卫模式

模式 + `如果` + 条件表达式：

```racket
匹配 n:
  x 如果 (> x 10) 那么: "大"
  x 如果 (> x 5) 那么: "中"
  _ 那么: "小"
```

守卫条件在模式匹配成功后额外验证。

## 4. 匹配顺序与语义

1. 先计算 `<表达式>` 的值
2. 从上到下依次尝试每个分支
3. 每个分支：先匹配模式，如果带守卫则再验证守卫条件
4. 第一个匹配成功（模式+守卫）的分支执行其体
5. 如果所有分支都不匹配，执行 `否则` 分支
6. `否则` 分支是强制要求的（除非编译器能静态证明全覆盖）

## 5. 实现方案

### 5.1 编译策略

编译为 Racket 的 `match` 宏：

```
明道代码:                   Racket 代码:
匹配 值:                    (match 值
  1 那么: "一"               [1 "一"]
  [a, b] 那么: 加 a, b      [(list a b) (+ a b)]
  _ 那么: 空值               [_ null]
  否则: "其他"               [else "其他"])
```

Racket 的 `match` 已支持所有需要的模式类型，因此 AST 生成直接映射。

### 5.2 涉及文件

| 文件 | 修改内容 |
|------|---------|
| `lang/tokenizer.rkt` | 在 `控制流关键字` 中添加 `"匹配"` |
| `lang/parser.rkt` | 新增 `parse-match` 函数，在 `parse-statement` 中注册 |
| `lang/error.rkt` | 可选：添加模式匹配专用错误提示 |

### 5.3 解析逻辑

```racket
(define (parse-match)
  (expect 'KEYWORD "匹配")
  (define value (parse-expression))
  (expect 'COLON)
  (skip-newlines)
  (expect 'INDENT)
  (define clauses '())
  (let loop ()
    (cond
      [(match? 'KEYWORD "否则")
       (advance)
       (expect 'COLON)
       (skip-newlines)
       (define else-body (parse-body))
       (set! clauses (append clauses (list (list 'else else-body))))]
      [else
       (define pattern (parse-pattern))
       (expect 'KEYWORD "那么")
       (expect 'COLON)
       (skip-newlines)
       (define body (parse-body))
       (set! clauses (append clauses (list (list pattern body))))
       (loop)]))
  (expect 'DEDENT)
  `(match ,value ,@clauses))
```

### 5.4 模式解析

```racket
(define (parse-pattern)
  (cond
    [(match? 'KEYWORD "任意")
     (advance)
     '_]
    [(match? 'KEYWORD "_")
     (advance)
     '_]
    [(match? 'IDENTIFIER)
     (define val (token-value (current)))
     (advance)
     (string->symbol val)]
    [(match? 'NUMBER)
     (define val (token-value (current)))
     (advance)
     (string->number val)]
    [(match? 'STRING)
     (define val (token-value (current)))
     (advance)
     val]
    [(match? 'LBRACKET)
     (advance)
     (define patterns (parse-pattern-list))
     (expect 'RBRACKET)
     `(list ,@patterns)]
    [else (error '匹配 "无效的模式: ~a" (current))]))
```

## 6. 测试计划

### 6.1 基本字面量匹配

```racket
;; 输入
匹配 1:
  1 那么: "一"
  _ 那么: "其他"

;; 预期 AST
'(match 1 [1 "一"] [_ "其他"])

;; 预期结果
"一"
```

### 6.2 列表解构

```racket
;; 输入
匹配 [1, 2, 3]:
  [a, b, c] 那么: 加 a, 加 b, c
  _ 那么: -1

;; 预期结果
6
```

### 6.3 守卫条件

```racket
;; 输入
定义 分类 就是函 [n]:
  匹配 n:
    x 如果 (> x 0) 那么: "正"
    x 如果 (< x 0) 那么: "负"
    _ 那么: "零"

;; 预期
(分类 5)  → "正"
(分类 -3) → "负"
(分类 0)  → "零"
```

### 6.4 多层嵌套

```racket
匹配 [[1, 2], 3]:
  [[a, b], c] 那么: 加 a, 加 b, c
  _ 那么: 0

;; 预期
6
```

### 6.5 没有否则分支（语法错误测试）

```racket
匹配 1:
  2 那么: "二"
;; → 解析错误：匹配必须有否则分支
```

## 7. 错误处理

| 错误情况 | 消息 |
|---------|------|
| 缺少 `匹配` | "解析错误：期望 '匹配'" |
| 缺少 `那么` | "匹配分支格式错误：缺少 '那么'" |
| 缺少缩进 | "匹配体需要缩进" |
| 缺少 `否则` | "匹配必须包含 '否则' 分支" |
| 无效模式 | "无效的模式: <类型>" |

## 8. 后续扩展（不在 v1 中）

- 记录/结构体模式：`{名称: 模式, ...}`
- `或` 模式：`模式1 或 模式2`
- 列表 rest 模式：`[head, ...tail]`
- 类型匹配：`是 类型 那么:`

## 9. 实现步骤

1. tokenizer.rkt：添加 `"匹配"` 关键字
2. parser.rkt：实现 `parse-match` 和 `parse-pattern`
3. 编写测试用例
4. 验证所有示例通过