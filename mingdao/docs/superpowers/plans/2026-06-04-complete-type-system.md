# 明道语言类型系统完整实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为明道语言实现完整的渐进类型系统，包含泛型类型、联合类型、类型别名、运行时校验和友好错误报告。

**架构：**
- 分词器添加 `< >` token 支持
- 解析器新增 `parse-type` 和 `parse-type-alias` 函数
- 类型检查器增强类型兼容性、运行时校验和错误报告

**技术栈：** Racket（核心语言）、测试框架（基于现有 `test-type-annotations.rkt` 扩展）

---

## 文件清单

| 文件路径 | 操作 | 职责 |
|---------|------|------|
| `mingdao/lang/tokenizer.rkt` | 修改 | 添加 `< >` token 类型和 `"或"` 关键字 |
| `mingdao/lang/parser.rkt` | 修改 | 添加 `parse-type`、`parse-type-alias`，集成类型解析 |
| `mingdao/lang/type-checker.rkt` | 修改 | 增强类型兼容性、运行时校验、错误报告 |
| `mingdao/tests/test-type-annotations.rkt` | 扩展 | 新增测试用例 |
| `mingdao/tests/test-type-aliases.rkt` | 新建 | 类型别名专用测试 |
| `mingdao/tests/test-runtime-checks.rkt` | 新建 | 运行时类型校验测试 |

---

## 任务 1：分词器添加 `< >` Token 支持

**文件：**
- 修改：`mingdao/lang/tokenizer.rkt`

**步骤：**

1. 在 `tokenizer.rkt` 文件开头添加新的 token 常量：
```racket
(define TOKEN-LEFT-ANGLE 'LEFT_ANGLE)
(define TOKEN-RIGHT-ANGLE 'RIGHT_ANGLE)
```

2. 在 `main-loop` 函数的 ASCII 字符处理部分添加：
```racket
[(char=? ch #\<)
 (advance)
 (set! tokens (cons (token TOKEN-LEFT-ANGLE #\< line col) tokens))
 (main-loop)]

[(char=? ch #\>)
 (advance)
 (set! tokens (cons (token TOKEN-RIGHT-ANGLE #\> line col) tokens))
 (main-loop)]
```

3. 在 `控制流关键字` 列表中添加 `"或"`

4. 运行测试验证：`racket mingdao/tests/test-type-annotations.rkt`

---

## 任务 2：解析器实现 parse-type 函数

**文件：**
- 修改：`mingdao/lang/parser.rkt`

**步骤：**

1. 添加类型别名表：
```racket
(define *类型别名表* (make-hash))
```

2. 实现 `parse-type` 函数：
```racket
(define (parse-type)
  (define base-types '())
  (let parse-base ()
    (define type-name (string->symbol (token-value (expect-identifier))))
    (define type-expr
      (if (match? 'LEFT_ANGLE)
          (begin
            (advance)
            (define type-params '())
            (let loop ()
              (define param (parse-type))
              (set! type-params (cons param type-params))
              (when (match? 'COMMA)
                (advance)
                (loop)))
            (set! type-params (reverse type-params))
            (expect 'RIGHT_ANGLE)
            `(,type-name ,@type-params))
          type-name))
    (set! base-types (cons type-expr base-types))
    (when (or (match? 'PIPE) (match? 'KEYWORD "或"))
      (advance)
      (parse-base)))
  (if (null? (cdr base-types))
      (car base-types)
      `(或 ,@(reverse base-types))))
```

3. 修改 `parse-definition` 使用 `parse-type` 解析变量类型

4. 修改函数参数和返回类型解析使用 `parse-type`

---

## 任务 3：解析器实现类型别名解析

**文件：**
- 修改：`mingdao/lang/parser.rkt`
- 新建：`mingdao/tests/test-type-aliases.rkt`

**步骤：**

1. 实现 `parse-type-alias` 函数：
```racket
(define (parse-type-alias)
  (expect-keyword "定义类型")
  (define alias-name (string->symbol (token-value (expect-identifier))))
  (expect-keyword "就是")
  (define actual-type (parse-type))
  (when (hash-has-key? *类型别名表* alias-name)
    (error '解析错误 (format "类型别名 '~a' 重复定义" alias-name)))
  (hash-set! *类型别名表* alias-name actual-type)
  (void))
```

2. 实现 `展开类型` 函数：
```racket
(define (展开类型 type-expr)
  (if (symbol? type-expr)
      (let ([展开的 (hash-ref *类型别名表* type-expr #f)])
        (if 展开的
            (展开类型 展开的)
            type-expr))
      type-expr))
```

3. 修改 `parse-top-level` 识别 `"定义类型"`

4. 创建测试文件 `test-type-aliases.rkt`

---

## 任务 4：增强类型检查器兼容性检查

**文件：**
- 修改：`mingdao/lang/type-checker.rkt`

**步骤：**

1. 增强 `type-compatible?` 函数支持：
   - 泛型类型兼容性
   - 嵌套泛型兼容性
   - 联合类型兼容性

2. 添加测试用例验证泛型和联合类型

---

## 任务 5：实现运行时类型校验

**文件：**
- 修改：`mingdao/lang/type-checker.rkt`
- 新建：`mingdao/tests/test-runtime-checks.rkt`

**步骤：**

1. 添加 `获取类型` 函数
2. 添加 `类型匹配?` 函数
3. 添加 `校验列表元素类型` 函数
4. 添加 `校验字典类型` 函数

---

## 任务 6：实现友好错误报告

**文件：**
- 修改：`mingdao/lang/type-checker.rkt`

**步骤：**

1. 实现 `报告类型错误` 函数，包含：
   - 位置信息（行号）
   - 变量名和类型信息
   - 修复建议

2. 在 `check-types` 中集成错误报告

---

## 验收标准

- [ ] 所有测试用例通过
- [ ] 错误信息包含行号、上下文和修复建议
- [ ] 类型别名支持嵌套展开
- [ ] 泛型列表/字典语法正确解析
- [ ] 联合类型（`|` 和 `或` 关键字）都支持
- [ ] 运行时类型校验逻辑实现