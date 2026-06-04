#lang racket

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

(displayln "========================================")
(displayln "明道语言分词和解析验证")
(displayln "========================================")

;; 辅助函数
(define (test code expected-desc)
  (displayln (format "\n【测试】~a" expected-desc))
  (displayln (format "输入: ~a" code))
  (displayln "分词:")
  (define tokens (tokenize code))
  (for ([tok tokens])
    (displayln (format "  ~a" tok)))
  (displayln "解析:")
  (define ast
    (with-handlers ([exn:fail? (λ (e)
                                  (displayln (format "  (解析错误) ~a" (exn-message e)))
                                  '解析错误)])
      (parse tokens)))
  (unless (eq? ast '解析错误)
    (pretty-print ast)))

;; ===== 核心测试 =====

(test "x等于y"
      "无空格比较运算符")

(test "a加b乘c"
      "运算符优先级（乘法优先）")

(test "分数大于等于90"
      "四字关键字")

(test "定义x就是5"
      "无空格变量定义")

(test "如果x大于0那么：打印x"
      "无空格条件语句")

(test "对于i从0到5：打印i"
      "无空格循环语句")

;; ===== 边界情况 =====

(test "定义定义x"
      "连续关键字")

(test "跳出循环"
      "关键字后跟标识符")

(test "列表长度"
      "两个关键字相邻（空格分隔）")

;; ===== 管道调用 =====

(test "数据|长度|打印"
      "无空格管道调用")

(test "列表1,2,3然后长度然后打印"
      "无空格管道+关键字")

;; ===== 实际游戏场景 =====

(test "如果按键按下\"左\"那么：x减等于5"
      "游戏条件语句")

(test "定义速度就是x乘y加z"
      "复杂表达式")

(test "对于i从0到长度数据减1"
      "循环+表达式")

(displayln "\n========================================")
(displayln "所有验证完成！")
(displayln "========================================")
