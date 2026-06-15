#lang racket/base

;; 明道语言 `--explain` 错误解释系统
;; 提供对每种错误类型的中文详细解释和示例

(require racket/string)

(provide error-explanations
         explain-error-code
         all-error-codes)

;; ============================================================
;; 预定义错误解释表
;; ============================================================

(define error-explanations
  (hash
   "E0001"
   (hasheq
    'title "语法错误"
    'description "这是语法错误，表示代码的结构不符合明道语言的语法规则。常见原因包括括号不匹配、引号未闭合、缩进错误，以及关键字拼写错误。明道语言使用关键字（如'定义'、'如果'）而不是英语单词。"
    'bad-example "定义 x 就是 (加 1 2"
    'good-example "定义 x 就是 (加 1 2)"
    'hint "确保所有括号和引号匹配，且使用正确的中文关键字")

   "E0002"
   (hasheq
    'title "类型不匹配"
    'description "这是类型不匹配错误，表示变量的类型与期望的类型不一致。明道是静态类型语言，变量的类型在定义时确定，之后不能改变。例如将字符串赋值给整型变量会触发此错误。"
    'bad-example "定义 x 就是 \"hello\"\n定义 y：整数 就是 x"
    'good-example "定义 x 就是 42\n定义 y：整数 就是 x"
    'hint "使用类型转换函数可以转换类型，如'转整数(x)'或'转字符串(x)'")

   "E0003"
   (hasheq
    'title "未定义错误"
    'description "这是未定义错误，表示引用了一个未声明的变量或函数。在明道中，所有变量和函数必须在使用前声明（通过'定义'语句）。"
    'bad-example "打印, x   ; x 没有定义过"
    'good-example "定义 x 就是 42\n打印, x"
    'hint "检查变量名是否拼写正确，以及变量是否在正确的作用域内。如果是函数，请确保已导入对应的模块")

   "E0004"
   (hasheq
    'title "参数错误"
    'description "这是参数错误，表示函数调用时传入的参数数量与函数定义不匹配。每个函数接受固定数量的参数，传入过多或过少的参数都会触发此错误。"
    'bad-example "打印, 1, 2, 3   ; 打印只接受 1 个参数"
    'good-example "打印, 1\n打印, 2\n打印, 3"
    'hint "查看函数定义，确认需要几个参数。可在函数名上悬停（在 IDE 中）查看签名")

   "E0005"
   (hasheq
    'title "运行时错误"
    'description "这是运行时错误，表示程序执行过程中发生了不可预期的状态。常见情况包括除零、列表索引越界、字典键不存在、文件路径错误等。"
    'bad-example "定义 result 就是 10 除 0"
    'good-example "定义 result 就是 10 除 2"
    'hint "检查除数是否可能为零，或列表索引是否超出范围。使用条件判断可以避免错误情况")

   "E0006"
   (hasheq
    'title "重复定义错误"
    'description "这是重复定义错误，表示定义了一个已存在的变量。在同一个作用域内，一个变量名只能定义一次。如果需要修改值，应使用'赋值'语句而不是'定义'语句。"
    'bad-example "定义 x 就是 1\n定义 x 就是 2"
    'good-example "定义 x 就是 1\n赋值 x 为 2"
    'hint "如果需要修改值，请使用'赋值'语句而不是'定义'语句")

   "E0007"
   (hasheq
    'title "断言错误"
    'description "这是断言错误，表示程序中声明的条件不满足。断言（'断言'语句）用于调试，确保程序在某个点的状态符合预期。如果条件为假，就会触发此错误。"
    'bad-example "断言 (大于 0 -1)   ; -1 大于 0 为假"
    'good-example "断言 (大于 0 1)"
    'hint "断言失败表示代码中有 bug。请检查条件表达式是否合理")

   "E0008"
   (hasheq
    'title "访问权限错误"
    'description "这是访问权限错误，表示尝试访问一个私有符号。使用'公开'定义的符号可以跨模块访问，使用'私有'定义的符号只能在同一模块内访问。"
    'bad-example "私有 定义 helper 就是 0\n; 其他模块不能访问 helper"
    'good-example "公开 定义 public-fn 就是 0\n; 其他模块可以访问 public-fn"
    'hint "如果需要跨模块访问，请将符号改为'公开'修饰，或在同一模块内使用")))

;; ============================================================
;; explain 主函数
;; ============================================================

(define (explain-error-code code)
  (define info (hash-ref error-explanations code #f))
  (if info
      (string-join
       (list
        (format "~a (~a)" (hash-ref info 'title) code)
        ""
        (hash-ref info 'description)
        ""
        "错误示例："
        "--------"
        (hash-ref info 'bad-example)
        "--------"
        ""
        "正确示例："
        "--------"
        (hash-ref info 'good-example)
        "--------"
        ""
        (format "提示：~a" (hash-ref info 'hint))
        "")
       "\n")
      (format "未知错误代码：~a。请检查代码是否正确。" code)))

;; 获取所有支持的错误代码
(define (all-error-codes)
  (sort (hash-keys error-explanations) string<?))
