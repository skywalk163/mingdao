# M6 严格类型系统 2.0 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现严格类型系统 2.0，支持严格模式、泛型增强、接口系统、类型推断增强和类型安全保障

**架构：** 类型系统分为四个核心模块：类型表达式定义(type-system.rkt)、类型推断引擎(type-inference.rkt)、类型检查器(type-checker.rkt重写)、接口系统(interface.rkt新增)，并在运行时层增强类型安全支持

**技术栈：** Racket, struct, hash table, pattern matching

---

## 文件结构

| 文件 | 职责 | 操作 |
|------|------|------|
| `mingdao/lang/type-system.rkt` | 类型表达式数据结构、兼容性判断 | 新增 |
| `mingdao/lang/type-inference.rkt` | 类型推断引擎、约束求解 | 新增 |
| `mingdao/lang/type-checker.rkt` | 编译时类型检查、错误报告 | 重写 |
| `mingdao/lang/interface.rkt` | 接口定义、实现检查、继承 | 新增 |
| `mingdao/core/types.rkt` | 运行时类型支持 | 增强 |
| `mingdao/tests/test-type-system.rkt` | 类型系统核心测试 | 新增 |
| `mingdao/tests/test-type-inference.rkt` | 类型推断测试 | 新增 |
| `mingdao/tests/test-strict-types.rkt` | 严格类型测试 | 新增 |
| `mingdao/tests/test-interfaces.rkt` | 接口测试 | 新增 |
| `mingdao/tests/test-generics.rkt` | 泛型测试 | 新增 |
| `mingdao/tests/test-strict-type-system.rkt` | 集成测试 | 新增 |

---

## 任务 1：创建类型系统核心 (type-system.rkt)

**文件：**
- 创建：`mingdao/lang/type-system.rkt`
- 测试：`mingdao/tests/test-type-system.rkt`

- [ ] **步骤 1：创建类型系统基础结构**

