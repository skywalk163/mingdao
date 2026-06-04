# 明道语言泛型和联合类型 — 设计规格

## 概述

在现有类型注解系统基础上，扩展支持**泛型类型**（`列表<整数>`）和**联合类型**（`整数 | 字符串`）。第一版为语法级检查——解析并识别类型签名，但不做元素运行时校验。

## 类型内部表示

类型从简单 symbol 扩展为结构化 S 表达式：

| 明道语法 | 内部表示 |
|---------|---------|
| `整数` | `'整数` |
| `列表<整数>` | `'(列表 整数)` |
| `字典<字符串, 整数>` | `'(字典 字符串 整数)` |
| `整数 | 字符串` | `'(或 整数 字符串)` |
| `列表<整数> | 字符串` | `'(或 (列表 整数) 字符串)` |
| `列表<列表<整数>>` | `'(列表 (列表 整数))` |

## 分词器改动

文件：`mingdao/lang/tokenizer.rkt`

### 新增 token 类型

| Token | ASCII | 说明 |
|-------|-------|------|
| `LEFT_ANGLE` | `<` | 泛型左尖括号 |
| `RIGHT_ANGLE` | `>` | 泛型右尖括号 |

在 ASCII 字符处理分支中添加：
```racket
[(char=? ch #\<)
 (advance)
 (set! tokens (cons (token 'LEFT_ANGLE #\< line col) tokens))
 (main-loop)]

[(char=? ch #\>)
 (advance)
 (set! tokens (cons (token 'RIGHT_ANGLE #\> line col) tokens))
 (main-loop)]
```

### 新增关键字

在控制流关键字列表中添加 `"或"`（用于联合类型语法 `整数 或 字符串`）：

```racket
;; 在 控制流关键字 或 关键字列表 中添加 "或"
```

## 解析器改动

文件：`mingdao/lang/parser.rkt`

### 新增 parse-type 函数

用于递归解析复杂类型表达式：

```racket
(define (parse-type)
  (define base-types '())
  (let parse-base ()
    (define type-name (string->symbol (token-value (expect-identifier))))
    ;; 检查泛型 <...>
    (define type-expr
      (if (match? 'LEFT_ANGLE)
          (begin
            (advance)  ;; 消费 <
            (define type-params '())
            (let loop ()
              (define param (parse-type))
              (set! type-params (cons param type-params))
              (when (match? 'COMMA)
                (advance)
                (loop)))
            (set! type-params (reverse type-params))
            (expect 'RIGHT_ANGLE)  ;; 消费 >
            `(,type-name ,@type-params))
          type-name))
    (set! base-types (cons type-expr base-types))
    ;; 检查联合类型 PIPE | 或
    (when (or (match? 'PIPE) (match? 'KEYWORD "或"))
      (advance)
      (parse-base)))
  (if (null? (cdr base-types))
      (car base-types)
      `(或 ,@(reverse base-types))))
```

### 变量定义中调用

将 `parse-definition` 中变量类型标注从：
```racket
(string->symbol (token-value (expect-identifier)))
```
改为：
```racket
(parse-type)
```

同时 `var-annotated-type` 的类型从 symbol 改为可接受 symbol 或 list。

### 函数返回类型中调用

将返回类型解析同样改为调用 `parse-type`。

### 类型名列表更新

在 `类型名列表` 中添加必要的类型名（已有 `列表` `字典` 等，无需额外添加）。

## 类型检查器更新

文件：`mingdao/lang/type-checker.rkt`

### type-compatible? 函数

```racket
(define (type-compatible? annotated actual)
  (or (eq? annotated '任意)              ;; 标注为任意 → 接受一切
      (eq? actual '任意)                 ;; 实际为任意 → 接受
      (equal? annotated actual)           ;; 完全相等
      (and (eq? annotated '浮点数) (eq? actual '整数))  ;; 整数→浮点数
      ;; 泛型 → 基类型：列表<整数> 兼容 列表
      (and (pair? annotated) (symbol? actual)
           (eq? (car annotated) actual))
      ;; 基类型 → 泛型：列表 兼容 列表<整数>
      (and (symbol? annotated) (pair? actual)
           (eq? annotated (car actual)))
      ;; 联合类型中包含：整数 兼容 整数|字符串
      (and (pair? annotated) (eq? (car annotated) '或)
           (member actual (cdr annotated)))
      ;; 实际值是联合，标注也是联合：检查子集关系
      (and (pair? annotated) (eq? (car annotated) '或)
           (pair? actual) (eq? (car actual) '或)
           (for/and ([a (cdr actual)])
             (member a (cdr annotated))))))
```

### infer-type 函数

保持基本不变。字面量推断仍返回简单类型 `'整数` `'字符串` 等。泛型和联合类型由标注引入，不由推断产生。

## 测试计划

以下测试追加到现有 `test-type-annotations.rkt`：

| # | 场景 | 代码 | 期望 |
|---|------|------|------|
| 11 | 泛型列表 | `定义 xs: 列表<整数> 就是 [1, 2, 3]; xs` | `'(1 2 3)` |
| 12 | 泛型字典 | `定义 d: 字典<字符串, 整数> 就是 [:]; d` | `#hash()` |
| 13 | 联合类型 PIPE | `定义 x: 整数 | 字符串 就是 42; x` | `42` |
| 14 | 联合类型 或 | `定义 s: 整数 或 字符串 就是 "hi"; s` | `"hi"` |
| 15 | 泛型→基类兼容 | `定义 xs: 列表 就是 [1, 2]; xs` | `'(1 2)` |
| 16 | 联合成员赋值 | `定义 x: 整数 | 字符串 就是 "a"; x` | `"a"` |
| 17 | 函数参数泛型 | `定义 fn 就是函 xs: 列表<整数>: xs; fn, [1]` | `'(1)` |
| 18 | 返回联合类型 | `定义 fn 就是函 n: 整数: 整数|字符串: n; fn, 5` | `5` |
| 19 | 空值联合 | `定义 x: 整数 | 空值 就是 空值; x` | `空值` |
| 20 | 嵌套泛型 | `定义 xs: 列表<列表<整数>> 就是 [[1]]; xs` | `'((1))` |

## 实现计划概要

1. **分词器**：添加 `<` `>` token，添加 `"或"` 关键字
2. **解析器**：实现 `parse-type` 函数，在变量和返回类型处调用
3. **类型检查器**：更新 `type-compatible?` 支持结构化类型
4. **测试**：追加 10 个新测试用例并验证

## 后续扩展方向

- 运行时类型校验（如 `列表<整数>` 插入数据时校验元素类型）
- 泛型函数（`定义 fn 就是函<T> xs: 列表<T>: ...`）
- 类型别名（`定义类型 整数列表 就是 列表<整数>`）
- 更丰富的联合类型推断