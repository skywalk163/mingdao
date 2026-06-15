#lang racket/base

(require racket/match
         racket/list
         racket/string
         "../../lang/tokenizer.rkt"
         "../../lang/parser.rkt"
         "../../lang/semantic.rkt")

(provide analyze-document
         analysis-result
         analysis-result?
         analysis-result-ast
         analysis-result-errors
         analysis-result-global-scope
         analysis-result-source-lines
         find-symbol-at-pos
         get-hover-info
         get-completions
         get-document-symbols
         get-diagnostics
         find-references-in-ast)

;; ============================================================
;; 数据结构
;; ============================================================

(struct analysis-result (ast errors global-scope source-lines) #:transparent)

;; ============================================================
;; 主入口
;; ============================================================

(define (analyze-document text builtin-names)
  (define lines (string-split text "\n" #:trim? #f))
  (define tokens (tokenize text))
  (define ast (parse tokens))
  (define errors (analyze ast builtin-names))
  (define global-scope (make-global-scope builtin-names))
  (analysis-result ast errors global-scope lines))

;; ============================================================
;; 符号位置查询
;; ============================================================

;; 在指定行/列位置查找符号名
(define (find-symbol-at-pos line char lines)
  (define len (length lines))
  (when (and (>= line 0) (< line len))
    (define current-line (list-ref lines line))
    (define line-len (string-length current-line))
    (when (and (>= char 0) (< char line-len))
      ;; 向左扩展找到符号起始
      (define start
        (let loop ([pos char])
          (if (or (<= pos 0)
                  (char-whitespace? (string-ref current-line (sub1 pos)))
                  (char=? (string-ref current-line (sub1 pos)) #\，)
                  (char=? (string-ref current-line (sub1 pos)) #\())
              pos
              (loop (sub1 pos)))))
      ;; 向右扩展找到符号结束
      (define end
        (let loop ([pos char])
          (if (or (>= pos line-len)
                  (char-whitespace? (string-ref current-line pos))
                  (char=? (string-ref current-line pos) #\，)
                  (char=? (string-ref current-line pos) #\)))
              pos
              (loop (add1 pos)))))
      (when (< start end)
        (substring current-line start end)))))

;; ============================================================
;; 悬停信息
;; ============================================================

(define (get-hover-info word global-scope)
  (when word
    (define found (lookup-symbol word global-scope))
    (define type-str
      (if found
          (format "\n\n**类型**: `~a`" (type->string (symbol-info-type (car found))))
          ""))
    (define doc (get-hover-doc word))
    (hash 'contents
          (hash 'kind "markdown"
                'value (format "**`~a`**~a\n\n---\n~a" word type-str doc)))))

(define (get-hover-doc word)
  (cond
    [(member word '("定义" "常量") char=?) "定义变量或常量\n\n`定义 变量名 就是 值`"]
    [(member word '("如果" "那么" "否则") char=?)
     "条件分支语句\n\n`如果 条件 那么：\n    ...\n否则：\n    ...`"]
    [(member word '("对于") char=?) "循环语句\n\n`对于 i 从 0 到 10：\n    ...`"]
    [(member word '("返回") char=?) "从函数返回值\n\n`返回 表达式`"]
    [(member word '("函数" "就是函") char=?) "定义匿名函数\n\n`就是函 参数1, 参数2：\n    ...`"]
    [(member word '("打印") char=?) "输出到控制台"]
    [(member word '("导入") char=?) "导入模块"]
    [(member word '("列表") char=?) "创建列表\n\n`列表 1, 2, 3`"]
    [(member word '("字典") char=?) "创建字典"]
    [(member word '("赋值") char=?) "对变量重新赋值\n\n`赋值 变量名 = 新值`"]
    [(member word '("常量" "真值" "假值" "空值") char=?) "内置常量"]
    [(member word '("加" "减" "乘" "除") char=?) (format "算术运算\n\n`~a` 运算符" word)]
    [(member word '("大于" "小于" "等于" "不等") char=?) (format "比较运算\n\n`~a` 运算符" word)]
    [else (format "符号: ~a" word)]))

;; ============================================================
;; 补全
;; ============================================================

(define (get-completions result builtin-names)
  (define scope (analysis-result-global-scope result))
  (define symbols (hash-keys (scope-symbols scope)))
  
  (define symbol-items
    (for/list ([name (remove-duplicates (append builtin-names symbols) string=?)])
      (define info (hash-ref (scope-symbols scope) name #f))
      (define kind
        (if info
            (match (symbol-info-kind info)
              ['变量 6]
              ['函数 3]
              ['参数 6]
              ['内置函数 3]
              [_ 13])
            3))
      (define detail
        (if (and info (symbol-info-type info))
            (type->string (symbol-info-type info))
            "任意"))
      (hash 'label name 'kind kind 'detail detail)))
  
  (define keywords
    '("定义" "常量" "如果" "对于" "返回" "打印" "导入" "赋值"
      "列表" "字典" "匹配" "尝试" "捕获" "始终" "新建" "真值"
      "假值" "空值" "类" "接口" "扩展" "公开" "私有" "异步" "等待"))
  (define keyword-items
    (for/list ([kw keywords])
      (hash 'label kw 'kind 14 'detail "关键字")))
  
  (hash 'isIncomplete #f
        'items (append symbol-items keyword-items)))

;; ============================================================
;; 文档符号
;; ============================================================

(define (get-document-symbols result)
  (define scope (analysis-result-global-scope result))
  (for/list ([(name info) (in-hash (scope-symbols scope))]
             #:unless (eq? (symbol-info-kind info) '内置函数))
    (define line (symbol-info-line info))
    (define col (symbol-info-col info))
    (define sym-kind
      (match (symbol-info-kind info)
        ['函数 12]
        ['变量 13]
        ['参数 13]
        [_ 13]))
    (hash 'name name
          'kind sym-kind
          'range (hash 'start (hash 'line line 'character col)
                       'end (hash 'line line 'character (+ col (string-length name)))))))

;; ============================================================
;; 诊断
;; ============================================================

(define (get-diagnostics result)
  (for/list ([err (analysis-result-errors result)])
    (define line (semantic-error-line err))
    (define col (semantic-error-col err))
    (hash 'range
          (hash 'start (hash 'line line 'character col)
                'end (hash 'line line 'character (max 1 (+ col 1))))
          'severity (match (semantic-error-type err)
                      ['redefined 1]
                      ['constant-assign 1]
                      [_ 2])
          'source "明道语义分析"
          'message (semantic-error-message err))))

;; ============================================================
;; 查找引用
;; ============================================================

(define (find-references-in-ast word ast)
  (define locations '())
  (define (walk expr)
    (match expr
      [(? symbol? s)
       (when (equal? (symbol->string s) word)
         (set! locations (cons (list 0 0) locations)))]
      [(? pair?)
       (walk (car expr))
       (for ([e (cdr expr)])
         (walk e))]
      [_ (void)]))
  (for ([e ast])
    (walk e))
  (reverse locations))