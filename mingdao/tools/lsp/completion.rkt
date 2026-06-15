#lang racket/base

(require racket/hash
         racket/string
         racket/match
         (prefix-in parser: "../../lang/parser.rkt")
         "../../lang/semantic.rkt")

(provide make-completion
         completion-get)

;; 代码补全状态
(struct completion ())

;; 创建补全器
(define (make-completion)
  (completion))

;; 获取补全项 — 支持基于上下文的过滤
(define (completion-get state uri line char text)
  (define prefix (extract-prefix text line char))
  (define items (get-context-aware-completions prefix))
  (hash 'isIncomplete #f
         'items (filter-matching-items items prefix)))

;; 提取光标前的上下文前缀
(define (extract-prefix text line char)
  (define lines (string-split text "\n" #:trim? #f))
  (when (< line (length lines))
    (define current-line (list-ref lines line))
    (define start-pos
      (let loop ([pos (sub1 char)])
        (cond
          [(< pos 0) (add1 pos)]
          [(char-whitespace? (string-ref current-line pos)) (add1 pos)]
          [(char=? (string-ref current-line pos) #\，) (add1 pos)]
          [else (loop (sub1 pos))])))
    (substring current-line start-pos char)))

;; 上下文感知的补全日
(define (get-context-aware-completions prefix)
  (define is-at-statement-start?
    (or (string=? prefix "")
        (string-suffix? prefix "\n")
        (string-suffix? prefix "：")
        (string-suffix? prefix ":")))
  
  (define is-in-expression?
    (or (string-contains? prefix "打印")
        (string-contains? prefix "就是")
        (string-contains? prefix "返回")
        (string-contains? prefix "赋值")))
  
  (define items
    (append
     (get-keyword-completions is-at-statement-start?)
     (get-function-completions)
     (get-type-completions is-in-expression?)))
  items)

;; 关键字补全
(define (get-keyword-completions is-stmt-start?)
  (if is-stmt-start?
      ;; 语句开始处：只提供语句级关键字
      (list
       (make-completion-item "定义" "关键字：定义变量" 14)
       (make-completion-item "定义类型" "关键字：类型别名" 14)
       (make-completion-item "赋值" "关键字：变量赋值" 14)
       (make-completion-item "如果" "关键字：条件判断" 14)
       (make-completion-item "对于" "关键字：循环" 14)
       (make-completion-item "返回" "关键字：从函数返回值" 14)
       (make-completion-item "跳出" "关键字：跳出循环" 14)
       (make-completion-item "继续" "关键字：继续循环" 14)
       (make-completion-item "导入" "关键字：导入模块" 14)
       (make-completion-item "类" "关键字：定义类" 14)
       (make-completion-item "接口" "关键字：定义接口" 14)
       (make-completion-item "引用" "关键字：引用变量" 14)
       (make-completion-item "执行" "关键字：执行代码块" 14)
       (make-completion-item "尝试" "关键字：异常捕获" 14))
      ;; 表达式内部：提供所有常用关键字
      (list
       (make-completion-item "打印" "函数：输出到控制台" 3)
       (make-completion-item "列表" "关键字：创建列表" 14)
       (make-completion-item "字典" "关键字：创建字典" 14))))

;; 函数补全
(define (get-function-completions)
  (list
   (make-completion-item "加" "函数：加法运算" 3)
   (make-completion-item "减" "函数：减法运算" 3)
   (make-completion-item "乘" "函数：乘法运算" 3)
   (make-completion-item "除" "函数：除法运算" 3)
   (make-completion-item "模" "函数：取模运算" 3)
   (make-completion-item "幂" "函数：幂运算" 3)
   (make-completion-item "等于" "函数：等于比较" 3)
   (make-completion-item "不等" "函数：不等比较" 3)
   (make-completion-item "大于" "函数：大于比较" 3)
   (make-completion-item "小于" "函数：小于比较" 3)
   (make-completion-item "大于等于" "函数：大于等于比较" 3)
   (make-completion-item "小于等于" "函数：小于等于比较" 3)
   (make-completion-item "索引" "函数：列表/字典索引" 3)
   (make-completion-item "长度" "函数：获取列表/字符串长度" 3)
   (make-completion-item "正弦" "函数：正弦运算" 3)
   (make-completion-item "余弦" "函数：余弦运算" 3)
   (make-completion-item "阶乘" "函数：阶乘运算" 3)
   (make-completion-item "绝对值" "函数：绝对值" 3)
   (make-completion-item "最大值" "函数：最大值" 3)
   (make-completion-item "最小值" "函数：最小值" 3)
   (make-completion-item "随机整数" "函数：生成随机整数" 3)
   (make-completion-item "是整数" "函数：判断是否为整数" 3)
   (make-completion-item "是浮点数" "函数：判断是否为浮点数" 3)
   (make-completion-item "是字符串" "函数：判断是否为字符串" 3)
   (make-completion-item "是数" "函数：判断是否为数字" 3)
   (make-completion-item "是空" "函数：判断是否为空" 3)
   (make-completion-item "获取类型" "函数：获取值的类型名" 3)))

;; 类型补全 — 仅在需要类型标注的上下文中提供
(define (get-type-completions in-type-context?)
  (if in-type-context?
      (list
       (make-completion-item "整数" "类型：整数" 7)
       (make-completion-item "浮点数" "类型：浮点数" 7)
       (make-completion-item "字符串" "类型：字符串" 7)
       (make-completion-item "布尔" "类型：布尔值" 7)
       (make-completion-item "空值" "类型：空值" 7)
       (make-completion-item "任意" "类型：任意类型" 7)
       (make-completion-item "列表" "类型：列表" 7)
       (make-completion-item "字典" "类型：字典" 7)
       (make-completion-item "函数" "类型：可调用函数" 7))
      '()))

;; 根据前缀过滤匹配项
(define (filter-matching-items items prefix)
  (if (string=? prefix "")
      items
      (filter (λ (item)
                (string-prefix? (hash-ref item 'label) prefix))
              items)))

;; 创建补全项
(define (make-completion-item label doc kind)
  (hash 'label label
        'kind kind
        'documentation doc
        'insertText label))

;; ============================================================
;; 语义分析上下文补全
;; ============================================================

;; 从 semantic.rkt 的 scope 构建上下文感知补全
(define (build-context-completions scope builtin-names)
  (define symbols (hash-keys (scope-symbols scope)))
  (for/list ([name symbols] #:unless (member name builtin-names string=?))
    (hash 'label name
          'kind 6
          'detail "变量")))