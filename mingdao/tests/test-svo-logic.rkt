#lang racket

;; 测试主谓宾语序逻辑

(require "../lang/tokenizer.rkt")

;; 模拟 build-svo-call 的逻辑
(define (build-svo-call-test items)
  (displayln (format "\nbuild-svo-call 输入: ~a" items))
  
  (cond
    [(< (length items) 2) 
     (car items)]
    
    [else
     ;; 从右向左找到连续的标识符（函数名）
     (let loop ([remaining (reverse items)]
                [funcs '()])
       (displayln (format "  remaining: ~a, funcs: ~a" remaining funcs))
       (cond
         [(null? remaining)
          ;; 所有都是函数名
          (if (= (length funcs) 1)
              (error 'parse "主谓宾语序缺少参数")
              (let ([all-funcs (reverse funcs)])
                (displayln (format "  all-funcs: ~a" all-funcs))
                (displayln (format "  last: ~a, drop-right: ~a" (last all-funcs) (drop-right all-funcs 1)))
                `(,(last all-funcs) ,@(drop-right all-funcs 1))))]
         
         ;; 检查是否为标识符（字符串）
         [(string? (car remaining))
          (loop (cdr remaining) (cons (car remaining) funcs))]
         
         ;; 不是标识符，停止扫描
         [else
          (let* ([args (reverse remaining)]
                 [all-funcs (reverse funcs)])
            (foldr (lambda (func result)
                     `(,func ,result))
                   `(,(last all-funcs) ,@args)
                   (drop-right all-funcs 1)))]))]))

;; 测试用例
(displayln "=== 测试1：x, 打印 ===")
(define result1 (build-svo-call-test '("x" "打印")))
(displayln (format "结果: ~a" result1))

(displayln "\n=== 测试2：2, 3, 求和, 打印 ===")
(define result2 (build-svo-call-test '(2 3 "求和" "打印")))
(displayln (format "结果: ~a" result2))
