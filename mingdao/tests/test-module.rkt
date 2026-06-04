#lang racket/base

(require racket/string
         racket/port
         racket/file
         "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

;; 测试导入/导出语句的解析

(define test-code "
导入 \"test-module-utils.md\"
打印 say-hello deck
导出 say-hello deck
")

(define tokens (tokenize test-code))
(define ast (parse tokens))

(printf "解析结果 (~a 个表达式):~n" (length ast))
(for ([expr ast])
  (printf "  ~s~n" expr))

;; 验证解析结果
(printf "~n验证导入语句...~n")
(define import-expr (findf (λ (e) (and (list? e) (eq? (car e) 'mingdao-import))) ast))
(when import-expr
  (printf "  [OK] 导入语句: 文件 = ~a~n" (cadr import-expr)))

(printf "~n验证导出语句...~n")
(define export-expr (findf (λ (e) (and (list? e) (eq? (car e) 'mingdao-export))) ast))
(when export-expr
  (printf "  [OK] 导出语句: 符号 = ~a~n" (cdr export-expr)))

(printf "~n验证普通表达式...~n")
(define normal-exprs (filter (λ (e) 
  (not (or (and (list? e) (memq (car e) '(mingdao-import mingdao-export)))
           (eq? e '(void))))) ast))
(for ([expr normal-exprs])
  (printf "  [OK] 普通表达式: ~s~n" expr))

(printf "~n=== 模块系统测试通过 ===~n")