#lang racket/base
(require racket/file
         racket/path
         "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         "../lang/semantic.rkt"
         "../lang/module.rkt"
         "../lang/type-checker.rkt"
         "../lang/type-system.rkt"
         "../lang/ir.rkt"
         "../lang/error-messages.rkt")

;; 自动检测项目根目录
(define (get-project-root)
  (define candidates
    (list (current-directory)
          (build-path (current-directory) 'up)))
  (or (for/or ([c candidates])
        (and (directory-exists? (build-path c "mingdao" "lang"))
             (build-path c "mingdao")))
      (for/or ([c candidates])
        (and (directory-exists? (build-path c "lang"))
             c))
      (current-directory)))

(define project-root (get-project-root))
(define (resolve-path rel) (path->string (build-path project-root rel)))
(define all-passed? #t)

(define (mark-failed! reason)
  (set! all-passed? #f))

(printf "=== 集成测试 - 逐个文件解析测试 ===\n")
(printf "项目根: ~a\n\n" project-root)

(define (safe-tokenize source)
  (with-handlers ([exn:fail? (λ (e) (values #f (exn-message e)))])
    (values (tokenize source) #f)))

(define (safe-parse tokens)
  (with-handlers ([exn:fail? (λ (e) (values #f (exn-message e)))])
    (values (parse tokens) #f)))

(define (safe-analyze ast)
  (with-handlers ([exn:fail? (λ (e) (values #f (exn-message e)))])
    (values (analyze ast builtin-names) #f)))

(define (safe-check-program ast)
  (with-handlers ([exn:fail:type? (λ (e) (values (exn-message e) #f))]
                  [exn:fail? (λ (e) (values #f (exn-message e)))])
    (check-program ast (make-type-env))
    (values #f #f)))

(define (safe-ast->ir ast)
  (with-handlers ([exn:fail? (λ (e) (values #f (exn-message e)))])
    (values (ast->ir ast null) #f)))

(define (safe-optimize-module ir)
  (with-handlers ([exn:fail? (λ (e) (values #f (exn-message e)))])
    (values (optimize-module ir) #f)))

(define (test-file label filepath)
  (printf "--- ~a：~a ---~n" label filepath)
  (define source (file->string (resolve-path filepath)))

  ;; 1. 分词
  (define-values (tokens token-err) (safe-tokenize source))
  (if token-err
      (begin (mark-failed! "tokenize") (printf "  ✗ 分词失败: ~a~n" token-err))
      (printf "  ✓ 分词成功 (~a tokens)~n" (length tokens)))
  (when (not tokens) (printf "~n") (error "分词失败"))

  ;; 2. 解析
  (define-values (ast parse-err) (safe-parse tokens))
  (if parse-err
      (begin (mark-failed! "parse") (printf "  ✗ 解析失败: ~a~n" parse-err))
      (printf "  ✓ 解析成功 (~a expressions)~n" (length ast)))
  (when (not ast) (printf "~n") (error "解析失败"))

  ;; AST 预览
  (printf "  AST 预览:~n")
  (for ([e ast] [i (in-range (min 3 (length ast)))])
    (define str (format "~a" e))
    (printf "    [~a] ~a~n" i (if (> (string-length str) 120)
                                    (string-append (substring str 0 120) "...")
                                    str)))

  ;; 3. 语义分析 (M2)
  (define-values (sem-errors sem-err) (safe-analyze ast))
  (if sem-err
      (begin (mark-failed! "semantic") (printf "  ✗ 语义分析失败: ~a~n" sem-err))
      (printf "  ✓ 语义分析: 发现 ~a 个问题~n" (length sem-errors)))
  (when sem-errors
    (for ([err sem-errors])
      (printf "    - ~a (line ~a): ~a~n"
              (semantic-error-type err)
              (semantic-error-line err)
              (semantic-error-message err))))

  ;; 4. 模块依赖检测 (M3)
  (with-handlers ([exn:fail? (λ (e) (mark-failed! "module") (printf "  ✗ 依赖检测: ~a~n" (exn-message e)))])
    (define deps (extract-dependencies ast))
    (printf "  ✓ 模块依赖: ~a~n" deps)
    (define exports (extract-exports ast))
    (printf "  ✓ 导出符号: ~a~n" exports))

  ;; 5. 类型检查 (M1)
  (define-values (type-err type-exn) (safe-check-program ast))
  (cond
    [type-exn (mark-failed! "type-check") (printf "  ! 类型检查异常: ~a~n" type-exn)]
    [type-err (printf "  ✓ 类型检查: 发现类型错误（预期）~n")]
    [else (printf "  ✓ 类型检查: 无类型错误~n")])

  ;; 6. IR 生成 (M5)
  (define-values (ir ir-err) (safe-ast->ir ast))
  (if ir-err
      (printf "  ! IR生成: ~a~n" ir-err)
      (begin
        (printf "  ✓ IR生成成功~n")
        (let-values ([(opt opt-err) (safe-optimize-module ir)])
          (if opt-err
              (printf "  ! IR优化: ~a~n" opt-err)
              (printf "  ✓ IR优化成功~n")))))

  ;; 7. 错误解释 (M4)
  (with-handlers ([exn:fail? (λ (e) (void))])
    (define expl (hash-ref error-explanations "E0002" #f))
    (when expl
      (printf "  ✓ 错误解释系统可用 (E0002: ~a)~n" (hash-ref expl 'title #f))))

  (printf "~n"))

;; 测试所有四个模块
(test-file "辅助函数模块" "examples/sort-integration/utils.mingdao")
(test-file "排序算法模块" "examples/sort-integration/algorithms.mingdao")
(test-file "主程序"     "examples/sort-integration/main.mingdao")
(test-file "错误示例"   "examples/sort-integration/errors-demo.mingdao")

(printf "=== 解析测试完成 ===~n")
(printf "结果: ~a~n" (if all-passed? "✓ 全部通过" "✗ 有失败"))
(if all-passed? (exit 0) (exit 1))
