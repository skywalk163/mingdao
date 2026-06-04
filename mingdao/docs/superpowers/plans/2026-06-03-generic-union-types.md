# 泛型和联合类型 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为明道语言的类型注解系统添加泛型（`列表<整数>`）和联合类型（`整数 | 字符串` / `整数 或 字符串`）支持。

**架构：** 分词器新增 `<` `>` token 和 `"或"` 关键字；解析器新增递归 `parse-type` 函数处理复合类型；类型检查器更新 `type-compatible?` 处理结构化 S 表达式类型表示。

**技术栈：** Racket/base, racket/match, 现有 tokenizer/parser/type-checker

---

### 任务 1：分词器 — 添加 `<` `>` 和 `"或"` 关键字

**文件：**
- 修改：`mingdao\lang\tokenizer.rkt`

- [ ] **步骤 1：在 tokenizer 中添加 LEFT_ANGLE 和 RIGHT_ANGLE 处理**

在 ASCII 字符处理分支中（约第 495 行 PIPE 处理之后），添加：

```racket
;; 泛型尖括号 < >
[(char=? ch #\<)
 (advance)
 (set! tokens (cons (token 'LEFT_ANGLE #\< line col) tokens))
 (main-loop)]

[(char=? ch #\>)
 (advance)
 (set! tokens (cons (token 'RIGHT_ANGLE #\> line col) tokens))
 (main-loop)]
```

- [ ] **步骤 2：在关键字列表中添加 `"或"`**

在 `控制流关键字` 列表或专门的关键字列表中添加 `"或"`，使其能被 tokenizer 识别为 KEYWORD 而非普通标识符：

找到 `控制流关键字` 的定义（约第 55-60 行），添加 `"或"`：

```racket
(define 控制流关键字
  '("定义" "如果" "那么" "否则" "对于" "跳出" "继续" "返回"
    "导入" "导出" "模块" "赋值" "尝试" "捕获" "匹配" "始终"
    "或"   ;; 联合类型关键字
    ))
```

- [ ] **步骤 3：验证 tokenizer 可加载**

运行：
```
& "E:\Program Files\Racket\racket.exe" -e "(require \"../lang/tokenizer.rkt\")" -e "(displayln \"OK\")"
```
在目录 `g:\dumategithub\langbyracket\mingdao\tests` 执行。
预期：输出 OK

- [ ] **步骤 4：验证 < > 被正确分词**

运行：
```
& "E:\Program Files\Racket\racket.exe" -e "(require \"../lang/tokenizer.rkt\")" -e "(pretty-print (tokenize \"定义 x: 列表<整数> 就是 [1]\"))"
```
在目录 `g:\dumategithub\langbyracket\mingdao\tests` 执行。
预期：输出中包含 `LEFT_ANGLE` 和 `RIGHT_ANGLE` token

- [ ] **步骤 5：Commit**

```bash
git add mingdao/lang/tokenizer.rkt
git commit -m "feat: add angle bracket tokens and \"或\" keyword for types"
```

### 任务 2：解析器 — 实现 parse-type 函数

**文件：**
- 修改：`mingdao\lang\parser.rkt`

- [ ] **步骤 1：实现 parse-type 递归类型解析函数**

在 `parse-definition` 函数之前或附近添加：

