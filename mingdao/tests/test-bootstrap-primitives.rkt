#lang racket/base

;; 明道自举 Phase 0：基础库测试
;; 验证新增的字符/字符串操作函数

(require racket/port racket/file
         "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

;; ========== 自动检测项目根目录 ==========
(define project-root
  (cond
    [(file-exists? (build-path (current-directory) "mingdao" "main.rkt"))
     (build-path (current-directory) "mingdao")]
    [(file-exists? (build-path (current-directory) "main.rkt"))
     (current-directory)]
    [(file-exists? (build-path (current-directory) ".." "main.rkt"))
     (build-path (current-directory) "..")]
    [else
     (error "test-bootstrap-primitives.rkt: cannot determine project root.")]))

;; 设置命名空间
(define ns
  (let ([ns (make-base-namespace)])
    (parameterize ([current-namespace ns])
      (define main-path
        (build-path project-root "main.rkt"))
      (eval `(require (file ,(path->string main-path)) racket/control))
      (void))
    ns))

(define (run-test name code)
  (printf "▶ ~a\n" name)
  (printf "  代码: ~a\n" code)
  (parameterize ([current-namespace ns])
    (with-handlers ([exn:fail? (λ (e)
                                 (printf "  ✗ 失败: ~a\n\n" (exn-message e)))])
      (define tokens (tokenize code))
      (define ast (parse tokens))
      (for ([expr ast])
        (define result
          (call-with-values
            (λ () (eval expr ns))
            (λ results results)))
        (unless (void? (if (null? result) (void) (car result)))
          (printf "  ✓ 结果: ~a\n" (car result)))))
    (printf "\n")))

(printf "══════════════════════════════════\n")
(printf "  明道自举 Phase 0：基础库测试\n")
(printf "══════════════════════════════════\n\n")

;; 注意：SVO 语法中 打印,(函数,参数) 用括号包裹子表达式
;; 表示"先计算函数(参数)，再将结果传给打印"

;; ========== 字符/整数转换 ==========
(run-test "字符：65 → A"
          "打印,(字符,65)")
(run-test "字符码：A → 65"
          "打印,(字符码,\"A\")")

;; ========== 字符串操作 ==========
(run-test "字符串索引：明道[1] → 道"
          "打印,(字符串索引,\"明道\",1)")
(run-test "字符串长度：明道 → 2"
          "打印,(字符串长度,\"明道\")")

;; ========== 字符串/列表互转 ==========
(run-test "字符串转列表"
          "打印,(字符串转列表,\"明道\")")
(run-test "列表转字符串 往返测试"
          "打印,(列表转字符串,(字符串转列表,\"明道\"))")

;; ========== 字符判断 ==========
(run-test "是中文：汉 → #t"
          "打印,(是中文,\"汉\")")
(run-test "是数字：3 → #t"
          "打印,(是数字,\"3\")")
(run-test "是字母：A → #t"
          "打印,(是字母,\"A\")")
(run-test "是空白：空格 → #t"
          "打印,(是空白,\" \")")
(run-test "是换行"
          "打印,(是换行,(字符串索引,\"A\nB\",1))")

;; ========== 字符串比较 ==========
(run-test "字符串前缀"
          "打印,(字符串前缀,\"明道\",\"明\")")
(run-test "字符串包含"
          "打印,(字符串包含,\"明道\",\"道\")")

;; ========== 列表/数字操作 ==========
(run-test "反转：(1 2 3) → (3 2 1)"
          "定义lst就是列表,1,2,3\n打印,(反转,lst)")
(run-test "数字转字符串：42 → \"42\""
          "打印,(数字转字符串,42)")
(run-test "子字符串"
          "打印,(子字符串,\"明道语言\",0,2)")

;; ========== 通用工具 ==========
(run-test "是否相等：5=5 → #t"
          "打印,(是否相等,5,5)")
(run-test "是否相等：5≠6 → #f"
          "打印,(是否相等,5,6)")

(printf "══════════════════════════════════\n")
(printf "  测试完成\n")
(printf "══════════════════════════════════\n")

;; ============================================================
;; 新增测试：Python 3.12 风格基础库
;; ============================================================

(printf "\n══════════════════════════════════\n")
(printf "  Python 3.12 风格基础库测试\n")
(printf "══════════════════════════════════\n\n")

;; ========== 字符串方法 ==========
(run-test "大写：\"hello\" → \"HELLO\""
          "打印,(大写,\"hello\")")

(run-test "小写：\"HELLO\" → \"hello\""
          "打印,(小写,\"HELLO\")")

(run-test "替换：\"hello world\" old→world new→明道"
          "打印,(替换,\"hello world\",\"world\",\"明道\")")

(run-test "去空格：\"  hello  \" → \"hello\""
          "打印,(去空格,\"  hello  \")")

(run-test "拆分：\"a,b,c\" 按逗号拆分"
          "打印,(拆分,\"a,b,c\",\",\")")

(run-test "连接：用逗号连接列表"
          "打印,(连接,\",\",列表\"a\",\"b\",\"c\")")

(run-test "查找：\"hello\"中找\"ll\" → 2"
          "打印,(查找,\"hello\",\"ll\")")

(run-test "查找：\"hello\"中找\"xyz\" → -1"
          "打印,(查找,\"hello\",\"xyz\")")

(run-test "计数：\"hello\"中\"l\"出现2次"
          "打印,(计数,\"hello\",\"l\")")

(run-test "重复字符串：\"ha\"重复3次"
          "打印,(重复字符串,\"ha\",3)")

(run-test "字符串后缀：\"hello\"以\"lo\"结尾 → #t"
          "打印,(字符串后缀,\"hello\",\"lo\")")

(run-test "字符串后缀：\"hello\"以\"hi\"结尾 → #f"
          "打印,(字符串后缀,\"hello\",\"hi\")")

;; ========== 类型转换 ==========
(run-test "转整数：3.14 → 3"
          "打印,(转整数,3.14)")

(run-test "转整数：\"42\" → 42"
          "打印,(转整数,\"42\")")

(run-test "转浮点数：3 → 3.0"
          "打印,(转浮点数,3)")

(run-test "转浮点数：\"3.14\" → 3.14"
          "打印,(转浮点数,\"3.14\")")

;; ========== 工具函数 ==========
(run-test "表示：字符串的表示"
          "打印,(表示,\"hello\")")

(run-test "哈希：42的哈希值"
          "打印,(哈希,42)")

(run-test "是可调用：函数 → #t"
          "定义f就是函x：
    返回x
打印,(是可调用,f)")

(run-test "是可调用：数字 → #f"
          "打印,(是可调用,42)")

(run-test "商余：7除以3 → (2,1)"
          "打印,(商余,7,3)")

(run-test "集合：从重复元素创建集合"
          "打印,(集合,1,2,2,3,3,3)")

(run-test "切片：0到10步长为3"
          "打印,(切片,0,10,3)")

;; ========== 新增内置函数 ==========
(printf "\n--- 新增内置函数测试 ---\n")

(run-test "ascii表示：数字的表示"
          "打印,(ascii表示,42)")

(run-test "ascii表示：字符串的表示"
          "打印,(ascii表示,\"hello\")")

(run-test "格式化：整数转二进制"
          "打印,(格式化,42,\"b\")")

(run-test "格式化：整数转十六进制"
          "打印,(格式化,255,\"x\")")

(run-test "元组：创建元组"
          "打印,(元组,1,2,3)")

(run-test "复数：创建复数"
          "打印,(复数,3,4)")

(run-test "冻结集合：去重"
          "打印,(冻结集合,1,2,2,3,3,3)")

(printf "\n══════════════════════════════════\n")
(printf "  Python 3.12 风格基础库测试完成\n")
(printf "══════════════════════════════════\n")