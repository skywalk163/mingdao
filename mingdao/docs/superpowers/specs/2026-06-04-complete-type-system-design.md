# 明道语言类型系统完整实现 — 设计规格

## 概述

为明道语言实现完整的渐进类型系统，包含**泛型类型**、**联合类型**、**类型别名**和**运行时类型校验**。采用可选的渐进类型注解（Gradual Typing），在编译时进行类型检查，不强制标注、不阻断执行。

## 设计目标

1. **泛型类型**：`列表<整数>`、`字典<字符串, 整数>`、嵌套泛型
2. **联合类型**：`整数 | 字符串`、`整数 或 字符串`
3. **类型别名**：`定义类型 MyList 就是 列表<整数>`
4. **泛型函数**：`定义<T> fn, xs: 列表<T>: ...`
5. **运行时校验**：插入元素时检查类型一致性
6. **友好错误**：包含位置、上下文和修复建议的错误信息

## 类型表示

### 内部表示

类型从简单 symbol 扩展为结构化 S 表达式：

| 明道语法 | 内部表示 |
|---------|---------|
| `整数` | `'整数` |
| `浮点数` | `'浮点数` |
| `字符串` | `'字符串` |
| `列表<整数>` | `'(列表 整数)` |
| `字典<字符串, 整数>` | `'(字典 字符串 整数)` |
| `整数 | 字符串` | `'(或 整数 字符串)` |
| `列表<整数> | 字符串` | `'(或 (列表 整数) 字符串)` |
| `列表<列表<整数>>` | `'(列表 (列表 整数))` |
| `MyIntList` (别名) | 展开为 `'(列表 整数)` |

### 类型环境

```racket
;; 类型环境：变量名 → 类型
(define 类型环境 (make-hash))

;; 类型别名表：别名 → 实际类型
(define 类型别名表 (make-hash))
```

## 语法设计

### 变量定义

```明道
;; 带类型标注（可选）
定义 x: 整数 就是 42
定义 name: 字符串 就是 "你好"
定义 xs: 列表<整数> 就是 [1, 2, 3]
定义 d: 字典<字符串, 整数> 就是 [:]
定义 y: 整数 | 字符串 就是 42

;; 无标注 — 自动推断为 任意
定义 x 就是 42
```

### 类型别名

```明道
;; 定义类型别名
定义类型 MyIntList 就是 列表<整数>
定义类型 StringDict 就是 字典<字符串, 字符串>
定义类型 IntOrString 就是 整数 | 字符串

;; 使用别名
定义 nums: MyIntList 就是 [1, 2, 3]
定义 data: StringDict 就是 [:]
```

### 泛型函数

```明道
;; 泛型函数参数
定义 映射 就是函<T> fn, xs: 列表<T>:
    定义结果 就是 []
    对于 x 从 xs:
        定义结果 就是 前置 (fn, x) 定义结果
    返回 反转 定义结果

;; 使用
定义 加一 就是函 x: 整数: x 加 1
[1, 2, 3], 加一, 映射, 打印
```

### 函数返回类型

```明道
;; 带返回类型（冒号分隔：参数: 类型: 返回类型: 函数体）
定义 add 就是函 a: 整数, b: 整数: 整数:
  返回 a 加 b

;; 泛型返回类型
定义 first 就是函<T> xs: 列表<T>: T:
  返回 xs 索引 0
```

## 架构设计

### 编译流程

```
源代码
  ↓ 分词器 (tokenizer.rkt) — 新增 < > token
Token 序列
  ↓ 解析器 (parser.rkt) — 解析类型标注和别名
带类型的 AST + 类型别名表
  ↓ 类型检查器 (type-checker.rkt)
已验证的 AST + 警告信息
  ↓ 运行时校验（可选）
执行结果
```

### 模块职责

| 模块 | 职责 |
|------|------|
| `tokenizer.rkt` | 新增 `< >` token 类型，识别 `"或"` 关键字 |
| `parser.rkt` | `parse-type` 解析复杂类型，`parse-type-alias` 解析别名 |
| `type-checker.rkt` | 类型推断、兼容性检查、运行时校验、错误报告 |

## 实现详情

### 1. 分词器改动

#### 1.1 新增 token 类型

在 tokenizer 中添加：