```racket
;; 解析类型表达式（泛型、联合）
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

- [ ] **步骤 2：在变量定义中调用 parse-type**

在 `parse-definition` 中找到变量类型标注处（约第 659-664 行），将原来的：

```racket
(define var-annotated-type
  (if (match? 'COLON)
      (begin
        (advance)              ;; 消费 :
        (string->symbol (token-value (expect-identifier))))  ;; 读取并保存类型名
      #f))
```

改为：

```racket
;; 检查类型标注（支持泛型和联合类型）
(define var-annotated-type
  (if (match? 'COLON)
      (begin
        (advance)              ;; 消费 :
        (parse-type))          ;; 解析复合类型表达式
      #f))
```

- [ ] **步骤 3：在函数返回类型中调用 parse-type**

在 "就是函" 分支中找到返回类型解析处（约第 677-686 行），将原来的：

```racket
(define return-type
  (let ([next-tok (current)])
    (if (and next-tok
             (eq? (token-type next-tok) 'IDENTIFIER)
             (是类型名? (token-value next-tok)))
        (begin
          (let ([tname (token-value (advance))])
            (expect 'COLON)
            (string->symbol tname)))
        '任意)))
```

改为：

```racket
(define return-type
  (let ([next-tok (current)])
    (if (and next-tok
             (or (eq? (token-type next-tok) 'IDENTIFIER)
                 (eq? (token-type next-tok) 'LEFT_ANGLE)
                 (and (eq? (token-type next-tok) 'KEYWORD)
                      (member (token-value next-tok) '("或"))))
             (or (是类型名? (token-value next-tok))
                 (eq? (token-type next-tok) 'LEFT_ANGLE)
                 (and (eq? (token-type next-tok) 'KEYWORD)
                      (equal? (token-value next-tok) "或"))))
        (begin
          (define return-type-val (parse-type))
          (expect 'COLON)
          return-type-val)
        '任意)))
```

注意：这里需要放宽检测条件，因为复合类型可能以 `<` 或 `或` 开头。一个更简单的方案：直接尝试 `peek` 看是否能调用 `parse-type`，但为稳妥，改为检查 token 类型后调用。

**简化方案：** 由于返回类型总是跟在参数列表后的 `:` 之后，且 `:` 后要么是类型表达式要么是换行缩进（体开始），可以直接用 `(peek 1)` 预读：

```racket
(define return-type
  (let ([next-tok (current)]
        [next-next (peek 1)])
    (if (and next-tok next-next
             (eq? (token-type next-tok) 'IDENTIFIER)
             (or (是类型名? (token-value next-tok))
                 (and (eq? (token-type next-next) 'LEFT_ANGLE)  ;; 泛型 <
                      (是类型名? (token-value next-tok)))
                 (and (eq? (token-type next-next) 'PIPE)  ;; 联合类型 |
                      (是类型名? (token-value next-tok)))
                 (and (eq? (token-type next-next) 'KEYWORD)  ;; 联合类型 或
                      (equal? (token-value next-next) "或")
                      (是类型名? (token-value next-tok)))))
        (begin
          (define return-type-val (parse-type))
          (expect 'COLON)
          return-type-val)
        '任意)))
```

- [ ] **步骤 4：运行现有测试确认未破坏功能**

运行：
```
& "E:\Program Files\Racket\racket.exe" test-try-catch-finally.rkt
```
预期：全部 10 个通过

运行：
```
& "E:\Program Files\Racket\racket.exe" test-type-annotations.rkt
```
预期：全部 10 个通过

- [ ] **步骤 5：Commit**

```bash
git add mingdao/lang/parser.rkt
git commit -m "feat: implement parse-type for generic and union types"
```

### 任务 3：类型检查器 — 更新 type-compatible?

**文件：**
- 修改：`mingdao\lang\type-checker.rkt`

- [ ] **步骤 1：更新 type-compatible? 函数支持结构化类型**

将原 `type-compatible?` 替换为：

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
      ;; 联合类型包含检查：整数 兼容 整数|字符串
      (and (pair? annotated) (eq? (car annotated) '或)
           (member actual (cdr annotated)))
      ;; 联合子集检查：(或 整数) 兼容 (或 整数 字符串)
      (and (pair? annotated) (eq? (car annotated) '或)
           (pair? actual) (eq? (car actual) '或)
           (for/and ([a (cdr actual)])
             (member a (cdr annotated))))))
```

- [ ] **步骤 2：验证加载正常**

运行：
```
& "E:\Program Files\Racket\racket.exe" -e "(require \"../lang/type-checker.rkt\")" -e "(displayln \"OK\")"
```
预期：输出 OK

- [ ] **步骤 3：运行现有类型注解测试**

```
& "E:\Program Files\Racket\racket.exe" test-type-annotations.rkt
```
预期：全部 10 个通过（类型检查器改变不影响现有测试）

- [ ] **步骤 4：Commit**

```bash
git add mingdao/lang/type-checker.rkt
git commit -m "feat: update type-compatible? for generic and union types"
```

### 任务 4：测试 — 追加泛型和联合类型测试

**文件：**
- 修改：`mingdao\tests\test-type-annotations.rkt`

- [ ] **步骤 1：追加测试 11-20**

在 test-type-annotations.rkt 末尾、汇总之前添加：

```racket
;; ========== 测试11：泛型列表 ==========
(run-test "泛型列表"
"定义 xs: 列表<整数> 就是 [1, 2, 3]
xs"
  '(1 2 3))

;; ========== 测试12：泛型字典 ==========
(run-test "泛型字典"
"定义 d: 字典<字符串, 整数> 就是 [:]
d"
  (make-hash))

;; ========== 测试13：联合类型 PIPE ==========
(run-test "联合类型 PIPE"
"定义 x: 整数 | 字符串 就是 42
x"
  42)

;; ========== 测试14：联合类型 或 ==========
(run-test "联合类型 或"
"定义 s: 整数 或 字符串 就是 \"hi\"
s"
  "hi")

;; ========== 测试15：泛型→基类兼容 ==========
(run-test "泛型→基类兼容"
"定义 xs: 列表 就是 [1, 2]
xs"
  '(1 2))

;; ========== 测试16：联合成员赋值 ==========
(run-test "联合成员赋值"
"定义 x: 整数 | 字符串 就是 \"a\"
x"
  "a")

;; ========== 测试17：函数参数泛型 ==========
(run-test "函数参数泛型"
"定义 fn 就是函 xs: 列表<整数>:
  xs
fn, [1]"
  '(1))

;; ========== 测试18：返回联合类型 ==========
(run-test "返回联合类型"
"定义 fn 就是函 n: 整数: 整数|字符串:
  返回 n
fn, 5"
  5)

;; ========== 测试19：空值联合 ==========
(run-test "空值联合"
"定义 x: 整数 | 空值 就是 空值
x"
  null)

;; ========== 测试20：嵌套泛型 ==========
(run-test "嵌套泛型"
"定义 xs: 列表<列表<整数>> 就是 [[1]]
xs"
  '((1)))
```

- [ ] **步骤 2：运行测试**

```
& "E:\Program Files\Racket\racket.exe" test-type-annotations.rkt
```
预期：全部 20 个测试通过

如果测试失败，分析失败原因并修复。常见问题：
- 返回类型检测条件太严格，导致 `parse-type` 未被调用
- `parse-type` 中的 `expect-identifier` 在遇到非标识符 token 时报错
- tokenizer 中 `"或"` 未正确标记为 KEYWORD

- [ ] **步骤 3：运行其他测试确认未破坏**

```
& "E:\Program Files\Racket\racket.exe" test-try-catch-finally.rkt
```
预期：全部 10 个通过

- [ ] **步骤 4：Commit**

```bash
git add mingdao/tests/test-type-annotations.rkt
git commit -m "test: add generic and union type tests"
```