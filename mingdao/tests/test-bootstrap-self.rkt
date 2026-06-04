#lang racket/base

(require racket/port racket/file racket/string racket/list racket/match)

;; ========== 自动检测项目根目录 ==========
;; 支持从 mingdao/tests/ 或仓库根目录运行
(define project-root
  (cond
    [(file-exists? (build-path (current-directory) "mingdao" "core.rkt"))
     ;; Running from repo root: G:\dumategithub\langbyracket
     (build-path (current-directory) "mingdao")]
    [(file-exists? (build-path (current-directory) ".." "core.rkt"))
     ;; Running from mingdao/tests/
     (build-path (current-directory) "..")]
    [(file-exists? (build-path (current-directory) "core.rkt"))
     ;; Running from mingdao/
     (current-directory)]
    [else
     (error "test-bootstrap-self.rkt: cannot determine project root.
  Please run from repo root, mingdao/, or mingdao/tests/ directory.")]))

;; 加载 Racket 版参考实现（路径相对于本文件位置）
(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

;; ========== UTF-8 文件读取 ==========
(define (read-utf8-file path)
  (define in (open-input-file path))
  (define chunks '())
  (let loop ()
    (define b (read-bytes 4096 in))
    (if (eof-object? b) (void)
        (begin (set! chunks (cons b chunks)) (loop))))
  (close-input-port in)
  (bytes->string/utf-8 (apply bytes-append (reverse chunks))))

;; ========== 创建 Mingdao 运行时命名空间 ==========
(define (make-mingdao-namespace)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (define core-path (build-path project-root "core.rkt"))
    (eval `(require (file ,(path->string core-path)))))
  ns)

;; ========== 加载明道版源码到命名空间 ==========
(define (load-mingdao-source ns source)
  (define tokens (tokenize source))
  (define ast (parse tokens))
  (define errors '())
  (parameterize ([current-namespace ns])
    (for ([expr ast] [i (in-naturals)])
      (with-handlers ([exn:fail? (λ (e)
                                   (set! errors (cons (format "#~a: ~a" i (exn-message e)) errors)))])
        (eval expr))))
  (reverse errors))

;; ========== 读取 Mingdao 版源码 ==========
(define tokenizer-source
  (read-utf8-file (build-path project-root "std/tokenizer.mingdao")))

(define parser-source
  (read-utf8-file (build-path project-root "std/parser.mingdao")))

;; ========== 初始化命名空间 ==========
(printf "初始化 Mingdao 运行时命名空间...\n")
(define mingdao-ns (make-mingdao-namespace))
(printf "  核心库加载完成\n")

(printf "加载明道版分词器...\n")
(define tokenizer-errors (load-mingdao-source mingdao-ns tokenizer-source))
(if (null? tokenizer-errors)
    (printf "  ✓ 成功\n")
    (for ([e tokenizer-errors])
      (printf "  ✗ ~a\n" e)))

(printf "加载明道版解析器...\n")
(define parser-errors (load-mingdao-source mingdao-ns parser-source))
(if (null? parser-errors)
    (printf "  ✓ 成功\n")
    (for ([e parser-errors])
      (printf "  ✗ ~a\n" e)))

;; ========== Token 格式转换 ==========
(define (token->comparable tok)
  (list (symbol->string (token-type tok))
        (token-value tok)
        (token-line tok)))

(define (mingdao-token->comparable tok)
  (define val (list-ref tok 2))
  (list (list-ref tok 1)
        (if (null? val) #f val)
        (list-ref tok 3)))

;; ========== 明道版分词器调用 ==========
(define (mingdao-tokenize code)
  (parameterize ([current-namespace mingdao-ns])
    (eval `(分词 ,code))))

;; ========== 明道版解析器调用 ==========
(define (mingdao-parse code)
  (parameterize ([current-namespace mingdao-ns])
    (define tokens (eval `(分词 ,code)))
    (eval `(解析 ',tokens))))

;; ========== 测试辅助函数 ==========
(define (test-consistency name code)
  (printf "▶ ~a\n" name)
  (printf "  代码: ~a\n" code)

  (define rt-tokens
    (with-handlers ([exn:fail? (λ (e)
                                 (printf "  ✗ Racket版分词失败: ~a\n" (exn-message e))
                                 #f)])
      (tokenize code)))

  (define rt-ast
    (when rt-tokens
      (with-handlers ([exn:fail? (λ (e)
                                   (printf "  ✗ Racket版解析失败: ~a\n" (exn-message e))
                                   #f)])
        (parse rt-tokens))))

  (define md-tokens
    (with-handlers ([exn:fail? (λ (e)
                                 (printf "  ✗ 明道版分词失败: ~a\n" (exn-message e))
                                 #f)])
      (mingdao-tokenize code)))

  (define md-ast
    (when md-tokens
      (with-handlers ([exn:fail? (λ (e)
                                   (printf "  ✗ 明道版解析失败: ~a\n" (exn-message e))
                                   #f)])
        (mingdao-parse code))))

  (when (and rt-tokens md-tokens)
    (define rt-tok-simple (map token->comparable rt-tokens))
    (define md-tok-simple (map mingdao-token->comparable md-tokens))
    (if (equal? rt-tok-simple md-tok-simple)
        (printf "  ✓ Token 一致\n")
        (begin
          (printf "  ✗ Token 不一致！\n")
          (printf "    Racket (~a): ~a\n" (length rt-tok-simple) rt-tok-simple)
          (printf "    明道 (~a):   ~a\n" (length md-tok-simple) md-tok-simple))))

  (when (and rt-ast md-ast)
    (if (equal? rt-ast md-ast)
        (printf "  ✓ AST 一致\n\n")
        (begin
          (printf "  ✗ AST 不一致！\n")
          (printf "    Racket: ~a\n" rt-ast)
          (printf "    明道:   ~a\n" md-ast)
          (printf "\n")))))

(printf "\n══════════════════════════════════\n")
(printf "  明道自举 Phase 3：Bootstrap 验证\n")
(printf "══════════════════════════════════\n\n")

(test-consistency "数字字面量" "42")
(test-consistency "字符串字面量" "\"hello\"")
(test-consistency "真值" "真值")
(test-consistency "假值" "假值")
(test-consistency "空值" "空值")
(test-consistency "标识符" "x")

(test-consistency "变量定义" "定义x就是5")
(test-consistency "变量定义+字符串" "定义x就是\"hello\"")

(test-consistency "SVO 打印" "打印,42")
(test-consistency "SVO 函数调用" "x,打印")
(test-consistency "SVO 运算符调用" "加,1,2")

(test-consistency "列表字面量" "列表,1,2,3")

(test-consistency "简单条件" "如果x大于0那么：\n  打印,x")

(test-consistency "无空格定义" "定义汉诺塔就是函n,源,目标,辅助：\n  如果n等于0那么：\n    返回")

(test-consistency "无空格汉诺塔调用"
  "汉诺塔,3,\"A\",\"C\",\"B\"")

(printf "\n══════════════════════════════════\n")
(printf "  Phase 3 验证完成\n")
(printf "══════════════════════════════════\n")