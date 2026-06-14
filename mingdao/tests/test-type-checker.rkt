#lang racket/base
;; 类型检查器 rackunit 测试
;; 测试 infer-type、type-compatible?、check-types 和 check-expr 递归

(require rackunit
         "../lang/type-checker.rkt")

(printf "\n══════ 类型推断测试 ══════\n")

;; ============================================================
;; 1. infer-type 基本类型
;; ============================================================

(check-equal? (infer-type 42 #hasheq()) '整数 "整数字面量 → 整数")
(check-equal? (infer-type 3.14 #hasheq()) '浮点数 "浮点数字面量 → 浮点数")
(check-equal? (infer-type "hello" #hasheq()) '字符串 "字符串字面量 → 字符串")
(check-equal? (infer-type #t #hasheq()) '布尔 "布尔字面量 → 布尔")
(check-equal? (infer-type '() #hasheq()) '空值 "空值 → 空值")
(check-equal? (infer-type '(列表 "a" "b") #hasheq()) '(列表 字符串) "Mingdao 列表 → (列表 字符串)")

(printf "  ✔ 基本类型推断通过\n")

;; ============================================================
;; 2. infer-type 变量引用
;; ============================================================

(check-equal? (infer-type 'x #hasheq((x . 整数))) '整数 "变量 x:整数 → 整数")
(check-equal? (infer-type 'y #hasheq()) '任意 "未定义变量 → 任意")

(printf "  ✔ 变量引用推断通过\n")

;; ============================================================
;; 3. infer-type 二元运算
;; ============================================================

(check-equal? (infer-type '(加 1 2) #hasheq()) '整数 "加 整数+整数 → 整数")
(check-equal? (infer-type '(加 1 3.14) #hasheq()) '浮点数 "加 整数+浮点 → 浮点数")
(check-equal? (infer-type '(大于 5 3) #hasheq()) '布尔 "大于 → 布尔")
(check-equal? (infer-type '(等于 "a" "b") #hasheq()) '布尔 "等于 → 布尔")

(printf "  ✔ 二元运算推断通过\n")

;; ============================================================
;; 4. infer-type 列表
;; ============================================================

(check-equal? (infer-type '(列表) #hasheq()) '列表 "空列表 → 列表")
(check-equal? (infer-type '(列表 1 2 3) #hasheq()) '(列表 整数) "整数列表 → (列表 整数)")

(printf "  ✔ 列表类型推断通过\n")

;; ============================================================
;; 5. infer-type if 表达式
;; ============================================================

(check-equal? (infer-type '(if (大于 3 1) 42 0) #hasheq()) '整数 "if then/else 同类型 → 整数")
(check-equal? (infer-type '(if (大于 3 1) 42 "x") #hasheq()) '任意 "if then/else 不同类型 → 任意")

(printf "  ✔ if 类型推断通过\n")

;; ============================================================
;; 6. type-compatible? 兼容性检查
;; ============================================================

(check-true (type-compatible? '整数 '整数) "整数和整数兼容")
(check-true (type-compatible? '浮点数 '整数) "浮点和整数兼容")
(check-true (type-compatible? '任意 '字符串) "任意和任何类型兼容")
(check-true (type-compatible? '(或 整数 字符串) '整数) "联合类型包含整数")
(check-true (type-compatible? '(或 整数 字符串) '字符串) "联合类型包含字符串")
(check-equal? (type-compatible? '(或 整数 字符串) '布尔) #f "联合类型不包含布尔")

(printf "  ✔ 类型兼容性检查通过\n")

;; ============================================================
;; 7. check-types 警告捕获测试
;; ============================================================

(printf "\n══════ 类型检查警告测试 ══════\n")

;; 收集警告的辅助函数
(define warnings '())
(define (collect-warn msg)
  (set! warnings (cons msg warnings)))

(define (clear-warnings!)
  (set! warnings '()))

;; 7a. 变量类型不匹配应产生警告
(clear-warnings!)
(check-types '((定义 x 42)) #hasheq((x . 字符串)) #hasheq() collect-warn)
(check-true (pair? warnings) "字符串变量赋整数 → 应产生警告")
(check-equal? (length warnings) 1 "应恰好产生 1 个警告")

(printf "  ✔ 变量类型不匹配警告通过\n")

;; 7b. 变量类型匹配不应产生警告
(clear-warnings!)
(check-types '((定义 x 42)) #hasheq((x . 整数)) #hasheq() collect-warn)
(check-equal? (length warnings) 0 "整数变量赋整数 → 不应有警告")

(printf "  ✔ 变量类型匹配通过\n")

;; 7c. 带有类型兼容（浮点←整数）不应产生警告
(clear-warnings!)
(check-types '((定义 x 42)) #hasheq((x . 浮点数)) #hasheq() collect-warn)
(check-equal? (length warnings) 0 "浮点变量赋整数 → 不应有警告（自动转换）")

(printf "  ✔ 浮点兼容通过\n")

;; 7d. if 条件类型检查
(clear-warnings!)
(check-types '((if 1 "a" "b")) #hasheq() #hasheq() collect-warn)
(check-true (pair? warnings) "if 条件为整数 → 应产生警告")

(printf "  ✔ if 条件检查通过\n")

;; 7e. 赋值类型检查
(clear-warnings!)
(check-types '((= x "str")) #hasheq((x . 整数)) #hasheq() collect-warn)
(check-true (pair? warnings) "赋值类型不匹配 → 应产生警告")

(printf "  ✔ 赋值检查通过\n")

;; 7f. 函数返回类型检查
(clear-warnings!)
(check-types '((定义 (fn) (返回 "str"))) #hasheq((fn . 整数)) #hasheq() collect-warn)
(check-true (pair? warnings) "函数返回类型不匹配 → 应产生警告")

(printf "  ✔ 函数返回类型检查通过\n")

;; 7g. 算术运算操作数检查
(clear-warnings!)
(check-types '((加 "a" "b")) #hasheq() #hasheq() collect-warn)
(check-true (pair? warnings) "字符串加法 → 应产生警告")

(printf "  ✔ 算术操作数检查通过\n")

(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  类型检查器 rackunit 测试通过!     ║\n")
(printf "╚══════════════════════════════════════╝\n")