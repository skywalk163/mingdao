#lang racket/base

(require drracket/tool
         racket/class
         racket/gui/base
         racket/string
         racket/list
         racket/match
         syntax-color/color-text)

(provide tool@)

;; 明道语言关键字列表（按颜色分类）
;; 蓝色 - 控制结构和定义关键字
(define control-keywords
  '("定义" "就是" "就是函" "就是宏"
    "如果" "那么" "否则" "否则若"
    "对于" "从" "到" "每个从"
    "返回" "跳出" "继续" "当满足"
    "导入" "导出"))

;; 紫色 - 运算符
(define operator-keywords
  '("加" "减" "乘" "除" "模" "幂"
    "非" "与" "或"
    "拼接" "然后"
    "大于" "小于" "等于" "不等"
    "大于等于" "小于等于"))

;; 青色 - 内置函数和数据操作
(define builtin-keywords
  '("列表" "字典" "索引" "长度" "打印"
    "生成" "捕获" "任意" "模块"
    "真值" "假值" "空值"
    "赋值" "为"))

;; 构建正则表达式（无词边界，中文不需要 \b）
(define (make-alternation-regex words)
  (pregexp (string-append "(" (string-join words "|") ")")))

(define pattern-key (list 'mingdao-syntax))

(define tool@
  (unit
    (import drracket:tool:tool^)
    (export drracket:tool:tool^)

    (define (phase1)
      (define ct (send/dc get-color-text))

      ;; 控制结构关键字 - 蓝色
      (send ct add-pattern
            (make-alternation-regex control-keywords)
            pattern-key
            (make-object color% "MediumBlue"))

      ;; 运算符 - 紫色
      (send ct add-pattern
            (make-alternation-regex operator-keywords)
            pattern-key
            (make-object color% "DarkOrchid"))

      ;; 内置函数 - 青色
      (send ct add-pattern
            (make-alternation-regex builtin-keywords)
            pattern-key
            (make-object color% "Teal"))

      ;; 数字 - 深绿色
      (send ct add-pattern
            (pregexp "[0-9]+(\\.[0-9]+)?")
            pattern-key
            (make-object color% "DarkGreen"))

      ;; 字符串 - 深红色
      (send ct add-pattern
            (pregexp "\"[^\"]*\"")
            pattern-key
            (make-object color% "FireBrick"))

      ;; 单行注释 - 灰色
      (send ct add-pattern
            (pregexp "//[^\n]*")
            pattern-key
            (make-object color% "Gray"))

      ;; 标识符 - 默认黑色（由 DrRacket 处理）
      )

    (define (phase2)
      (void))))