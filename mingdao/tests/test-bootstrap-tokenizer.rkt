#lang racket/base

;; 明道自举 Phase 1：验证明道版分词器与Racket版一致性

(require racket/port racket/file
         "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

;; ========== 自动检测项目根目录 ==========
(define project-root
  (cond
    [(file-exists? (build-path (current-directory) "mingdao" "std" "tokenizer.mingdao"))
     (build-path (current-directory) "mingdao")]
    [(file-exists? (build-path (current-directory) "std" "tokenizer.mingdao"))
     (current-directory)]
    [(file-exists? (build-path (current-directory) ".." "std" "tokenizer.mingdao"))
     (build-path (current-directory) "..")]
    [else
     (error "test-bootstrap-tokenizer.rkt: cannot determine project root.")]))

;; 读取明道版分词器源码
(define tokenizer-source
  (let* ([in (open-input-file (build-path project-root "std/tokenizer.mingdao"))]
         [b (port->bytes in)])
    (close-input-port in)
    (bytes->string/utf-8 b)))

;; 设置命名空间并加载明道版分词器
(define ns
  (let ([ns (make-base-namespace)])
    (parameterize ([current-namespace ns])
      (define main-path
        (build-path project-root "main.rkt"))
      (eval `(require (file ,(path->string main-path))))
      ;; 加载并评估明道版分词器
      (define tokens (tokenize tokenizer-source))
      (define ast (parse tokens))
      (for ([expr ast])
        (eval expr ns))
      (void))
    ns))

;; Racket版分词
(define (racket-tokenize code)
  (tokenize code))

;; 明道版分词
(define (mingdao-tokenize code)
  (parameterize ([current-namespace ns])
    (eval `(分词 ,code) ns)))

;; 辅助：将token列表转为可比较的简化表示
(define (simplify-tokens tokens)
  (map (lambda (tok)
         (list (symbol->string (token-type tok))
               (token-value tok)
               (token-line tok)))
       tokens))

;; 辅助：将明道版token列表（list形式）转为可比较的简化表示
(define (simplify-mingdao-tokens tokens)
  (define (simplify-one t)
    (define val (list-ref t 2))
    (list (list-ref t 1)  ;; type (string)
          (if (null? val) #f val)  ;; normalize '() to #f
          (list-ref t 3))) ;; line
  (map simplify-one tokens))

;; 测试辅助函数
(define (test-tokenizer name code)
  (printf "▶ ~a\n" name)
  (printf "  代码: ~a\n" code)
  (define rt-tokens
    (with-handlers ([exn:fail? (λ (e) 
                                 (printf "  ✗ Racket版失败: ~a\n\n" (exn-message e))
                                 #f)])
      (racket-tokenize code)))
  (define md-tokens
    (with-handlers ([exn:fail? (λ (e)
                                 (printf "  ✗ 明道版失败: ~a\n\n" (exn-message e))
                                 #f)])
      (mingdao-tokenize code)))
  (when (and rt-tokens md-tokens)
    (define rt-simple (simplify-tokens rt-tokens))
    (define md-simple (simplify-mingdao-tokens md-tokens))
    (printf "  Racket: ~a\n" rt-simple)
    (printf "  明道:   ~a\n" md-simple)
    (if (equal? rt-simple md-simple)
        (printf "  ✓ 一致\n\n")
        (printf "  ✗ 不一致！\n\n"))))

(printf "══════════════════════════════════\n")
(printf "  明道自举 Phase 1：分词器测试\n")
(printf "══════════════════════════════════\n\n")

;; ========== 基础测试 ==========
(test-tokenizer "关键字：定义"
  "定义")

(test-tokenizer "关键字：如果"
  "如果")

(test-tokenizer "标识符：汉诺塔"
  "汉诺塔")

(test-tokenizer "数字：42"
  "42")

(test-tokenizer "字符串：hello"
  "\"hello\"")

;; ========== 复合标识符 ==========
(test-tokenizer "复合标识符：字符串索引"
  "字符串索引")

(test-tokenizer "复合标识符：列表转字符串"
  "列表转字符串")

(test-tokenizer "复合标识符：字符串长度"
  "字符串长度")

;; ========== 无空格关键字 ==========
(test-tokenizer "无空格：定义汉诺塔"
  "定义汉诺塔")

(test-tokenizer "无空格：汉诺塔就是函n"
  "汉诺塔就是函n")

(test-tokenizer "无空格：如果n等于0"
  "如果n等于0")

;; ========== 运算符 ==========
(test-tokenizer "运算符：加"
  "加")

(test-tokenizer "运算符：与"
  "与")

(test-tokenizer "运算符：大于等于"
  "大于等于")

;; ========== 标点符号 ==========
(test-tokenizer "冒号和逗号"
  "：,")

(test-tokenizer "括号"
  "()")

;; ========== 简单代码段 ==========
(test-tokenizer "简单定义"
  "定义汉诺塔就是函n")

(test-tokenizer "条件语句"
  "如果n等于0那么：")

(test-tokenizer "带缩进的代码"
  "定义汉诺塔就是函n,源,目标,辅助：
  如果n等于0那么：
    返回")

(printf "\n══════════════════════════════════\n")
(printf "  测试完成\n")
(printf "══════════════════════════════════\n")