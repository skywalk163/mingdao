#lang racket/base

(require racket/hash
         racket/string
         (prefix-in parser: "../../lang/parser.rkt"))

(provide make-completion
         completion-get)

;; 代码补全状态
(struct completion ())

;; 创建补全器
(define (make-completion)
  (completion))

;; 获取补全项
(define (completion-get state uri line char)
  (hash 'isIncomplete #f
         'items (get-completion-items)))

;; 获取补全项列表
(define (get-completion-items)
  (append (get-keyword-completions)
          (get-function-completions)
          (get-type-completions)))

;; 关键字补全
(define (get-keyword-completions)
  (list
   (make-completion-item "定义" "关键字：定义变量" 14)
   (make-completion-item "赋值" "关键字：变量赋值" 14)
   (make-completion-item "如果" "关键字：条件判断" 14)
   (make-completion-item "那么" "关键字：条件分支" 14)
   (make-completion-item "否则" "关键字：条件分支" 14)
   (make-completion-item "对于" "关键字：循环" 14)
   (make-completion-item "返回" "关键字：返回值" 14)
   (make-completion-item "跳出" "关键字：跳出循环" 14)
   (make-completion-item "继续" "关键字：继续循环" 14)
   (make-completion-item "打印" "关键字：打印输出" 14)
   (make-completion-item "导入" "关键字：导入模块" 14)
   (make-completion-item "类" "关键字：类定义" 14)
   (make-completion-item "接口" "关键字：接口定义" 14)
   (make-completion-item "定义类型" "关键字：类型别名" 14)
   (make-completion-item "列表" "关键字：创建列表" 14)
   (make-completion-item "字典" "关键字：创建字典" 14)))

;; 函数补全
(define (get-function-completions)
  (list
   (make-completion-item "加" "函数：加法运算" 3)
   (make-completion-item "减" "函数：减法运算" 3)
   (make-completion-item "乘" "函数：乘法运算" 3)
   (make-completion-item "除" "函数：除法运算" 3)
   (make-completion-item "模" "函数：取模运算" 3)
   (make-completion-item "等于" "函数：等于比较" 3)
   (make-completion-item "大于" "函数：大于比较" 3)
   (make-completion-item "小于" "函数：小于比较" 3)
   (make-completion-item "索引" "函数：列表索引" 3)
   (make-completion-item "长度" "函数：获取长度" 3)
   (make-completion-item "是整数" "函数：整数检查" 3)
   (make-completion-item "是字符串" "函数：字符串检查" 3)))

;; 类型补全
(define (get-type-completions)
  (list
   (make-completion-item "整数" "类型：整数" 7)
   (make-completion-item "浮点数" "类型：浮点数" 7)
   (make-completion-item "字符串" "类型：字符串" 7)
   (make-completion-item "布尔" "类型：布尔值" 7)
   (make-completion-item "空值" "类型：空值" 7)
   (make-completion-item "任意" "类型：任意类型" 7)
   (make-completion-item "列表" "类型：列表" 7)
   (make-completion-item "字典" "类型：字典" 7)))

;; 创建补全项
(define (make-completion-item label doc kind)
  (hash 'label label
        'kind kind
        'documentation doc
        'insertText label))