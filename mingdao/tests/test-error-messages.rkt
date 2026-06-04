#lang racket

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

(displayln "=== 错误提示测试 ===")

;; 测试1：期望错误
(displayln "\n【测试1】期望错误：缺少'就是'")
(displayln "代码：定义 x 5")
(with-handlers ([exn:fail? (lambda (e) 
                             (displayln (exn-message e)))])
  (parse (tokenize "定义 x 5")))

;; 测试2：期望错误：缺少冒号
(displayln "\n【测试2】期望错误：缺少冒号")
(displayln "代码：如果x大于0那么打印x")
(with-handlers ([exn:fail? (lambda (e) 
                             (displayln (exn-message e)))])
  (parse (tokenize "如果x大于0那么打印x")))

;; 测试3：未知字符
(displayln "\n【测试3】未知字符错误")
(displayln "代码：定义 x @ 5")
(with-handlers ([exn:fail? (lambda (e) 
                             (displayln (exn-message e)))])
  (parse (tokenize "定义 x @ 5")))

;; 测试4：正确的代码
(displayln "\n【测试4】正确的代码（验证修复后仍能正常工作）")
(displayln "代码：定义x就是5")
(with-handlers ([exn:fail? (lambda (e) 
                             (displayln (format "错误: ~a" (exn-message e))))])
  (displayln "解析结果：")
  (pretty-print (parse (tokenize "定义x就是5"))))

(displayln "\n【测试5】正确的条件语句")
(displayln "代码：如果x大于0那么：打印x")
(with-handlers ([exn:fail? (lambda (e) 
                             (displayln (format "错误: ~a" (exn-message e))))])
  (displayln "解析结果：")
  (pretty-print (parse (tokenize "如果x大于0那么：打印x"))))