```racket
;; 新增 token 类型常量
(define TOKEN-LEFT-ANGLE 'LEFT_ANGLE)
(define TOKEN-RIGHT-ANGLE 'RIGHT_ANGLE)

;; 在 ASCII 字符处理中添加
[(char=? ch #\<)
 (advance)
 (set! tokens (cons (token TOKEN-LEFT-ANGLE #\< line col) tokens))
 (main-loop)]

[(char=? ch #\>)
 (advance)
 (set! tokens (cons (token TOKEN-RIGHT-ANGLE #\> line col) tokens))
 (main-loop)]
```

#### 1.2 新增关键字

在控制流关键字列表中添加 `"或"`：

```racket
;; 控制流关键字
(define 控制流关键字 '("定义" "就是" "就是函" "如果" ... "或"))
```

### 2. 解析器改动

#### 2.1 parse-type 函数

```racket
;; 递归解析复杂类型表达式
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

#### 2.2 parse-type-alias 函数

```racket
;; 解析类型别名: 定义类型 MyList 就是 列表<整数>
(define (parse-type-alias)
  (expect-keyword "定义类型")
  (define alias-name (string->symbol (token-value (expect-identifier))))
  (expect-keyword "就是")
  (define actual-type (parse-type))
  ;; 存储到类型别名表
  (hash-set! 类型别名表 alias-name actual-type)
  (void))
```

#### 2.3 类型展开

```racket
;; 解析时展开别名
(define (展开类型 type-expr)
  (if (symbol? type-expr)
      (hash-ref 类型别名表 type-expr type-expr)
      type-expr))
