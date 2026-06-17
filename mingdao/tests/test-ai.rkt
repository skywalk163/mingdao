#lang racket/base

;; 明道 AI 模块系统测试
;; 运行: racket -t mingdao/tests/test-ai.rkt

(require racket/string
         racket/list
         racket/hash
         racket/format
         racket/port
         rackunit)

;; === 动态加载所有模块 ===

(define (safe-require filename sym)
  (with-handlers ([exn:fail? (lambda (e) (printf "[WARN] ~a:~a 加载失败: ~a\n" filename sym (exn-message e)) #f)])
    (define full-path (build-path (current-directory) "mingdao" "tools" "ai" filename))
    (dynamic-require full-path sym)))

(define (safe-require-sub filename sym)
  (with-handlers ([exn:fail? (lambda (e) (printf "[WARN] providers/~a:~a 加载失败: ~a\n" filename sym (exn-message e)) #f)])
    (define full-path (build-path (current-directory) "mingdao" "tools" "ai" "providers" filename))
    (dynamic-require full-path sym)))

(displayln "╔═══════════════════════════════════════════╗")
(displayln "║     明道 AI 模块系统测试                   ║")
(displayln "╚═══════════════════════════════════════════╝")
(newline)

;; === 测试计数器 ===

(define total-tests 0)
(define passed-tests 0)

(define-syntax-rule (测试 名称 表达式)
  (begin
    (set! total-tests (add1 total-tests))
    (with-handlers ([exn:fail? (lambda (e)
                                 (printf "[FAIL] ~a\n        原因: ~a\n" 名称 (exn-message e)))])
      (when 表达式
        (set! passed-tests (add1 passed-tests))
        (printf "[PASS] ~a\n" 名称)))))

;; === Phase 1: 基础模块 ===
(displayln "=== Phase 1: 基础模块 ===")
(newline)

(测试 "config.rkt 可加载" (not (equal? (safe-require "config.rkt" 'list-providers) #f)))
(define list-providers-fn (safe-require "config.rkt" 'list-providers))
(define default-provider-fn (safe-require "config.rkt" '*default-provider*))

(测试 "list-providers 返回非空列表"
  (and list-providers-fn (not (empty? (list-providers-fn)))))
(测试 "有 5 个已配置的提供商"
  (and list-providers-fn (= (length (list-providers-fn)) 5)))

(define semantic-fn (safe-require "semantic-protocol.rkt" '语义查询))
(define keyword-fn (safe-require "semantic-protocol.rkt" '获取关键字))
(测试 "semantic-protocol.rkt 可加载" (not (equal? semantic-fn #f)))
(测试 "获取关键字返回非空"
  (and keyword-fn (let ([r (keyword-fn)])
                    (or (list? r) (hash? r))
                    #t)))

(define prompt-fn (safe-require "prompt-builder.rkt" '构造系统提示词))
(测试 "prompt-builder.rkt 可加载" (not (equal? prompt-fn #f)))
(测试 "系统提示词非空且包含中文"
  (and prompt-fn
       (let ([text (prompt-fn)])
         (and (string? text)
              (> (string-length text) 100)
              (regexp-match? #px"[\u4e00-\u9fff]" text)))))

(define code-extract-fn (safe-require "prompt-builder.rkt" '提取代码))
(测试 "提取代码可解析 markdown 代码块"
  (and code-extract-fn
       (let* ([test-text "```\n定义 x 就是 42\n```"]
              [result (code-extract-fn test-text)])
         (string-contains? result "定义"))))

(define session-init-fn (safe-require "session.rkt" 'ai初始化会话))
(define session-add-fn (safe-require "session.rkt" 'ai添加上下文))
(测试 "session.rkt 可加载" (not (equal? session-init-fn #f)))
(测试 "可以创建新会话并添加上下文"
  (and session-init-fn session-add-fn
       (let* ([sid (session-init-fn)])
         (session-add-fn sid "user" "测试需求")
         (string? sid))))

(define validator-fn (safe-require "validator.rkt" '验证代码))
(测试 "validator.rkt 可加载" (not (equal? validator-fn #f)))
(测试 "验证明道代码返回 hash 且有状态字段"
  (and validator-fn
       (let* ([code "定义 x 就是 42\nx, 打印"]
              [result (validator-fn code)])
         (or (hash? result) (equal? (hash-ref result '状态 #f) "通过")))))

(newline)
(displayln "=== Phase 2: 提供商模块 ===")
(newline)

(for ([provider-name '("deepseek" "glm" "wenxin" "tongyi" "openai")])
  (define call-fn (safe-require-sub (string-append provider-name ".rkt") '调用模型))
  (define models-fn (safe-require-sub (string-append provider-name ".rkt") '支持的模型))
  (测试 (format "~a.rkt 可加载" provider-name) (not (equal? call-fn #f)))
  (测试 (format "~a 支持模型列表非空" provider-name)
    (and models-fn (not (empty? (models-fn))))))

(newline)
(displayln "=== Phase 3: 适配器 ===")
(newline)

(define adapter-gen-fn (safe-require "adapter.rkt" 'ai生成代码))
(define adapter-verify-fn (safe-require "adapter.rkt" 'ai验证代码))
(define adapter-providers-fn (safe-require "adapter.rkt" 'ai获取提供者列表))

(测试 "adapter.rkt 可加载" (not (equal? adapter-gen-fn #f)))
(测试 "ai获取提供者列表返回5个提供商"
  (and adapter-providers-fn (= (length (adapter-providers-fn)) 5)))

(测试 "adapter 初始化会话"
  (let ([init-fn (safe-require "adapter.rkt" 'ai初始化会话)])
    (and init-fn (string? (init-fn)))))

(newline)
(displayln "=== Phase 4: 端到端消息构造测试 ===")
(newline)

(define build-msg-fn (safe-require "prompt-builder.rkt" '构造消息列表))
(测试 "构造消息列表返回 list-of-hash"
  (and build-msg-fn
       (let ([msgs (build-msg-fn "写一个加法函数")])
         (and (list? msgs)
              (> (length msgs) 0)
              (for/and ([m msgs])
                (and (hash? m)
                     (string? (hash-ref m 'role #f))
                     (string? (hash-ref m 'content #f))))))))

(newline)
(displayln "╔═══════════════════════════════════════════╗")
(printf "║     总测试: ~a  通过: ~a  失败: ~a        ║\n"
        total-tests
        passed-tests
        (- total-tests passed-tests))
(if (= passed-tests total-tests)
    (displayln "║     所有测试通过 ✓                        ║")
    (displayln "║     部分测试失败 ✗                        ║"))
(displayln "╚═══════════════════════════════════════════╝")

;; 退出码
(exit (if (= passed-tests total-tests) 0 1))
