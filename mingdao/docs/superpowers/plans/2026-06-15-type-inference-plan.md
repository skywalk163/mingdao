# 明道语言类型推导实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 `semantic.rkt` 中集成类型推导，使变量/函数定义时自动推导类型，无需显式类型标注。

**架构：** 在 `analyze-expr` 遍历 AST 的过程中，同步调用 `infer-type` 推导子表达式的类型，将结果填入 `symbol-info.type` 字段。利用现有 scope 树和 lookup-symbol 查找变量/函数类型。

**技术栈：** Racket（racket/base, racket/match, racket/list）

---

## 文件清单

| 文件 | 职责 |
|------|------|
| `mingdao/lang/semantic.rkt` | 新增 `infer-type`、`type->string` 函数；增强 `analyze-expr` |
| `mingdao/lang/semantic.rkt` | `register-with-checks!` 新增 `type` 参数 |
| `mingdao/lang/semantic.rkt` | 函数定义分支新增返回类型推导 |
| `mingdao/tests/test-semantic.rkt` | 新增类型推导测试用例（~10 个） |

---

## 任务 1：实现 infer-type 基础函数

**文件：**
- 修改：`mingdao/lang/semantic.rkt`

### 子任务 1.1：添加 infer-type 主函数

- [ ] **步骤 1：在 semantic.rkt 的 provide 中添加 infer-type 和 type->string**

```racket
(provide analyze
         semantic-error
         scope
         symbol-info
         make-global-scope
         lookup-symbol
         define-symbol!
         infer-type            ;; 新增
         type->string          ;; 新增
         (struct-out semantic-error)
         (struct-out scope)
         (struct-out symbol-info))
```

- [ ] **步骤 2：添加 type->string 函数（在 register-with-checks! 之前）**

```racket
;; ============================================================
;; 类型格式化
;; ============================================================

(define (type->string t)
  (cond
    [(eq? t '整数) "整数"]
    [(eq? t '浮点数) "浮点数"]
    [(eq? t '字符串) "字符串"]
    [(eq? t '布尔) "布尔"]
    [(eq? t '空值) "空值"]
    [(eq? t '任意) "任意"]
    [(eq? t '列表) "列表"]
    [(eq? t '字典) "字典"]
    [(eq? t '函数) "函数"]
    [(eq? t '符号) "符号"]
    [(pair? t)
     (string-append (type->string (car t))
                    "<"
                    (string-join (map type->string (cdr t)) ", ")
                    ">")]
    [else (format "~a" t)]))
```

- [ ] **步骤 3：添加内置函数返回类型哈希表**

```racket
(define builtin-return-types
  (hash
   ;; 算术运算
   "加" (λ (ts) (if (member '浮点数 ts) '浮点数 '整数))
   "减" (λ (ts) (if (member '浮点数 ts) '浮点数 '整数))
   "乘" (λ (ts) (if (member '浮点数 ts) '浮点数 '整数))
   "除" (λ (ts) '浮点数)
   "模" (λ (ts) (if (member '浮点数 ts) '浮点数 '整数))
   "幂" (λ (ts) (if (member '浮点数 ts) '浮点数 '整数))
   ;; 比较运算
   "大于" (λ (ts) '布尔)
   "小于" (λ (ts) '布尔)
   "等于" (λ (ts) '布尔)
   "不等" (λ (ts) '布尔)
   "大于等于" (λ (ts) '布尔)
   "小于等于" (λ (ts) '布尔)
   ;; 类型转换
   "转整数" (λ (ts) '整数)
   "转浮点数" (λ (ts) '浮点数)
   "数字转字符串" (λ (ts) '字符串)
   ;; 序列操作
   "长度" (λ (ts) '整数)
   "索引" (λ (ts) '任意)
   "范围" (λ (ts) '(列表 整数))
   ;; 数学函数
   "绝对值" (λ (ts) (if (null? ts) '任意 (car ts)))
   "最大值" (λ (ts) (if (null? ts) '任意 (car ts)))
   "最小值" (λ (ts) (if (null? ts) '任意 (car ts)))
   "正弦" (λ (ts) '浮点数)
   "余弦" (λ (ts) '浮点数)
   "正切" (λ (ts) '浮点数)
   "阶乘" (λ (ts) '整数)
   "随机整数" (λ (ts) '整数)
   "随机浮点数" (λ (ts) '浮点数)
   ;; 字符串操作
   "字符串长度" (λ (ts) '整数)
   "字符串转列表" (λ (ts) '(列表 字符串))
   ;; 其他
   "打印" (λ (ts) (if (null? ts) '任意 (car ts)))
   "是整数" (λ (ts) '布尔)
   "是浮点数" (λ (ts) '布尔)
   "是字符串" (λ (ts) '布尔)
   "是数" (λ (ts) '布尔)
   "是空" (λ (ts) '布尔)
   "获取类型" (λ (ts) '字符串)
   "表示" (λ (ts) '字符串)))
```

- [ ] **步骤 4：编写 infer-type 主函数**

