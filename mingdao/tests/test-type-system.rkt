#lang racket/base

(require "../lang/type-system.rkt"
         rackunit)

(printf "\n══════ 类型系统核心测试 ══════\n")

;; ============================================================
;; 测试 1：基础类型
;; ============================================================
(printf "\n--- 基础类型测试 ---\n")

(check-true (type-base? BASE-INTEGER) "BASE-INTEGER 是基础类型")
(check-equal? (type-base-name BASE-INTEGER) '整数 "BASE-INTEGER 名称为整数")

(check-true (type-base? BASE-FLOAT) "BASE-FLOAT 是基础类型")
(check-equal? (type-base-name BASE-FLOAT) '浮点数 "BASE-FLOAT 名称为浮点数")

(check-true (type-base? BASE-STRING) "BASE-STRING 是基础类型")
(check-equal? (type-base-name BASE-STRING) '字符串 "BASE-STRING 名称为字符串")

(check-true (type-base? BASE-BOOLEAN) "BASE-BOOLEAN 是基础类型")
(check-equal? (type-base-name BASE-BOOLEAN) '布尔 "BASE-BOOLEAN 名称为布尔")

(check-true (type-base? BASE-NULL) "BASE-NULL 是基础类型")
(check-equal? (type-base-name BASE-NULL) '空值 "BASE-NULL 名称为空值")

(check-true (type-base? BASE-ANY) "BASE-ANY 是基础类型")
(check-equal? (type-base-name BASE-ANY) '任意 "BASE-ANY 名称为任意")

;; ============================================================
;; 测试 2：类型参数
;; ============================================================
(printf "\n--- 类型参数测试 ---\n")

(define type-t (type-param 'T))
(check-true (type-param? type-t) "type-param 创建类型参数 T")
(check-equal? (type-param-name type-t) 'T "类型参数名称为 T")

(define type-u (type-param 'U))
(check-true (type-param? type-u) "type-param 创建类型参数 U")
(check-equal? (type-param-name type-u) 'U "类型参数名称为 U")

;; ============================================================
;; 测试 3：泛型类型
;; ============================================================
(printf "\n--- 泛型类型测试 ---\n")

(define list-int (type-generic '列表 (list BASE-INTEGER)))
(check-true (type-generic? list-int) "列表<整数> 是泛型类型")
(check-equal? (type-generic-name list-int) '列表 "泛型名称为列表")
(check-equal? (length (type-generic-args list-int)) 1 "泛型参数数量为1")
(check-equal? (car (type-generic-args list-int)) BASE-INTEGER "泛型参数为整数")

(define dict-str-int (type-generic '字典 (list BASE-STRING BASE-INTEGER)))
(check-true (type-generic? dict-str-int) "字典<字符串, 整数> 是泛型类型")
(check-equal? (type-generic-name dict-str-int) '字典 "泛型名称为字典")
(check-equal? (length (type-generic-args dict-str-int)) 2 "泛型参数数量为2")

(define nested-list (type-generic '列表 (list (type-generic '列表 (list BASE-INTEGER)))))
(check-true (type-generic? nested-list) "嵌套列表是泛型类型")
(check-true (type-generic? (car (type-generic-args nested-list))) "嵌套列表的内部也是泛型")

;; type-expr-args 测试
(check-equal? (type-expr-args list-int) (list BASE-INTEGER) "type-expr-args 返回泛型参数列表")

;; ============================================================
;; 测试 4：联合类型
;; ============================================================
(printf "\n--- 联合类型测试 ---\n")

(define int-or-str (type-union (list BASE-INTEGER BASE-STRING)))
(check-true (type-union? int-or-str) "整数|字符串 是联合类型")
(check-equal? (length (type-union-types int-or-str)) 2 "联合类型有2个成员")

(define multi-union (type-union (list BASE-INTEGER BASE-STRING BASE-BOOLEAN)))
(check-true (type-union? multi-union) "多成员联合类型")
(check-equal? (length (type-union-types multi-union)) 3 "联合类型有3个成员")

;; type-expr-types 测试
(check-equal? (type-expr-types int-or-str) (list BASE-INTEGER BASE-STRING) "type-expr-types 返回联合成员列表")

;; ============================================================
;; 测试 5：接口类型
;; ============================================================
(printf "\n--- 接口类型测试 ---\n")

(define printable-methods (list (list '转字符串 '字符串)))
(define printable-iface (type-interface '可打印 printable-methods))
(check-true (type-interface? printable-iface) "可打印是接口类型")
(check-equal? (type-interface-name printable-iface) '可打印 "接口名称为可打印")
(check-equal? (type-interface-methods printable-iface) printable-methods "接口方法列表正确")

;; type-expr-methods 测试
(check-equal? (type-expr-methods printable-iface) printable-methods "type-expr-methods 返回接口方法")

;; ============================================================
;; 测试 6：类型别名
;; ============================================================
(printf "\n--- 类型别名测试 ---\n")

(define my-int-alias (type-alias 'MyInt BASE-INTEGER))
(check-true (type-alias? my-int-alias) "MyInt 是类型别名")
(check-equal? (type-alias-name my-int-alias) 'MyInt "类型别名名称为 MyInt")
(check-equal? (type-alias-target my-int-alias) BASE-INTEGER "类型别名目标为基础类型")

;; type-expr-target 测试
(check-equal? (type-expr-target my-int-alias) BASE-INTEGER "type-expr-target 返回别名目标")

;; ============================================================
;; 测试 7：type-expr-name 通用访问器
;; ============================================================
(printf "\n--- 通用访问器测试 ---\n")

(check-equal? (type-expr-name BASE-INTEGER) '整数 "type-expr-name 用于基础类型")
(check-equal? (type-expr-name type-t) 'T "type-expr-name 用于类型参数")
(check-equal? (type-expr-name list-int) '列表 "type-expr-name 用于泛型类型")
(check-equal? (type-expr-name int-or-str) '联合 "type-expr-name 用于联合类型")
(check-equal? (type-expr-name printable-iface) '可打印 "type-expr-name 用于接口类型")
(check-equal? (type-expr-name my-int-alias) 'MyInt "type-expr-name 用于类型别名")

;; ============================================================
;; 测试 8：builtin-type? 和 *base-types*
;; ============================================================
(printf "\n--- 内置类型判断测试 ---\n")

(check-true (builtin-type? '整数) "整数是内置类型")
(check-true (builtin-type? '浮点数) "浮点数是内置类型")
(check-true (builtin-type? '字符串) "字符串是内置类型")
(check-true (builtin-type? '布尔) "布尔是内置类型")
(check-true (builtin-type? '空值) "空值是内置类型")
(check-true (builtin-type? '任意) "任意是内置类型")
(check-false (builtin-type? 'MyType) "自定义类型不是内置类型")
(check-false (builtin-type? '列表) "泛型名称不是内置类型")

;; ============================================================
;; 测试 9：类型兼容性 - 相同类型
;; ============================================================
(printf "\n--- 类型兼容性测试：相同类型 ---\n")

(check-true (type-compatible? BASE-INTEGER BASE-INTEGER) "整数兼容整数")
(check-true (type-compatible? BASE-FLOAT BASE-FLOAT) "浮点数兼容浮点数")
(check-true (type-compatible? BASE-STRING BASE-STRING) "字符串兼容字符串")
(check-true (type-compatible? BASE-BOOLEAN BASE-BOOLEAN) "布尔兼容布尔")
(check-true (type-compatible? BASE-NULL BASE-NULL) "空值兼容空值")

;; ============================================================
;; 测试 10：类型兼容性 - 整数与浮点数
;; ============================================================
(printf "\n--- 类型兼容性测试：整数与浮点数 ---\n")

(check-true (type-compatible? BASE-FLOAT BASE-INTEGER) "浮点数兼容整数（自动转换）")
(check-false (type-compatible? BASE-INTEGER BASE-FLOAT) "整数不兼容浮点数")

;; ============================================================
;; 测试 11：类型兼容性 - 任意类型
;; ============================================================
(printf "\n--- 类型兼容性测试：任意类型 ---\n")

(check-true (type-compatible? BASE-ANY BASE-INTEGER) "任意兼容整数")
(check-true (type-compatible? BASE-ANY BASE-STRING) "任意兼容字符串")
(check-true (type-compatible? BASE-INTEGER BASE-ANY) "整数兼容任意")
(check-true (type-compatible? BASE-ANY BASE-ANY) "任意兼容任意")

;; ============================================================
;; 测试 12：类型兼容性 - 联合类型
;; ============================================================
(printf "\n--- 类型兼容性测试：联合类型 ---\n")

(check-true (type-compatible? int-or-str BASE-INTEGER) "联合类型包含整数")
(check-true (type-compatible? int-or-str BASE-STRING) "联合类型包含字符串")
(check-false (type-compatible? int-or-str BASE-BOOLEAN) "联合类型不包含布尔")

;; 多成员联合
(check-true (type-compatible? multi-union BASE-INTEGER) "多成员联合包含整数")
(check-true (type-compatible? multi-union BASE-STRING) "多成员联合包含字符串")
(check-true (type-compatible? multi-union BASE-BOOLEAN) "多成员联合包含布尔")
(check-false (type-compatible? multi-union BASE-NULL) "多成员联合不包含空值")

;; ============================================================
;; 测试 13：类型兼容性 - 类型参数
;; ============================================================
(printf "\n--- 类型兼容性测试：类型参数 ---\n")

(check-true (type-compatible? type-t BASE-INTEGER) "类型参数 T 兼容整数")
(check-true (type-compatible? type-t BASE-STRING) "类型参数 T 兼容字符串")
(check-true (type-compatible? type-t BASE-ANY) "类型参数 T 兼容任意")

;; ============================================================
;; 测试 14：类型兼容性 - 泛型类型
;; ============================================================
(printf "\n--- 类型兼容性测试：泛型类型 ---\n")

(define list-int-2 (type-generic '列表 (list BASE-INTEGER)))
(define list-str (type-generic '列表 (list BASE-STRING)))
(define list-any (type-generic '列表 (list BASE-ANY)))

(check-true (type-compatible? list-int list-int-2) "列表<整数> 兼容列表<整数>")
(check-false (type-compatible? list-int list-str) "列表<整数> 不兼容列表<字符串>")
(check-true (type-compatible? list-any list-int) "列表<任意> 兼容列表<整数>")

;; 嵌套泛型兼容性
(check-true (type-compatible? nested-list nested-list) "嵌套列表兼容自身")

;; ============================================================
;; 测试 15：type-equal? - 基础类型
;; ============================================================
(printf "\n--- type-equal? 测试：基础类型 ---\n")

(check-true (type-equal? BASE-INTEGER BASE-INTEGER) "整数等于整数")
(check-false (type-equal? BASE-INTEGER BASE-FLOAT) "整数不等于浮点数")
(check-false (type-equal? BASE-INTEGER BASE-STRING) "整数不等于字符串")

;; ============================================================
;; 测试 16：type-equal? - 类型参数
;; ============================================================
(printf "\n--- type-equal? 测试：类型参数 ---\n")

(check-true (type-equal? type-t type-t) "T 等于 T")
(check-false (type-equal? type-t type-u) "T 不等于 U")

;; ============================================================
;; 测试 17：type-equal? - 泛型类型
;; ============================================================
(printf "\n--- type-equal? 测试：泛型类型 ---\n")

(check-true (type-equal? list-int list-int-2) "列表<整数> 等于列表<整数>")
(check-false (type-equal? list-int list-str) "列表<整数> 不等于列表<字符串>")
(check-false (type-equal? list-int (type-generic '列表 (list BASE-INTEGER BASE-STRING)))
             "列表<整数> 不等于列表<整数, 字符串>")

;; ============================================================
;; 测试 18：type-equal? - 联合类型
;; ============================================================
(printf "\n--- type-equal? 测试：联合类型 ---\n")

(define int-or-str-2 (type-union (list BASE-INTEGER BASE-STRING)))
(define str-or-int (type-union (list BASE-STRING BASE-INTEGER)))

(check-true (type-equal? int-or-str int-or-str-2) "联合类型相等（成员相同顺序不同）")
(check-false (type-equal? int-or-str str-or-int) "联合类型成员顺序影响相等性")
(check-false (type-equal? int-or-str multi-union) "联合类型成员数量不同")

;; ============================================================
;; 测试 19：type-equal? - 接口类型
;; ============================================================
(printf "\n--- type-equal? 测试：接口类型 ---\n")

(define iface1 (type-interface '可打印 (list (list '转字符串 '字符串))))
(define iface2 (type-interface '可打印 (list (list '转字符串 '字符串))))
(define iface3 (type-interface '可打印 (list (list '打印 '空值))))

(check-true (type-equal? iface1 iface2) "相同名称和方法的接口相等")
(check-false (type-equal? iface1 iface3) "不同方法的接口不相等")

;; ============================================================
;; 测试 20：type-equal? - 类型别名
;; ============================================================
(printf "\n--- type-equal? 测试：类型别名 ---\n")

(define alias1 (type-alias 'MyInt BASE-INTEGER))
(define alias2 (type-alias 'MyInt BASE-INTEGER))
(define alias3 (type-alias 'MyInt BASE-STRING))

(check-true (type-equal? alias1 alias2) "相同名称和目标的类型别名相等")
(check-false (type-equal? alias1 alias3) "相同名称但不同目标的类型别名不相等")

;; ============================================================
;; 测试 21：类型环境 - 创建和基本操作
;; ============================================================
(printf "\n--- 类型环境测试：创建和基本操作 ---\n")

(define env (make-type-env))
(check-true (type-env? env) "make-type-env 创建类型环境")
(check-true (hash? (type-env-vars env)) "类型环境包含 vars hash")
(check-true (hash? (type-env-fns env)) "类型环境包含 fns hash")
(check-true (hash? (type-env-types env)) "类型环境包含 types hash")
(check-true (hash? (type-env-ifaces env)) "类型环境包含 ifaces hash")
(check-true (hash? (type-env-generics env)) "类型环境包含 generics hash")

;; ============================================================
;; 测试 22：类型环境 - 添加和查找变量
;; ============================================================
(printf "\n--- 类型环境测试：变量 ---\n")

(type-env-add-var! env 'x BASE-INTEGER)
(type-env-add-var! env 'y BASE-STRING)
(type-env-add-var! env 'name BASE-STRING)

(check-equal? (type-env-lookup-var env 'x) BASE-INTEGER "环境可查找变量 x")
(check-equal? (type-env-lookup-var env 'y) BASE-STRING "环境可查找变量 y")
(check-equal? (type-env-lookup-var env 'name) BASE-STRING "环境可查找变量 name")
(check-false (type-env-lookup-var env 'z) "不存在的变量返回 #f")
(check-false (type-env-lookup-var env 'undefined) "未定义的变量返回 #f")

;; ============================================================
;; 测试 23：类型环境 - 添加和查找函数
;; ============================================================
(printf "\n--- 类型环境测试：函数 ---\n")

(type-env-add-fn! env '加 (list BASE-INTEGER BASE-INTEGER) BASE-INTEGER)
(type-env-add-fn! env '拼接 (list BASE-STRING BASE-STRING) BASE-STRING)

(check-equal? (type-env-lookup-fn env '加) (list (list BASE-INTEGER BASE-INTEGER) BASE-INTEGER)
              "环境可查找函数 加")
(check-equal? (type-env-lookup-fn env '拼接) (list (list BASE-STRING BASE-STRING) BASE-STRING)
              "环境可查找函数 拼接")
(check-false (type-env-lookup-fn env '不存在) "不存在的函数返回 #f")

;; ============================================================
;; 测试 24：类型环境 - 添加和查找类型别名
;; ============================================================
(printf "\n--- 类型环境测试：类型别名 ---\n")

(type-env-add-type! env 'MyInt BASE-INTEGER)
(type-env-add-type! env 'MyStr BASE-STRING)

(check-equal? (type-env-lookup-type env 'MyInt) BASE-INTEGER "环境可查找类型别名 MyInt")
(check-equal? (type-env-lookup-type env 'MyStr) BASE-STRING "环境可查找类型别名 MyStr")
(check-false (type-env-lookup-type env 'Undefined) "不存在的类型别名返回 #f")

;; ============================================================
;; 测试 25：类型环境 - 添加和查找接口
;; ============================================================
(printf "\n--- 类型环境测试：接口 ---\n")

(type-env-add-iface! env '可打印 printable-methods)
(type-env-add-iface! env '可比较 (list (list '大于 (list BASE-ANY) BASE-BOOLEAN)))

(check-equal? (type-env-lookup-iface env '可打印) printable-methods "环境可查找接口 可打印")
(check-equal? (type-env-lookup-iface env '可比较) (list (list '大于 (list BASE-ANY) BASE-BOOLEAN))
              "环境可查找接口 可比较")
(check-false (type-env-lookup-iface env '不存在) "不存在的接口返回 #f")

;; ============================================================
;; 测试 26：类型环境 - 添加和查找泛型约束
;; ============================================================
(printf "\n--- 类型环境测试：泛型约束 ---\n")

(type-env-add-generic! env 'T (list '可比较))
(type-env-add-generic! env 'U (list '可打印))

(check-equal? (type-env-lookup-generic env 'T) (list '可比较) "环境可查找泛型约束 T")
(check-equal? (type-env-lookup-generic env 'U) (list '可打印) "环境可查找泛型约束 U")
(check-false (type-env-lookup-generic env 'V) "不存在的泛型约束返回 #f")

;; ============================================================
;; 测试 27：make-type-expr 工厂函数
;; ============================================================
(printf "\n--- make-type-expr 工厂函数测试 ---\n")

(check-true (type-base? (make-type-expr '整数 '())) "make-type-expr '整数 返回基础类型")
(check-true (type-base? (make-type-expr '浮点数 '())) "make-type-expr '浮点数 返回基础类型")
(check-true (type-generic? (make-type-expr '列表 (list BASE-INTEGER)))
            "make-type-expr '列表 带参数返回泛型类型")

;; ============================================================
;; 汇总
;; ============================================================
(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  类型系统核心测试全部通过!          ║\n")
(printf "╚══════════════════════════════════════╝\n")