```

### 3. 类型检查器改动

#### 3.1 类型推断

```racket
(define (infer-type expr env)
  (match expr
    [(? exact-integer?) '整数]
    [(? number?) '浮点数]
    [(? string?) '字符串]
    [(? boolean?) '布尔]
    [(? null?) '空值]
    [(? list?) '列表]
    [(? hash?) '字典]
    ;; 变量引用：查环境
    [(? symbol? s)
     (hash-ref env s '任意)]
    ;; 算术运算
    [`(,op ,a ,b)
     (match op
       [(or '加 '减 '乘 '除 '模 '幂)
        (let ([ta (infer-type a env)]
              [tb (infer-type b env)])
          (if (or (eq? ta '浮点数) (eq? tb '浮点数))
              '浮点数
              '整数))]
       [(or '大于 '小于 '大于等于 '小于等于 '等于 '不等)
        '布尔]
       ['非 '布尔]
       [(or '与 '或) '布尔]
       [_ '任意])]
    [_ '任意]))
```

#### 3.2 类型兼容性检查

```racket
(define (type-compatible? annotated actual)
  (or (eq? annotated '任意)
      (eq? actual '任意)
      (equal? annotated actual)
      (and (eq? annotated '浮点数) (eq? actual '整数))

      ;; 泛型 → 基类型：列表<整数> 兼容 列表
      (and (pair? annotated) (symbol? actual)
           (eq? (car annotated) actual))

      ;; 基类型 → 泛型：列表 兼容 列表<整数>
      (and (symbol? annotated) (pair? actual)
           (eq? annotated (car actual)))

      ;; 嵌套泛型：列表<列表<整数>> 兼容 列表<列表>
      (and (pair? annotated) (pair? actual)
           (eq? (car annotated) (car actual))
           (= (length (cdr annotated)) (length (cdr actual)))
           (for/and ([a (cdr annotated)] [d (cdr actual)])
             (type-compatible? a d)))

      ;; 联合类型包含检查：整数 兼容 整数|字符串
      (and (pair? annotated) (eq? (car annotated) '或)
           (member actual (cdr annotated)))

      ;; 联合子集检查：(或 整数) 兼容 (或 整数 字符串)
      (and (pair? annotated) (eq? (car annotated) '或)
           (pair? actual) (eq? (car actual) '或)
           (for/and ([a (cdr actual)])
             (member a (cdr annotated))))))
```

#### 3.3 运行时类型校验

```racket
;; 列表<整数> 运行时校验
(define (校验列表元素类型 lst element-type)
  (for ([elem lst])
    (unless (类型匹配? elem element-type)
      (报告类型错误 "运行时" elem element-type (获取类型 elem)))))

;; 字典<字符串, 整数> 运行时校验
(define (校验字典类型 dict key-type val-type)
  (hash-for-each dict
    (lambda (k v)
      (unless (类型匹配? k key-type)
        (报告类型错误 "运行时键" k key-type (获取类型 k)))
      (unless (类型匹配? v val-type)
        (报告类型错误 "运行时值" v val-type (获取类型 v))))))

;; 泛型约束校验
(define (校验泛型约束 param actual-param)
  (when (and (pair? param) (pair? actual-param))
    (for ([p (cdr param)] [a (cdr actual-param)])
      (校验泛型约束 p a))))
```

#### 3.4 错误报告器

```racket
(define (报告类型错误 位置 变量名 期望类型 实际类型)
  (define 建议
    (cond
      [(and (eq? 期望类型 '整数) (eq? 实际类型 '字符串))
       "💡 建议: 使用 转整数() 将字符串转换为整数"]
      [(and (eq? 期望类型 '浮点数) (not (数类型? 实际类型)))
       "💡 建议: 使用 转浮点数() 进行类型转换"]
      [(eq? 期望类型 '列表)
       "💡 建议: 使用 列表() 构造函数创建列表"]
      [(and (eq? 期望类型 '字符串) (数类型? 实际类型))
       "💡 建议: 使用 数字转字符串() 进行转换"]
      [(pair? 期望类型)
       (format "💡 建议: 确保值符合 ~a 类型约束" 期望类型)]
      [else "💡 建议: 检查类型标注是否正确"]))

  (displayln
    (format "[类型警告] 第~a行: 变量 '~a' 标注为 ~a，但实际得到 ~a\n~a"
            位置 变量名 期望类型 实际类型 建议)))
```

## 测试计划

### 测试覆盖矩阵

| # | 类别 | 测试场景 | 代码示例 |
|---|------|---------|---------|
| 1 | 基础 | 整数标注 | `定义 x: 整数 就是 42` |
| 2 | 基础 | 浮点数标注 | `定义 f: 浮点数 就是 3.14` |
| 3 | 基础 | 字符串标注 | `定义 s: 字符串 就是 "hello"` |
| 4 | 基础 | 布尔标注 | `定义 b: 布尔 就是 真值` |
| 5 | 基础 | 空值标注 | `定义 n: 空值 就是 空值` |
| 6 | 泛型 | 泛型列表 | `定义 xs: 列表<整数> 就是 [1, 2, 3]` |
| 7 | 泛型 | 泛型字典 | `定义 d: 字典<字符串, 整数> 就是 [:]` |
| 8 | 泛型 | 嵌套泛型 | `定义 m: 列表<列表<整数>> 就是 [[1]]` |
| 9 | 泛型 | 泛型→基类兼容 | `定义 xs: 列表 就是 [1, 2]` |
| 10 | 泛型 | 基类→泛型赋值 | `定义 xs: 列表<整数> 就是 []` |
| 11 | 联合 | 联合类型 PIPE | `定义 y: 整数 | 字符串 就是 42` |
| 12 | 联合 | 联合类型 或 | `定义 z: 整数 或 字符串 就是 "hi"` |
| 13 | 联合 | 联合成员赋值 | `定义 x: 整数 | 字符串 就是 "a"` |
| 14 | 联合 | 空值联合 | `定义 n: 整数 | 空值 就是 空值` |
| 15 | 联合 | 联合子集兼容 | `定义 x: 整数 就是 42` (隐式兼容 `整数|字符串`) |
| 16 | 别名 | 类型别名定义 | `定义类型 MyIntList 就是 列表<整数>` |
| 17 | 别名 | 使用别名 | `定义 xs: MyIntList 就是 [1]` |
| 18 | 别名 | 嵌套别名 | `定义类型 A 就是 B; 定义类型 B 就是 整数` |
| 19 | 别名 | 别名与泛型 | `定义类型 IntList 就是 列表<整数>` |
| 20 | 别名 | 别名循环检测 | 检测 `定义类型 A 就是 B; 定义类型 B 就是 A` |
| 21 | 函数 | 参数类型检查 | `定义 fn 就是函 x: 整数: x` |
| 22 | 函数 | 返回类型检查 | `定义 fn 就是函: 整数: 42` |
| 23 | 函数 | 泛型参数 | `定义 fn 就是函<T> xs: 列表<T>: xs` |
| 24 | 函数 | 泛型返回 | `定义 first 就是函<T> xs: 列表<T>: T: xs 索引 0` |
| 25 | 函数 | 参数返回类型 | `定义 add 就是函 a: 整数, b: 整数: 整数: a 加 b` |
| 26 | 运行时 | 列表元素校验 | `[1, "a"], 列表<整数>` → 类型警告 |
| 27 | 运行时 | 字典键值校验 | `["k": 1], 字典<整数, 字符串>` → 类型警告 |
| 28 | 运行时 | 嵌套泛型校验 | `[[1, "a"]], 列表<列表<整数>>` → 类型警告 |
| 29 | 错误 | 整数赋字符串 | `定义 x: 整数 就是 "s"` → 警告 + 建议 |
| 30 | 错误 | 浮点数赋列表 | `定义 f: 浮点数 就是 []` → 警告 + 建议 |
| 31 | 错误 | 联合类型不匹配 | `定义 x: 整数|字符串 就是 3.14` → 警告 |
| 32 | 错误 | 别名未定义 | `定义 x: UnknownType 就是 42` → 错误 |
| 33 | 边界 | 空列表泛型 | `定义 xs: 列表<整数> 就是 []` |
| 34 | 边界 | 深嵌套泛型 | `列表<列表<列表<列表<整数>>>>` |
| 35 | 边界 | 多重联合 | `整数|字符串|浮点数|布尔` |
| 36 | 组合 | 宏+泛型 | 宏展开结果类型检查 |
| 37 | 组合 | 生成器+类型 | `定义 gen 就是函<T> xs: 列表<T>: ...` |
| 38 | 组合 | 异步+类型 | `异步 返回 列表<整数>` |
| 39 | 组合 | OOP+泛型 | 类方法参数类型检查 |
| 40 | 组合 | 模式匹配+类型 | 匹配分支类型兼容性 |

## 实现任务清单

| # | 模块 | 任务 | 预估行数 | 优先级 |
|---|------|------|---------|--------|
| 1 | tokenizer | 添加 < > token | 20 | P0 |
| 2 | tokenizer | 添加 "或" 关键字 | 5 | P0 |
| 3 | parser | parse-type 函数 | 80 | P0 |
| 4 | parser | parse-type-alias 函数 | 50 | P1 |
| 5 | parser | 类型展开逻辑 | 20 | P0 |
| 6 | parser | 变量/函数类型解析集成 | 30 | P0 |
| 7 | type-checker | 类型兼容性检查增强 | 60 | P0 |
| 8 | type-checker | 运行时类型校验 | 80 | P1 |
| 9 | type-checker | 错误报告器（带建议） | 40 | P0 |
| 10 | type-checker | 别名循环检测 | 30 | P1 |
| 11 | tests | 基础类型测试 (1-5) | 30 | P0 |
| 12 | tests | 泛型测试 (6-10) | 30 | P0 |
| 13 | tests | 联合类型测试 (11-15) | 30 | P0 |
| 14 | tests | 类型别名测试 (16-20) | 30 | P0 |
| 15 | tests | 泛型函数测试 (21-25) | 30 | P0 |
| 16 | tests | 运行时校验测试 (26-28) | 30 | P1 |
| 17 | tests | 错误信息测试 (29-32) | 30 | P0 |
| 18 | tests | 边界测试 (33-35) | 30 | P1 |
| 19 | tests | 组合测试 (36-40) | 30 | P2 |
| **总计** | | | **655 行** | |

## 后续扩展方向

1. **型变（Variance）**：协变/逆变支持
2. **类型类（Type Classes）**：类似 Haskell 的类型约束
3. **依赖类型**：基于值的类型约束
4. **类型推断增强**：支持局部类型推断
5. **IDE 集成**：LSP 类型信息提供

## 验收标准

1. 所有 40 个测试用例通过
2. 错误信息包含行号、上下文和修复建议
3. 类型别名支持嵌套展开和循环检测
4. 泛型函数支持参数和返回类型
5. 运行时校验可开关（默认开启）
6. 不阻断程序执行（仅警告）

---

*文档版本: 1.0*
*创建日期: 2026-06-04*
*状态: 待实现*