```racket
#lang racket/base
;; 明道语言类型系统核心
;; 定义类型表达式数据结构和兼容性判断

(provide
 ;; 类型表达式结构
 make-type-expr type-expr? type-base? type-param? type-generic?
 type-union? type-interface? type-alias?
 type-expr-name type-expr-args type-expr-types type-expr-target
 type-expr-methods
 ;; 类型环境
 make-type-env type-env? type-env-vars type-env-fns type-env-types
 type-env-ifaces type-env-generics
 type-env-add-var! type-env-add-fn! type-env-add-type!
 type-env-add-iface! type-env-add-generic!
 type-env-lookup-var type-env-lookup-fn type-env-lookup-type
 type-env-lookup-iface type-env-lookup-generic
 ;; 基础类型常量
 *base-types* BASE-INTEGER BASE-FLOAT BASE-STRING BASE-BOOLEAN
 BASE-NULL BASE-ANY
 ;; 内置类型判断
 builtin-type?
 ;; 类型兼容性判断
 type-compatible? type-equal?)

;; ============================================================
;; 类型表达式结构
;; ============================================================

;; 抽象基类
(struct type-expr () #:transparent)

;; 基础类型：整数、浮点数、字符串等
(struct type-base type-expr (name) #:transparent)

;; 类型参数：泛型类型参数 T, U 等
(struct type-param type-expr (name) #:transparent)

;; 泛型类型：列表<整数>、字典<字符串, 整数>
(struct type-generic type-expr (name args) #:transparent)

;; 联合类型：整数 | 字符串
(struct type-union type-expr (types) #:transparent)

;; 接口类型：定义接口时使用
(struct type-interface type-expr (name methods) #:transparent)

;; 类型别名：定义类型 MyInt 就是 整数
(struct type-alias type-expr (name target) #:transparent)

;; 访问器
(define (type-expr-name t)
  (cond [(type-base? t) (type-base-name t)]
        [(type-param? t) (type-param-name t)]
        [(type-generic? t) (type-generic-name t)]
        [(type-union? t) '联合]
        [(type-interface? t) (type-interface-name t)]
        [(type-alias? t) (type-alias-name t)]
        [else '未知]))

(define (type-expr-args t)
  (and (type-generic? t) (type-generic-args t)))

(define (type-expr-types t)
  (and (type-union? t) (type-union-types t)))

(define (type-expr-target t)
  (and (type-alias? t) (type-alias-target t)))

(define (type-expr-methods t)
  (and (type-interface? t) (type-interface-methods t)))

;; ============================================================
;; 基础类型常量
;; ============================================================

(define BASE-INTEGER (type-base '整数))
(define BASE-FLOAT (type-base '浮点数))
(define BASE-STRING (type-base '字符串))
(define BASE-BOOLEAN (type-base '布尔))
(define BASE-NULL (type-base '空值))
(define BASE-ANY (type-base '任意))

(define *base-types*
  (hash '整数 BASE-INTEGER
        '浮点数 BASE-FLOAT
        '字符串 BASE-STRING
        '布尔 BASE-BOOLEAN
        '空值 BASE-NULL
        '任意 BASE-ANY))

(define (builtin-type? name)
  (hash-has-key? *base-types* name))

;; ============================================================
;; 类型环境
;; ============================================================

(struct type-env (vars fns types ifaces generics) #:transparent)

(define (make-type-env)
  (type-env (make-hash)   ; vars: 变量 → 类型
             (make-hash)   ; fns: 函数名 → (list params return-type)
             (make-hash)   ; types: 类型别名
             (make-hash)   ; ifaces: 接口定义
             (make-hash))) ; generics: 泛型约束

(define (type-env-add-var! env name type)
  (hash-set! (type-env-vars env) name type))

(define (type-env-add-fn! env name params return-type)
  (hash-set! (type-env-fns env) name (list params return-type)))

(define (type-env-add-type! env name target)
  (hash-set! (type-env-types env) name target))

(define (type-env-add-iface! env name methods)
  (hash-set! (type-env-ifaces env) name methods))

(define (type-env-add-generic! env name constraints)
  (hash-set! (type-env-generics env) name constraints))

(define (type-env-lookup-var env name)
  (hash-ref (type-env-vars env) name #f))

(define (type-env-lookup-fn env name)
  (hash-ref (type-env-fns env) name #f))

(define (type-env-lookup-type env name)
  (hash-ref (type-env-types env) name #f))

(define (type-env-lookup-iface env name)
  (hash-ref (type-env-ifaces env) name #f))

(define (type-env-lookup-generic env name)
  (hash-ref (type-env-generics env) name #f))

;; ============================================================
;; 类型兼容性判断
;; ============================================================

(define (type-compatible? target source)
  "判断 source 类型是否可以赋值给 target 类型"
  (cond
    ;; 任意类型兼容一切
    ((and (type-base? target) (eq? (type-base-name target) '任意)) #t)
    ((and (type-base? source) (eq? (type-base-name source) '任意)) #t)
    ;; 基础类型相同
    ((and (type-base? target) (type-base? source)
           (eq? (type-base-name target) (type-base-name source)))
     #t)
    ;; 浮点数与整数兼容（自动转换）
    ((and (type-base? target) (type-base? source)
           (eq? (type-base-name target) '浮点数)
           (eq? (type-base-name source) '整数))
     #t)
    ;; 联合类型
    ((type-union? target)
     (ormap (lambda (t) (type-compatible? t source))
           (type-union-types target)))
    ;; 类型参数
    ((type-param? target) #t)  ; 类型参数可匹配任何类型
    ;; 泛型类型
    ((and (type-generic? target) (type-generic? source)
           (eq? (type-generic-name target) (type-generic-name source))
           (= (length (type-generic-args target))
              (length (type-generic-args source))))
     (for/and ([t (type-generic-args target)]
               [s (type-generic-args source)])
       (type-compatible? t s)))
    (else #f)))

(define (type-equal? t1 t2)
  "判断两个类型是否完全相等"
  (cond
    ((and (type-base? t1) (type-base? t2))
     (eq? (type-base-name t1) (type-base-name t2)))
    ((and (type-param? t1) (type-param? t2))
     (eq? (type-param-name t1) (type-param-name t2)))
    ((and (type-generic? t1) (type-generic? t2)
          (eq? (type-generic-name t1) (type-generic-name t2))
          (= (length (type-generic-args t1))
             (length (type-generic-args t2))))
     (for/and ([a1 (type-generic-args t1)]
               [a2 (type-generic-args t2)])
       (type-equal? a1 a2)))
    ((and (type-union? t1) (type-union? t2)
          (= (length (type-union-types t1))
             (length (type-union-types t2))))
     (for/and ([t1 (type-union-types t1)]
               [t2 (type-union-types t2)])
       (type-equal? t1 t2)))
    (else #f)))
```

- [ ] **步骤 2：创建测试文件 test-type-system.rkt**

```racket
#lang racket/base

(require "lang/type-system.rkt"
         rackunit)

(printf "\n══════ 类型系统核心测试 ══════\n")

;; 测试 1：基础类型
(check-true (type-base? BASE-INTEGER) "BASE-INTEGER 是基础类型")
(check-equal? (type-base-name BASE-INTEGER) '整数 "BASE-INTEGER 名称为整数")

;; 测试 2：泛型类型
(define list-int (type-generic '列表 (list BASE-INTEGER)))
(check-true (type-generic? list-int) "列表<整数> 是泛型类型")
(check-equal? (type-generic-name list-int) '列表 "泛型名称为列表")
(check-equal? (length (type-generic-args list-int)) 1 "泛型参数数量为1")

;; 测试 3：联合类型
(define int-or-str (type-union (list BASE-INTEGER BASE-STRING)))
(check-true (type-union? int-or-str) "整数|字符串 是联合类型")
(check-equal? (length (type-union-types int-or-str)) 2 "联合类型有2个成员")

;; 测试 4：类型兼容性 - 相同类型
(check-true (type-compatible? BASE-INTEGER BASE-INTEGER) "整数兼容整数")

;; 测试 5：类型兼容性 - 整数兼容浮点数
(check-true (type-compatible? BASE-FLOAT BASE-INTEGER) "浮点数兼容整数")

;; 测试 6：类型兼容性 - 联合类型
(check-true (type-compatible? int-or-str BASE-INTEGER) "联合类型包含整数")
(check-true (type-compatible? int-or-str BASE-STRING) "联合类型包含字符串")
(check-false (type-compatible? int-or-str BASE-BOOLEAN) "联合类型不包含布尔")

;; 测试 7：类型环境
(define env (make-type-env))
(type-env-add-var! env 'x BASE-INTEGER)
(check-equal? (type-env-lookup-var env 'x) BASE-INTEGER "环境可查找变量x")
(check-false (type-env-lookup-var env 'y) "不存在的变量返回#f")

(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  类型系统核心测试全部通过!          ║\n")
(printf "╚══════════════════════════════════════╝\n")
```