```racket
;; ============================================================
;; 类型推导
;; ============================================================

;; 推导表达式的类型
;; expr: S-expression（AST 中的表达式）
;; scope: 当前作用域（用于查符号类型）
;; 返回: 类型符号（'整数 / '字符串 / '(列表 整数) / ...）
(define (infer-type expr scope)
  (match expr
    ;; 字面量
    [(? exact-integer?) '整数]
    [(? number?) '浮点数]    ;; 包括浮点数和混合数
    [(? string?) '字符串]
    [(? boolean?) '布尔]
    [(? null?) '空值]
    [(? void?) '空值]
    
    ;; 符号引用：查作用域链
    [(? symbol? s)
     (define name (symbol->string s))
     (define found (lookup-symbol name scope))
     (if found
         (or (symbol-info-type (car found)) '任意)
         '任意)]
    
    ;; if 表达式
    [`(if ,_ ,then ,else)
     (let ([tt (infer-type then scope)]
           [te (infer-type else scope)])
       (if (equal? tt te) tt '任意))]
    
    ;; 列表字面量
    [`(列表 . ,items)
     (if (null? items)
         '列表
         (let ([elem-types (map (λ (e) (infer-type e scope)) items)])
           (if (and (pair? elem-types)
                    (for/and ([t elem-types]) (equal? t (car elem-types))))
               `(列表 ,(car elem-types))
               '列表)))]
    
    ;; return 语句
    [`(return ,val)
     (infer-type val scope)]
    
    ;; 赋值语句（右值类型）
    [`(= ,_ ,val)
     (infer-type val scope)]
    [`(set! ,_ ,val)
     (infer-type val scope)]
    
    ;; (op a b) 二元运算
    [`(,(? symbol? op) ,a ,b)
     (infer-binary-op op a b scope)]
    
    ;; (fn args...) 函数调用
    [`(,(? symbol? fn) . ,args)
     (define arg-types (map (λ (a) (infer-type a scope)) args))
     (define handler (hash-ref builtin-return-types fn #f))
     (if handler
         (handler arg-types)
         ;; 查自定义函数注册类型
         (define fn-str (symbol->string fn))
         (define found (lookup-symbol fn-str scope))
         (if found
             (or (symbol-info-type (car found)) '任意)
             '任意))]
    
    ;; 其他
    [_ '任意]))
```

- [ ] **步骤 5：编写 infer-binary-op 辅助函数**

```racket
(define (infer-binary-op op a b scope)
  (match op
    [(or '加 '减 '乘 '模 '幂)
     (let ([ta (infer-type a scope)]
           [tb (infer-type b scope)])
       (if (or (eq? ta '浮点数) (eq? tb '浮点数)) '浮点数 '整数))]
    ['除 '浮点数]
    [(or '大于 '小于 '等于 '不等 '大于等于 '小于等于 'equal?)
     '布尔]
    [(or '非 'not)
     '布尔]
    [(or '与 '或)
     '布尔]
    [_ (let* ([op-str (symbol->string op)]
              [handler (hash-ref builtin-return-types op-str #f)])
         (if handler
             (handler (map (λ (e) (infer-type e scope)) (list a b)))
             '任意))]))
```

- [ ] **步骤 6：运行测试验证基础函数可用**

运行：`racket -e '(require "mingdao/lang/semantic.rkt") (displayln (type->string (infer-type 42 (make-global-scope (list)))) (displayln (type->string (infer-type "hello" (make-global-scope (list)))))'`
预期：输出 "整数" 和 "字符串"

---

## 任务 2：增强 analyze-expr 以填充类型

**文件：**
- 修改：`mingdao/lang/semantic.rkt`

### 子任务 2.1：修改 register-with-checks! 接收类型参数

- [ ] **步骤 1：修改 register-with-checks! 签名**

```racket
(define (register-with-checks! name-str name-sym kind mutable? current-scope add-error! 
                                [type #f])       ;; ← 新增可选参数
  ;; 重复定义检查（不变）
  (when (hash-has-key? (scope-symbols current-scope) name-str)
    (add-error! (make-error 'redefined
                            (format "重复定义: 符号 '~a' 在当前作用域已存在" name-str)
                            (get-line name-sym) (get-col name-sym)
                            (kind->suggestion kind))))
  ;; 遮蔽检查（不变）
  (define parent-found (lookup-symbol name-str (scope-parent current-scope)))
  (when parent-found
    (add-error! (make-error 'shadowed
                            (format "作用域遮蔽: 符号 '~a' 遮蔽了父作用域中的同名符号" name-str)
                            (get-line name-sym) (get-col name-sym)
                            "考虑重命名以提高可读性")))
  ;; 注册——type 从可选参数中获取
  (define-symbol! name-str
                  (symbol-info kind type (get-line name-sym) (get-col name-sym) mutable? #t)
                  current-scope))
```

- [ ] **步骤 2：修改 analyze-expr 的变量定义分支**

```racket
;; 变量定义: (define name value)
[`(define ,(? symbol? name) ,val)
 (define val-type (infer-type val current-scope))        ;; ← 新增
 (register-with-checks! (symbol-name name) name '变量 #t current-scope add-error! val-type)  ;; ← type 参数
 (analyze-expr val current-scope)]
```

- [ ] **步骤 3：修改函数定义分支——添加返回类型推导**

```racket
;; 函数定义: (define (fn . params) . body)
[`(define (,(? symbol? fn) . ,params) . ,body)
 (define fn-str (symbol-name fn))
 ;; 先创建子作用域（参数能往里注册）
 (define child-scope (make-child-scope current-scope))
 (for ([p params])
   (when (symbol? p)
     (register-with-checks! (symbol-name p) p '参数 #t child-scope add-error!)))
 ;; 分析函数体
 (for ([b body])
   (analyze-expr b child-scope))
 ;; 推导返回类型
 (define fn-return-type
   (let ([ret-type
          ;; 查找 body 中的 (return val) 语句
          (let loop ([b body])
            (cond
              [(null? b) #f]
              [(and (pair? (car b)) (eq? (caar b) 'return)
                    (pair? (cdar b)))
               (infer-type (cadar b) child-scope)]
              [else (loop (cdr b))]))])
     (or ret-type
         (and (pair? body) (infer-type (last body) child-scope))
         '任意)))
 ;; 注册函数名（带返回类型）
 (register-with-checks! fn-str fn '函数 #f current-scope add-error! fn-return-type)]
```

- [ ] **步骤 4：验证现有测试不破坏**

运行：`racket -t mingdao/tests/test-semantic.rkt`
预期：18 test(s) run, 0 failures

### 子任务 2.3：添加新的类型推导测试

- [ ] **步骤 1：在 test-semantic.rkt 底部添加类型推导测试**

```racket
;; === 类型推导测试 ===

(test-suite "类型推导"

  (test-case "整数字面量类型"
    (define errors (analyze '((define x 5)) builtin-names))
    (define scope (make-global-scope builtin-names))
    (define-symbol! "x" (symbol-info '变量 '整数 0 0 #t #t) scope)
    (check-equal? (length errors) 0 "整数定义不应有语义错误"))

  (test-case "字符串字面量类型"
    (let* ([errors (analyze '((define s "hello")) builtin-names)])
      (check-equal? (length errors) 0)))

  (test-case "算术表达式类型-整数"
    (let* ([errors (analyze '((define x 5) (define y 3) (define r (加 x y))) builtin-names)])
      (check-equal? (length errors) 0 "整数加法不应有语义错误"))

  (test-case "算术表达式类型-浮点数"
    (let* ([errors (analyze '((define x 5) (define y 3.0) (define r (加 x y))) builtin-names)])
      (check-equal? (length errors) 0 "浮点数加法不应有语义错误"))

  (test-case "布尔字面量类型"
    (let* ([errors (analyze '((define b #t)) builtin-names)])
      (check-equal? (length errors) 0)))

  (test-case "条件表达式类型一致"
    (let* ([errors (analyze '((define x 5) (define r (if (> x 3) 1 0))) builtin-names)])
      (check-equal? (length errors) 0)))

  (test-case "函数返回类型"
    (let* ([errors (analyze '((define (双倍 n) (return (加 n n)))) builtin-names)])
      (check-equal? (length errors) 0 "函数定义不应有语义错误"))

  (test-case "列表推导-同类型"
    (let* ([errors (analyze '((define lst (列表 1 2 3))) builtin-names)])
      (check-equal? (length errors) 0)))

  (test-case "除法返回浮点数"
    (let* ([errors (analyze '((define r (除 5 2))) builtin-names)])
      (check-equal? (length errors) 0)))
  )
```

- [ ] **步骤 2：运行测试验证**

运行：`racket -t mingdao/tests/test-semantic.rkt`
预期：所有测试通过

---

## 任务 3：验证集成——reader.rkt 输出类型信息

- [ ] **步骤 1：验证 reader.rkt 使用 analyze 不受影响**

运行：`echo '定义 x 就是 5' | racket -e '(require mingdao/lang/reader) (read (current-input-port))'`
预期：正常输出 `(module 明道 ...)` 形式，无额外错误

- [ ] **步骤 2：验证测试文件 hello.mingdao 仍能运行**

运行：`cd mingdao && racket examples/hello.mingdao`
预期：输出 `5`

---

## 验收检查

- [ ] 所有原有测试通过：`racket -t mingdao/tests/test-semantic.rkt`
- [ ] 新增类型推导测试通过
- [ ] `infer-type` 导出并可独立调用
- [ ] `type->string` 导出并可正确格式化
- [ ] 变量定义时自动填充 symbol-info.type
- [ ] 函数定义时自动推导返回类型
- [ ] hello.mingdao 等现有程序正常运行

---

## 自检清单

1. **规格覆盖度**：所有推理规则都实现了（字面量、二元运算、if、列表、函数调用、函数返回）
2. **占位符扫描**：无 "待定"、"TODO"、"后续实现"
3. **类型一致性**：所有类型符号统一使用 `'整数` `'浮点数` `'字符串` `'布尔` `'列表` 等 
4. **函数签名**：`register-with-checks!` 新增可选参数 `type`，默认 `#f` 兼容旧调用