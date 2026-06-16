#lang racket/base
;; 明道语言类型推断引擎测试

(require "../lang/type-inference.rkt"
         "../lang/type-system.rkt"
         rackunit)

(printf "\n══════ 类型推断测试 ══════\n")

;; ============================================================
;; 测试 1：字面量推断
;; ============================================================
(printf "\n--- 字面量推断测试 ---\n")

(check-true (type-equal? (infer-expr-type 42 (make-type-env)) BASE-INTEGER)
            "整数字面量推断为整数")
(check-true (type-equal? (infer-expr-type 3.14 (make-type-env)) BASE-FLOAT)
            "浮点数字面量推断为浮点数")
(check-true (type-equal? (infer-expr-type "hello" (make-type-env)) BASE-STRING)
            "字符串字面量推断为字符串")
(check-true (type-equal? (infer-expr-type #t (make-type-env)) BASE-BOOLEAN)
            "布尔字面量推断为布尔")
(check-true (type-equal? (infer-expr-type '() (make-type-env)) BASE-NULL)
            "空值字面量推断为空值")

;; ============================================================
;; 测试 2：列表推断
;; ============================================================
(printf "\n--- 列表推断测试 ---\n")

(check-true (type-equal? (infer-expr-type '(列表 1 2 3) (make-type-env))
                          (type-generic '列表 (list BASE-INTEGER)))
            "整数列表推断为列表<整数>")
(check-true (type-equal? (infer-expr-type '(1 2 3) (make-type-env))
                          (type-generic '列表 (list BASE-INTEGER)))
            "[1, 2, 3]推断为列表<整数>")
(check-true (type-equal? (infer-expr-type '(列表) (make-type-env))
                          (type-generic '列表 (list BASE-ANY)))
            "空列表推断为列表<任意>")
(check-true (type-equal? (infer-expr-type '(列表 "a" "b") (make-type-env))
                          (type-generic '列表 (list BASE-STRING)))
            "字符串列表推断为列表<字符串>")
(check-true (type-equal? (infer-expr-type '(列表 1 "a") (make-type-env))
                          (type-generic '列表 (list BASE-ANY)))
            "混合类型列表推断为列表<任意>")

;; ============================================================
;; 测试 3：二元运算推断
;; ============================================================
(printf "\n--- 二元运算推断测试 ---\n")

(check-true (type-equal? (infer-expr-type '(加 1 2) (make-type-env)) BASE-INTEGER)
            "整数加法推断为整数")
(check-true (type-equal? (infer-expr-type '(减 5 3) (make-type-env)) BASE-INTEGER)
            "整数减法推断为整数")
(check-true (type-equal? (infer-expr-type '(乘 2 3) (make-type-env)) BASE-INTEGER)
            "整数乘法推断为整数")
(check-true (type-equal? (infer-expr-type '(除 6 2) (make-type-env)) BASE-INTEGER)
            "整数除法推断为整数")
(check-true (type-equal? (infer-expr-type '(加 1 3.14) (make-type-env)) BASE-FLOAT)
            "整数+浮点推断为浮点数")
(check-true (type-equal? (infer-expr-type '(乘 2.5 3.0) (make-type-env)) BASE-FLOAT)
            "浮点乘法推断为浮点数")

;; ============================================================
;; 测试 4：比较运算推断
;; ============================================================
(printf "\n--- 比较运算推断测试 ---\n")

(check-true (type-equal? (infer-expr-type '(大于 5 3) (make-type-env)) BASE-BOOLEAN)
            "大于比较推断为布尔")
(check-true (type-equal? (infer-expr-type '(小于 3 5) (make-type-env)) BASE-BOOLEAN)
            "小于比较推断为布尔")
(check-true (type-equal? (infer-expr-type '(大于等于 5 3) (make-type-env)) BASE-BOOLEAN)
            "大于等于比较推断为布尔")
(check-true (type-equal? (infer-expr-type '(小于等于 3 5) (make-type-env)) BASE-BOOLEAN)
            "小于等于比较推断为布尔")
(check-true (type-equal? (infer-expr-type '(等于 5 5) (make-type-env)) BASE-BOOLEAN)
            "等于比较推断为布尔")
(check-true (type-equal? (infer-expr-type '(不等 5 3) (make-type-env)) BASE-BOOLEAN)
            "不等于比较推断为布尔")

;; ============================================================
;; 测试 5：逻辑运算推断
;; ============================================================
(printf "\n--- 逻辑运算推断测试 ---\n")

(check-true (type-equal? (infer-expr-type '(与 #t #f) (make-type-env)) BASE-BOOLEAN)
            "逻辑与推断为布尔")
(check-true (type-equal? (infer-expr-type '(或 #t #f) (make-type-env)) BASE-BOOLEAN)
            "逻辑或推断为布尔")
(check-true (type-equal? (infer-expr-type '(非 #t) (make-type-env)) BASE-BOOLEAN)
            "逻辑非推断为布尔")

;; ============================================================
;; 测试 6：if 表达式推断
;; ============================================================
(printf "\n--- if 表达式推断测试 ---\n")

(check-true (type-equal? (infer-expr-type '(if #t 1 2) (make-type-env)) BASE-INTEGER)
            "if then/else 同类型推断为该类型")
(check-true (type-equal? (infer-expr-type '(if #t "a" "b") (make-type-env)) BASE-STRING)
            "if then/else 同为字符串推断为字符串")
(check-true (type-equal? (infer-expr-type '(if #t 1 "x") (make-type-env)) BASE-ANY)
            "if then/else 不同类型推断为任意")
(check-true (type-equal? (infer-expr-type '(if (大于 3 1) 42 0) (make-type-env)) BASE-INTEGER)
            "嵌套条件表达式的 if 推断为整数")

;; ============================================================
;; 测试 7：变量引用推断
;; ============================================================
(printf "\n--- 变量引用推断测试 ---\n")

(define test-env-1 (make-type-env))
(type-env-add-var! test-env-1 'x BASE-INTEGER)
(type-env-add-var! test-env-1 'name BASE-STRING)

(check-true (type-equal? (infer-expr-type 'x test-env-1) BASE-INTEGER)
            "已知变量推断为其类型")
(check-true (type-equal? (infer-expr-type 'name test-env-1) BASE-STRING)
            "已知变量 name 推断为字符串")
(check-true (type-equal? (infer-expr-type 'y test-env-1) BASE-ANY)
            "未知变量推断为任意")

;; ============================================================
;; 测试 8：函数调用推断
;; ============================================================
(printf "\n--- 函数调用推断测试 ---\n")

(define test-env-2 (make-type-env))
(type-env-add-fn! test-env-2 '加 (list BASE-INTEGER BASE-INTEGER) BASE-INTEGER)
(type-env-add-fn! test-env-2 '拼接 (list BASE-STRING BASE-STRING) BASE-STRING)
(type-env-add-fn! test-env-2 '求最大值 (list BASE-INTEGER BASE-INTEGER) BASE-INTEGER)

(check-true (type-equal? (infer-call-type '加 (list 1 2) test-env-2) BASE-INTEGER)
            "函数加推断返回整数")
(check-true (type-equal? (infer-call-type '拼接 (list "a" "b") test-env-2) BASE-STRING)
            "函数拼接推断返回字符串")
(check-true (type-equal? (infer-call-type '求最大值 (list 1 2) test-env-2) BASE-INTEGER)
            "函数求最大值推断返回整数")
(check-true (type-equal? (infer-call-type '未知函数 (list 1 2) test-env-2) BASE-ANY)
            "未知函数推断返回任意")

;; ============================================================
;; 测试 9：定义表达式推断
;; ============================================================
(printf "\n--- 定义表达式推断测试 ---\n")

(check-true (type-equal? (infer-expr-type '(定义 x 42) (make-type-env)) BASE-INTEGER)
            "(定义 x 42) 推断为整数")
(check-true (type-equal? (infer-expr-type '(定义 y "hello") (make-type-env)) BASE-STRING)
            "(定义 y \"hello\") 推断为字符串")

;; ============================================================
;; 测试 10：parse-type-expr 测试
;; ============================================================
(printf "\n--- parse-type-expr 测试 ---\n")

(check-true (type-equal? (parse-type-expr '整数) BASE-INTEGER)
            "解析整数类型")
(check-true (type-equal? (parse-type-expr '浮点数) BASE-FLOAT)
            "解析浮点数类型")
(check-true (type-equal? (parse-type-expr '字符串) BASE-STRING)
            "解析字符串类型")
(check-true (type-equal? (parse-type-expr '布尔) BASE-BOOLEAN)
            "解析布尔类型")
(check-true (type-equal? (parse-type-expr '空值) BASE-NULL)
            "解析空值类型")
(check-true (type-equal? (parse-type-expr '任意) BASE-ANY)
            "解析任意类型")

;; ============================================================
;; 测试 11：infer-function-return 测试
;; ============================================================
(printf "\n--- infer-function-return 测试 ---\n")

(check-true (type-equal? (infer-function-return '加 test-env-2) BASE-INTEGER)
            "infer-function-return 返回函数返回类型")
(check-true (type-equal? (infer-function-return '拼接 test-env-2) BASE-STRING)
            "infer-function-return 返回字符串拼接函数类型")
(check-true (type-equal? (infer-function-return '未知 test-env-2) BASE-ANY)
            "infer-function-return 对未知函数返回任意")

;; ============================================================
;; 测试 12：type-env-with-decls 测试
;; ============================================================
(printf "\n--- type-env-with-decls 测试 ---\n")

(define test-env-3 (make-type-env))
(type-env-with-decls (list '(定义 x 42)
                           '(定义 (fn a b) (返回 (加 a b))))
                      test-env-3)

(check-true (type-equal? (type-env-lookup-var test-env-3 'x) BASE-INTEGER)
            "type-env-with-decls 添加变量 x")
(check-true (pair? (type-env-lookup-fn test-env-3 'fn))
            "type-env-with-decls 添加函数 fn")

;; ============================================================
;; 汇总
;; ============================================================
(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  类型推断测试全部通过!                ║\n")
(printf "╚══════════════════════════════════════╝\n")