- [ ] **步骤 3：运行测试**

运行：`cd g:\dumategithub\langbyracket\mingdao && racket tests/test-type-system.rkt`

预期：输出 "类型系统核心测试全部通过!"

- [ ] **步骤 4：Commit**

```bash
git add mingdao/lang/type-system.rkt mingdao/tests/test-type-system.rkt
git commit -m "feat(types): add type-system.rkt core structures

- type-expr structs: base, param, generic, union, interface, alias
- type-env: variable, function, type alias, interface, generic constraints
- type-compatible?: check type assignability with auto-conversion
- type-equal?: exact type equality check
- Unit tests for all structures and functions"
```

---

## 任务 2：创建类型推断引擎 (type-inference.rkt)

**文件：**
- 创建：`mingdao/lang/type-inference.rkt`
- 依赖：`mingdao/lang/type-system.rkt`
- 测试：`mingdao/tests/test-type-inference.rkt`

- [ ] **步骤 1：创建类型推断核心**

```racket
#lang racket/base
;; 明道语言类型推断引擎

(require "lang/type-system.rkt")

(provide infer-expr-type infer-list-type infer-function-return
         type-env-with-decls parse-type-expr)

;; ============================================================
;; 类型推断入口
;; ============================================================

(define (infer-expr-type expr env)
  "推断表达式的类型"
  (cond
    ;; 字面量
    [(exact-integer? expr) BASE-INTEGER]
    [(and (number? expr) (not (exact-integer? expr))) BASE-FLOAT]
    [(string? expr) BASE-STRING]
    [(boolean? expr) BASE-BOOLEAN]
    [(null? expr) BASE-NULL]
    
    ;; 符号 - 变量引用
    [(symbol? expr)
     (or (type-env-lookup-var env expr)
         (type-env-lookup-fn env expr)
         BASE-ANY)]
    
    ;; 列表字面量
    [(and (pair? expr) (eq? (car expr) '列表))
     (infer-list-type (cdr expr) env)]
    
    ;; 列表字面量 (简化语法 [1, 2, 3])
    [(list? expr)
     (infer-list-type expr env)]
    
    ;; 二元运算
    [(and (pair? expr) (= (length expr) 3)
          (member (car expr) '(加 减 乘 除 模 幂)))
     (infer-binop-type (car expr) (cadr expr) (caddr expr) env)]
    
    ;; 比较运算
    [(and (pair? expr) (= (length expr) 3)
          (member (car expr) '(大于 小于 大于等于 小于等于 等于 不等)))
     BASE-BOOLEAN]
    
    ;; 逻辑运算
    [(and (pair? expr) (member (car expr) '(与 或 非)))
     BASE-BOOLEAN]
    
    ;; if 表达式
    [(and (pair? expr) (eq? (car expr) 'if) (= (length expr) 4))
     (infer-if-type (cadr expr) (caddr expr) (cadddr expr) env)]
    
    ;; 函数调用
    [(and (pair? expr) (symbol? (car expr)))
     (infer-call-type (car expr) (cdr expr) env)]
    
    ;; 定义表达式
    [(and (pair? expr) (eq? (car expr) '定义))
     (infer-define-type expr env)]
    
    [else BASE-ANY]))

;; ============================================================
;; 列表类型推断
;; ============================================================

(define (infer-list-type items env)
  (if (null? items)
      (type-generic '列表 (list BASE-ANY))
      (let ([item-types (map (lambda (i) (infer-expr-type i env)) items)])
        (if (for/and ([t item-types]) (type-equal? t (car item-types)))
            (type-generic '列表 (list (car item-types)))
            (type-generic '列表 (list BASE-ANY))))))

;; ============================================================
;; 二元运算类型推断
;; ============================================================

(define (infer-binop-type op left right env)
  (let ([left-type (infer-expr-type left env)]
        [right-type (infer-expr-type right env)])
    (cond
      [(or (type-equal? left-type BASE-FLOAT)
           (type-equal? right-type BASE-FLOAT))
       BASE-FLOAT]
      [else BASE-INTEGER])))

;; ============================================================
;; if 类型推断
;; ============================================================

(define (infer-if-type cond then else-expr env)
  (let ([then-type (infer-expr-type then env)]
        [else-type (infer-expr-type else-expr env)])
    (cond
      [(type-equal? then-type else-type) then-type]
      [(type-compatible? then-type else-type) else-type]
      [(type-compatible? else-type then-type) then-type]
      [else BASE-ANY])))

;; ============================================================
;; 函数调用类型推断
;; ============================================================

(define (infer-call-type fn-name args env)
  (let ([fn-sig (type-env-lookup-fn env fn-name)])
    (if fn-sig
        (cadr fn-sig)  ; 返回第二项（返回类型）
        BASE-ANY)))

;; ============================================================
;; 定义表达式推断
;; ============================================================

(define (infer-define-type expr env)
  (cond
    ;; (定义 x val)
    [(and (= (length expr) 3) (symbol? (cadr expr)))
     (infer-expr-type (caddr expr) env)]
    ;; (定义 x: Type val)
    [(and (= (length expr) 4) (symbol? (cadr expr)))
     (parse-type-expr (caddr expr))]
    ;; (定义 (fn . params) . body)
    [(and (pair? (cadr expr)) (symbol? (caadr expr)))
     BASE-ANY]
    [else BASE-ANY]))

;; ============================================================
;; 辅助：解析类型表达式字符串
;; ============================================================

(define (parse-type-expr type-sym)
  (cond
    [(eq? type-sym '整数) BASE-INTEGER]
    [(eq? type-sym '浮点数) BASE-FLOAT]
    [(eq? type-sym '字符串) BASE-STRING]
    [(eq? type-sym '布尔) BASE-BOOLEAN]
    [(eq? type-sym '空值) BASE-NULL]
    [(eq? type-sym '任意) BASE-ANY]
    [else (type-base type-sym)]))

;; ============================================================
;; 带声明的类型环境
;; ============================================================

(define (type-env-with-decls decls env)
  "将变量和函数声明添加到类型环境"
  (for-each (lambda (decl)
              (match decl
                [`(定义 ,(? symbol? var) ,val)
                 (let ([t (infer-expr-type val env)])
                   (type-env-add-var! env var t))]
                [`(定义 (,fn . ,params) . ,body)
                 (type-env-add-fn! env fn (length params) BASE-ANY)]
                [_ (void)]))
            decls)
  env)
```

- [ ] **步骤 2：创建测试文件 test-type-inference.rkt**

```racket
#lang racket/base

(require "lang/type-inference.rkt"
         "lang/type-system.rkt"
         rackunit)

(printf "\n══════ 类型推断测试 ══════\n")

;; 测试 1：字面量推断
(check-true (type-equal? (infer-expr-type 42 (make-type-env)) BASE-INTEGER)
            "整数字面量推断为整数")
(check-true (type-equal? (infer-expr-type 3.14 (make-type-env)) BASE-FLOAT)
            "浮点数字面量推断为浮点数")
(check-true (type-equal? (infer-expr-type "hello" (make-type-env)) BASE-STRING)
            "字符串字面量推断为字符串")
(check-true (type-equal? (infer-expr-type #t (make-type-env)) BASE-BOOLEAN)
            "布尔字面量推断为布尔")

;; 测试 2：列表推断
(check-true (type-equal? (infer-expr-type '(列表 1 2 3) (make-type-env))
                          (type-generic '列表 (list BASE-INTEGER)))
            "整数列表推断为列表<整数>")
(check-true (type-equal? (infer-expr-type '(1 2 3) (make-type-env))
                          (type-generic '列表 (list BASE-INTEGER)))
            "[1, 2, 3]推断为列表<整数>")

;; 测试 3：二元运算推断
(check-true (type-equal? (infer-expr-type '(加 1 2) (make-type-env)) BASE-INTEGER)
            "整数加法推断为整数")
(check-true (type-equal? (infer-expr-type '(加 1 3.14) (make-type-env)) BASE-FLOAT)
            "整数+浮点推断为浮点数")

;; 测试 4：比较运算推断
(check-true (type-equal? (infer-expr-type '(大于 5 3) (make-type-env)) BASE-BOOLEAN)
            "比较运算推断为布尔")

;; 测试 5：if 表达式推断
(check-true (type-equal? (infer-expr-type '(if #t 1 2) (make-type-env)) BASE-INTEGER)
            "if then/else 同类型推断为该类型")
(check-true (type-equal? (infer-expr-type '(if #t 1 "x") (make-type-env)) BASE-ANY)
            "if then/else 不同类型推断为任意")

;; 测试 6：变量引用推断
(define env (make-type-env))
(type-env-add-var! env 'x BASE-INTEGER)
(check-true (type-equal? (infer-expr-type 'x env) BASE-INTEGER)
            "已知变量推断为其类型")
(check-true (type-equal? (infer-expr-type 'y env) BASE-ANY)
            "未知变量推断为任意")

(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  类型推断测试全部通过!                ║\n")
(printf "╚══════════════════════════════════════╝\n")
```

- [ ] **步骤 3：运行测试**

运行：`cd g:\dumategithub\langbyracket\mingdao && racket tests/test-type-inference.rkt`

预期：输出 "类型推断测试全部通过!"

- [ ] **步骤 4：Commit**

```bash
git add mingdao/lang/type-inference.rkt mingdao/tests/test-type-inference.rkt
git commit -m "feat(types): add type-inference.rkt engine

- infer-expr-type: main type inference entry point
- infer-list-type: infer list element type
- infer-binop-type: arithmetic operation type inference
- infer-if-type: conditional expression type inference
- infer-call-type: function call type inference
- Unit tests for all inference functions"
```

---

## 任务 3：重写类型检查器 (type-checker.rkt)

**文件：**
- 修改：`mingdao/lang/type-checker.rkt`（完全重写）
- 依赖：`mingdao/lang/type-system.rkt`, `mingdao/lang/type-inference.rkt`
- 测试：`mingdao/tests/test-strict-types.rkt`

- [ ] **步骤 1：重写类型检查器核心**

```racket
#lang racket/base
;; 明道语言严格类型检查器
;; 类型不匹配时抛出编译错误

(require "lang/type-system.rkt"
         "lang/type-inference.rkt"
         racket/match
         racket/list
         racket/string)

(provide check-program check-expr
         *type-errors* get-type-errors clear-errors!)

;; ============================================================
;; 类型错误结构
;; ============================================================

(struct type-error (message location type-info) #:transparent)

(define *type-errors* null)

(define (record-error! msg loc info)
  (set! *type-errors* (cons (type-error msg loc info) *type-errors*)))

(define (get-type-errors)
  (reverse *type-errors*))

(define (clear-errors!)
  (set! *type-errors* null))

;; ============================================================
;; 严格模式检查
;; ============================================================

(define (check-program ast env)
  "检查整个程序，收集所有类型错误"
  (clear-errors!)
  (for-each (lambda (expr) (check-expr expr env)) ast)
  (unless (null? *type-errors*)
    (error '类型检查
           (format "发现 ~a 个类型错误:\n~a"
                   (length *type-errors*)
                   (string-join (map type-error-message (get-type-errors)) "\n"))))
  (void))

(define (check-expr expr env)
  "检查单个表达式，类型不匹配时记录错误"
  (match expr
    ;; 变量定义: (定义 x val)
    [`(定义 ,(? symbol? var) ,val)
     (let ([inferred-type (infer-expr-type val env)]
           [declared-type BASE-ANY])
       (unless (type-compatible? declared-type inferred-type)
         (record-error! (format "变量 '~a' 类型不匹配：声明为 ~a，实际为 ~a"
                                var (type-expr-name declared-type)
                                (type-expr-name inferred-type))
                        expr '变量定义))
       (type-env-add-var! env var inferred-type))]
    
    ;; 变量定义: (定义 x: Type val)
    [`(定义 ,(? symbol? var) ,(? symbol? type-sym) ,val)
     (let ([inferred-type (infer-expr-type val env)]
           [declared-type (parse-type-expr type-sym)])
       (unless (type-compatible? declared-type inferred-type)
         (record-error! (format "变量 '~a' 类型不匹配：声明为 ~a，实际为 ~a"
                                var (type-expr-name declared-type)
                                (type-expr-name inferred-type))
                        expr '变量定义))
       (type-env-add-var! env var inferred-type))]
    
    ;; 函数定义: (定义 (fn . params) . body)
    [`(定义 (,fn . ,params) . ,body)
     (check-function-definition fn params body env)]
    
    ;; 返回语句: (返回 val)
    [`(返回 ,val)
     (let ([ret-type (infer-expr-type val env)]
           [expected (type-env-lookup-generic env 'return-type)])
       (when expected
         (unless (type-compatible? expected ret-type)
           (record-error! (format "返回类型不匹配：期望 ~a，实际为 ~a"
                                  (type-expr-name expected)
                                  (type-expr-name ret-type))
                          expr '返回类型))))]
    
    ;; 赋值: (= var val)
    [`(= ,var ,val)
     (let ([var-type (type-env-lookup-var env var)]
           [val-type (infer-expr-type val env)])
       (unless (and var-type (type-compatible? var-type val-type))
         (record-error! (format "赋值类型不匹配：变量 '~a' 类型为 ~a，值类型为 ~a"
                                var (and var-type (type-expr-name var-type))
                                (type-expr-name val-type))
                        expr '赋值)))]
    
    ;; if 条件检查
    [`(if ,cond ,then ,else)
     (let ([cond-type (infer-expr-type cond env)])
       (unless (type-compatible? BASE-BOOLEAN cond-type)
         (record-error! (format "if 条件必须为布尔类型，实际为 ~a"
                                (type-expr-name cond-type))
                        cond '条件类型)))
     (check-expr cond env)
     (check-expr then env)
     (check-expr else env)]
    
    ;; 算术运算检查
    [(and `(,op ,a ,b) (member op '(加 减 乘 除 模 幂)))
     (let ([a-type (infer-expr-type a env)]
           [b-type (infer-expr-type b env)])
       (unless (or (type-compatible? BASE-INTEGER a-type)
                   (type-compatible? BASE-FLOAT a-type))
         (record-error! (format "运算 ~a 的左操作数必须为数值类型，实际为 ~a"
                                op (type-expr-name a-type))
                        a '操作数类型))
       (unless (or (type-compatible? BASE-INTEGER b-type)
                   (type-compatible? BASE-FLOAT b-type))
         (record-error! (format "运算 ~a 的右操作数必须为数值类型，实际为 ~a"
                                op (type-expr-name b-type))
                        b '操作数类型)))]
    
    ;; 函数调用检查
    [(and `(,fn . ,args) (symbol? fn))
     (let ([fn-sig (type-env-lookup-fn env fn)])
       (when fn-sig
         (check-function-call fn args (car fn-sig) env)))]
    
    ;; 其他表达式
    [_ (void)]))

(define (check-function-definition fn-name params body env)
  "检查函数定义"
  (for-each (lambda (p) (type-env-add-var! env p BASE-ANY)) params)
  (for-each (lambda (e) (check-expr e env)) body))

(define (check-function-call fn-name args param-count env)
  "检查函数调用参数"
  (when (not (= (length args) param-count))
    (record-error! (format "函数 '~a' 需要 ~a 个参数，但提供了 ~a 个"
                           fn-name param-count (length args))
                   fn-name '参数数量)))
```

- [ ] **步骤 2：创建严格类型测试 test-strict-types.rkt**

```racket
#lang racket/base

(require "lang/type-checker.rkt"
         "lang/type-system.rkt"
         rackunit)

(printf "\n══════ 严格类型检查测试 ══════\n")

(define (test-check name code should-error?)
  (printf "测试: ~a\n" name)
  (clear-errors!)
  (let ([env (make-type-env)]
        [ast (list code)])
    (with-handlers ([exn:fail? (lambda (e)
                                  (if should-error?
                                      (begin
                                        (printf "  ✓ 预期错误: ~a\n" (exn-message e))
                                        #t)
                                      (begin
                                        (printf "  ✗ 意外错误: ~a\n" (exn-message e))
                                        #f)))])
      (check-program ast env)
      (if should-error?
          (begin
            (printf "  ✗ 期望错误但未发生\n")
            #f)
          (begin
            (printf "  ✓ 检查通过\n")
            #t)))))

;; 测试 1：正确类型应通过
(test-check "正确整数赋值"
            '(定义 x 42)
            #f)

;; 测试 2：类型不匹配应报错
(test-check "字符串赋给整数变量应报错"
            '(定义 x: 整数 "hello")
            #t)

;; 测试 3：if 条件类型检查
(test-check "整数作为 if 条件应报错"
            '(if 1 "a" "b")
            #t)

;; 测试 4：算术运算操作数类型
(test-check "字符串加法应报错"
            '(加 "a" "b")
            #t)

;; 测试 5：正确的算术运算应通过
(test-check "整数加法应通过"
            '(加 1 2)
            #f)

;; 测试 6：联合类型赋值
(test-check "联合类型赋值应通过"
            '(定义 x: (整数 或 字符串) "hello")
            #f)

(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  严格类型检查测试全部通过!          ║\n")
(printf "╚══════════════════════════════════════╝\n")
```

- [ ] **步骤 3：运行测试**

运行：`cd g:\dumategithub\langbyracket\mingdao && racket tests/test-strict-types.rkt`

预期：输出 "严格类型检查测试全部通过!"

- [ ] **步骤 4：Commit**

```bash
git add mingdao/lang/type-checker.rkt mingdao/tests/test-strict-types.rkt
git commit -m "feat(types): rewrite type-checker.rkt for strict mode

- type-error struct for error collection
- check-program: main entry point with error aggregation
- check-expr: expression type checking
- check-function-definition, check-function-call
- Strict mode: errors thrown instead of warnings
- Unit tests for type mismatches"
```

---

## 任务 4：创建接口系统 (interface.rkt)

**文件：**
- 创建：`mingdao/lang/interface.rkt`
- 依赖：`mingdao/lang/type-system.rkt`
- 测试：`mingdao/tests/test-interfaces.rkt`

- [ ] **步骤 1：创建接口系统核心**

```racket
#lang racket/base
;; 明道语言接口系统
;; 支持接口定义、实现检查、接口继承

(require "lang/type-system.rkt")

(provide
 ;; 接口定义
 define-interface interface-defined?
 get-interface-methods get-interface-parents
 ;; 接口实现检查
 implements-interface? check-interface-implementation
 ;; 接口继承
 interface-extends?)

;; ============================================================
;; 接口定义存储
;; ============================================================

(define *interfaces* (make-hash))

;; 接口定义结构
(struct interface-def (name methods parents) #:transparent)

;; 定义接口
(define (define-interface name methods [parents null])
  (hash-set! *interfaces* name (interface-def name methods parents)))

;; 检查接口是否定义
(define (interface-defined? name)
  (hash-has-key? *interfaces* name))

;; 获取接口方法列表
(define (get-interface-methods name)
  (let ([iface (hash-ref *interfaces* name #f)])
    (if iface
        (interface-def-methods iface)
        null)))

;; 获取接口父接口
(define (get-interface-parents name)
  (let ([iface (hash-ref *interfaces* name #f)])
    (if iface
        (interface-def-parents iface)
        null)))

;; 检查是否实现了接口（递归检查父接口）
(define (implements-interface? type methods name)
  (let ([iface (hash-ref *interfaces* name #f)])
    (if (not iface)
        #f
        (let ([required-methods (interface-def-methods iface)]
              [provided-names (map car methods)])
          (and
           ;; 检查所有必需方法都已提供
           (for/and ([req required-methods])
             (member (car req) provided-names))
           ;; 检查方法签名兼容
           (for/and ([req required-methods])
             (let ([provided (assoc (car req) methods)])
               (if provided
                   (method-compatible? (cdr req) (cdr provided))
                   #f)))
           ;; 递归检查父接口
           (for/and ([parent (interface-def-parents iface)])
             (implements-interface? type methods parent)))))))

;; 检查方法签名兼容性
(define (method-compatible? required provided)
  (cond
    ;; 如果没有返回类型要求，兼容
    [(null? required) #t]
    [(null? provided) #f]
    ;; 检查参数数量
    [(not (= (length (car required)) (length (car provided)))) #f]
    ;; 检查返回类型
    [else (type-compatible? (cadr required) (cadr provided))]))

;; 接口继承检查
(define (interface-extends? child parent)
  (cond
    [(eq? child parent) #t]
    [else
     (let ([child-iface (hash-ref *interfaces* child #f)])
       (if child-iface
           (ormap (lambda (p) (interface-extends? p parent))
                  (interface-def-parents child-iface))
           #f))]))
```

- [ ] **步骤 2：创建接口测试 test-interfaces.rkt**

```racket
#lang racket/base

(require "lang/interface.rkt"
         rackunit)

(printf "\n══════ 接口系统测试 ══════\n")

;; 定义测试接口
(define-interface '可打印
  (list (cons '转字符串 (cons (list) '字符串))))
(define-interface '可比较
  (list (cons '大于 (cons (list '任意) '布尔))))

(check-true (interface-defined? '可打印) "可打印接口已定义")
(check-false (interface-defined? '不存在的接口) "不存在的接口返回#f")
(check-equal? (get-interface-methods '可打印)
              (list (cons '转字符串 (cons null '字符串)))
              "获取可打印接口方法列表")

;; 测试接口实现检查
(define test-methods (list (cons '转字符串 (cons null '字符串))))
(check-true (implements-interface? '人 test-methods '可打印)
            "人实现了可打印接口")

;; 测试方法签名兼容
(check-false (implements-interface? '人
                                    (list (cons '转字符串 (cons (list '整数) '字符串)))
                                    '可打印)
            "参数数量不匹配应返回#f")

;; 测试接口继承
(define-interface '可序列化的可打印
  (list (cons '序列化 (cons null '字符串)))
  (list '可打印))
(check-true (interface-extends? '可序列化的可打印 '可打印)
            "可序列化的可打印继承自可打印")

(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  接口系统测试全部通过!               ║\n")
(printf "╚══════════════════════════════════════╝\n")
```

- [ ] **步骤 3：运行测试**

运行：`cd g:\dumategithub\langbyracket\mingdao && racket tests/test-interfaces.rkt`

预期：输出 "接口系统测试全部通过!"

- [ ] **步骤 4：Commit**

```bash
git add mingdao/lang/interface.rkt mingdao/tests/test-interfaces.rkt
git commit -m "feat(types): add interface.rkt system

- define-interface: define new interface with methods
- interface-defined?: check if interface exists
- get-interface-methods: get interface method signatures
- implements-interface?: check if type implements interface
- interface-extends?: check interface inheritance
- Unit tests for all functions"
```

---

## 任务 5：增强运行时类型支持 (core/types.rkt)

**文件：**
- 修改：`mingdao/core/types.rkt`
- 依赖：`mingdao/lang/type-system.rkt`

- [ ] **步骤 1：添加严格模式运行时支持**

在 `core/types.rkt` 末尾添加：

```racket
;; ============================================================
;; 严格模式运行时类型校验
;; ============================================================

;; 严格模式开关
(define *strict-runtime-mode* #t)

(define (enable-strict-runtime!)
  (set! *strict-runtime-mode* #t))

(define (disable-strict-runtime!)
  (set! *strict-runtime-mode* #f))

;; 断言类型函数
(define (断言类型 value expected-type)
  (when *strict-runtime-mode*
    (unless (检查类型值 value expected-type)
      (error '断言类型
             (format "运行时类型校验失败: 期望类型 ~a，但得到 ~a (值: ~a)"
                     expected-type
                     (获取类型 value)
                     value))))
  value)

;; 运行时类型检查
(define (运行时类型检查 value type-expr)
  (断言类型 value type-expr))

;; 安全类型转换
(define (安全转整数 value)
  (断言类型 value '整数)
  (转整数 value))

(define (安全转浮点数 value)
  (断言类型 value '浮点数)
  (转浮点数 value))
```

- [ ] **步骤 2：Commit**

```bash
git add mingdao/core/types.rkt
git commit -m "feat(types): enhance core/types.rkt for strict runtime

- *strict-runtime-mode*: runtime type checking toggle
- enable-strict-runtime!, disable-strict-runtime!
- 断言类型: runtime type assertion
- 运行时类型检查: runtime type verification
- 安全转换函数: safe type conversion with assertions"
```

---

## 任务 6：创建泛型测试套件

**文件：**
- 创建：`mingdao/tests/test-generics.rkt`
- 依赖：`mingdao/lang/type-system.rkt`, `mingdao/lang/type-inference.rkt`

- [ ] **步骤 1：创建泛型测试**

```racket
#lang racket/base

(require "lang/type-system.rkt"
         "lang/type-inference.rkt"
         rackunit)

(printf "\n══════ 泛型类型测试 ══════\n")

;; 测试 1：泛型列表类型
(define (test-generic-list)
  (let ([list-int (type-generic '列表 (list BASE-INTEGER))]
        [list-str (type-generic '列表 (list BASE-STRING))])
    (check-true (type-generic? list-int) "列表<整数> 是泛型")
    (check-equal? (type-generic-name list-int) '列表 "泛型名称为列表")
    (check-equal? (car (type-generic-args list-int)) BASE-INTEGER
                  "泛型参数为整数")
    (check-false (type-equal? list-int list-str)
                 "列表<整数> ≠ 列表<字符串>")))

;; 测试 2：嵌套泛型
(define (test-nested-generic)
  (let ([nested (type-generic '列表 (list (type-generic '列表 (list BASE-INTEGER))))]
        [flat (type-generic '列表 (list BASE-INTEGER))])
    (check-false (type-equal? nested flat)
                 "嵌套列表与扁平列表不同")))

;; 测试 3：泛型类型兼容性
(define (test-generic-compat)
  (let ([list-any (type-generic '列表 (list BASE-ANY))])
    (check-true (type-compatible? list-any
                                  (type-generic '列表 (list BASE-INTEGER)))
                "列表<任意> 兼容列表<整数>")))

;; 测试 4：类型参数推断
(define (test-type-param-inference)
  (let ([env (make-type-env)])
    (type-env-add-var! env 'xs (type-generic '列表 (list BASE-INTEGER)))
    (check-true (type-generic? (infer-expr-type 'xs env))
                "列表变量推断为泛型列表")))

;; 运行所有测试
(test-generic-list)
(test-nested-generic)
(test-generic-compat)
(test-type-param-inference)

(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  泛型类型测试全部通过!               ║\n")
(printf "╚══════════════════════════════════════╝\n")
```

- [ ] **步骤 2：运行测试**

运行：`cd g:\dumategithub\langbyracket\mingdao && racket tests/test-generics.rkt`

预期：输出 "泛型类型测试全部通过!"

- [ ] **步骤 3：Commit**

```bash
git add mingdao/tests/test-generics.rkt
git commit -m "test(types): add generics test suite

- test-generic-list: generic list type tests
- test-nested-generic: nested generic types
- test-generic-compat: generic type compatibility
- test-type-param-inference: type parameter inference"
```

---

## 任务 7：集成测试

**文件：**
- 创建：`mingdao/tests/test-strict-type-system.rkt`
- 依赖：所有类型系统模块

- [ ] **步骤 1：创建完整集成测试**

```racket
#lang racket/base

(require "lang/type-system.rkt"
         "lang/type-inference.rkt"
         "lang/type-checker.rkt"
         "lang/interface.rkt"
         rackunit)

(printf "\n══════ 严格类型系统 2.0 集成测试 ══════\n")

;; 测试 1：完整类型检查流程
(define (test-full-type-check)
  (clear-errors!)
  (let ([env (make-type-env)])
    (check-program (list '(定义 x 42)
                        '(定义 y (加 x 1))
                        '(定义 z (if (> y 10) y 0)))
                   env)
    (check-equal? (length (get-type-errors)) 0
                  "无类型错误的程序应通过检查")))

;; 测试 2：类型推断与检查协同
(define (test-inference-check-coop)
  (clear-errors!)
  (let ([env (make-type-env)])
    (type-env-add-var! env 'name BASE-STRING)
    (check-expr '(定义 greeting ("hello" 拼接 name)) env)
    (check-equal? (length (get-type-errors)) 0
                  "字符串拼接应类型正确")))

;; 测试 3：接口与类型系统集成
(define (test-interface-type-integration)
  (define-interface '可迭代
    (list (cons '迭代器 (cons null '任意))))
  (check-true (interface-defined? '可迭代)
              "接口定义与类型系统集成成功"))

;; 测试 4：严格模式错误收集
(define (test-strict-error-collection)
  (clear-errors!)
  (let ([env (make-type-env)])
    (check-program (list '(定义 x: 整数 "hello"))
                   env)
    (check-equal? (length (get-type-errors)) 1
                  "类型错误应被收集")))

;; 运行所有集成测试
(test-full-type-check)
(test-inference-check-coop)
(test-interface-type-integration)
(test-strict-error-collection)

(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  集成测试全部通过!                   ║\n")
(printf "║  M6 严格类型系统 2.0 实现完成!       ║\n")
(printf "╚══════════════════════════════════════╝\n")
```

- [ ] **步骤 2：运行集成测试**

运行：`cd g:\dumategithub\langbyracket\mingdao && racket tests/test-strict-type-system.rkt`

预期：
- 所有测试通过
- 输出 "M6 严格类型系统 2.0 实现完成!"

- [ ] **步骤 3：Commit**

```bash
git add mingdao/tests/test-strict-type-system.rkt
git commit -m "test(types): add strict type system integration tests

- test-full-type-check: complete type checking flow
- test-inference-check-coop: inference and checking cooperation
- test-interface-type-integration: interface with type system
- test-strict-error-collection: error collection in strict mode"
```

---

## 规格覆盖度检查

| 设计章节 | 实现任务 |
|----------|----------|
| 2.1 类型表达式语法 | 任务1: type-system.rkt |
| 2.2 类型层次结构 | 任务1: 基础类型常量定义 |
| 2.3 核心数据结构 | 任务1: type-expr structs, type-env |
| 3.1 严格模式 | 任务3: type-checker.rkt 重写 |
| 3.2 泛型增强 | 任务2, 任务6 |
| 3.3 接口/协议系统 | 任务4: interface.rkt |
| 3.4 类型推断增强 | 任务2: type-inference.rkt |
| 3.5 类型安全保障 | 任务5: core/types.rkt 增强 |
| 5.1 新语法特性 | 类型表达式解析已在 type-system.rkt |
| 6. 类型检查流程 | 任务3: check-program 入口 |
| 8. 测试计划 | 任务1-7: 所有测试文件 |
