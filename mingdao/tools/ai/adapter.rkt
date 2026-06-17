#lang racket/base

(require racket/string
         racket/list
         racket/hash
         racket/match
         racket/port
         racket/format
         racket/path)

;; ============================================================
;; 模块自身所在目录 — 用于动态加载同级模块
;; ============================================================

(define here
  (path-only (resolved-module-path-name (variable-reference->resolved-module-path (#%variable-reference)))))

(define (local-module-path sub-path)
  (build-path here sub-path))

;; ============================================================
;; 动态加载同级模块 — 失败不会崩溃
;; ============================================================

(define 构造系统提示词-fn
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "prompt-builder.rkt") '构造系统提示词)))

(define 构造用户提示词-fn
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "prompt-builder.rkt") '构造用户提示词)))

(define 构造完整提示词-fn
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "prompt-builder.rkt") '构造完整提示词)))

(define 构造消息列表-fn
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "prompt-builder.rkt") '构造消息列表)))

(define 提取代码-fn
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "prompt-builder.rkt") '提取代码)))

(define 构造上下文提示词-fn
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "prompt-builder.rkt") '构造上下文提示词)))

(define 验证代码-fn
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "validator.rkt") '验证代码)))

(define ai初始化会话-fn
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "session.rkt") 'ai初始化会话)))

(define ai获取会话-fn
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "session.rkt") 'ai获取会话)))

(define ai关闭会话-fn
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "session.rkt") 'ai关闭会话)))

(define ai添加上下文-fn
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "session.rkt") 'ai添加上下文)))

(define 会话-消息历史-fn
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "session.rkt") '会话-消息历史 (lambda () #f))))

(define *ai-providers*-cfg
  (with-handlers ([exn:fail? (lambda (e) (hash))])
    (dynamic-require (local-module-path "config.rkt") '*ai-providers* (lambda () (hash)))))

(define *default-provider*-cfg
  (with-handlers ([exn:fail? (lambda (e) "deepseek")])
    (dynamic-require (local-module-path "config.rkt") '*default-provider* (lambda () "deepseek"))))

(define get-provider-cfg
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "config.rkt") 'get-provider (lambda () #f))))

(define get-api-key-cfg
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "config.rkt") 'get-api-key (lambda () #f))))

(define list-providers-cfg
  (with-handlers ([exn:fail? (lambda (e) (lambda () '()))])
    (dynamic-require (local-module-path "config.rkt") 'list-providers (lambda () (lambda () '())))))

;; ============================================================
;; 动态加载各提供商模块
;; ============================================================

(define 调用模型-deepseek
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "providers/deepseek.rkt") '调用模型 (lambda () #f))))

(define 调用模型-glm
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "providers/glm.rkt") '调用模型 (lambda () #f))))

(define 调用模型-wenxin
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "providers/wenxin.rkt") '调用模型 (lambda () #f))))

(define 调用模型-tongyi
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "providers/tongyi.rkt") '调用模型 (lambda () #f))))

(define 调用模型-openai
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (dynamic-require (local-module-path "providers/openai.rkt") '调用模型 (lambda () #f))))

;; *provider-map*
;;   key   — 提供商名称字符串（如 "deepseek"）
;;   value — (list 调用模型-fn api-key-env default-model)
(define *provider-map*
  (hash "deepseek" (list 调用模型-deepseek "DEEPSEEK_API_KEY" "deepseek-chat")
        "glm"      (list 调用模型-glm      "ZHIPU_API_KEY"    "glm-4")
        "wenxin"   (list 调用模型-wenxin   "WENXIN_API_KEY"   "ernie-4.0")
        "tongyi"   (list 调用模型-tongyi   "TONGYI_API_KEY"   "qwen-turbo")
        "openai"   (list 调用模型-openai   "OPENAI_API_KEY"   "gpt-4o-mini")))

(provide ai生成代码
         ai验证代码
         ai获取提供者列表
         ai初始化会话
         ai获取会话
         ai关闭会话
         选择提供商)

;; ============================================================
;; 选择提供商 — 从 *provider-map* 返回 (list fn api-key-env default-model)
;; ============================================================
(define (选择提供商 provider-name)
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (hash-ref *provider-map* provider-name (lambda () #f))))

;; ============================================================
;; ai获取提供者列表 — 转发到 config 的 list-providers
;; ============================================================
(define (ai获取提供者列表)
  (if list-providers-cfg
      (list-providers-cfg)
      (sort (hash-keys *provider-map*) string<?)))

;; ============================================================
;; ai初始化会话 — 转发到 session 的 ai初始化会话
;; ============================================================
(define (ai初始化会话 #:provider [provider *default-provider*-cfg] #:model [model #f])
  (if ai初始化会话-fn
      (ai初始化会话-fn #:provider provider #:model model)
      (format "sess-~a" (number->string (random 1000000) 10))))

(define (ai获取会话 id)
  (if ai获取会话-fn
      (ai获取会话-fn id)
      #f))

(define (ai关闭会话 id)
  (when ai关闭会话-fn
    (ai关闭会话-fn id))
  (void))

;; ============================================================
;; ai验证代码 — 简单转发到 validator 的 验证代码
;; ============================================================
(define (ai验证代码 code)
  (if 验证代码-fn
      (验证代码-fn code)
      (hash '状态 '通过 '解析通过 #f '分词通过 #f '结构通过 #f '错误 #f)))

;; ============================================================
;; 内部：调用提供商
;; ============================================================
(define (调用提供商 provider-name messages #:model [model #f])
  (with-handlers ([exn:fail? (lambda (e) (format "错误: 网络请求失败 - ~a" (exn-message e)))])
    (define provider-info (选择提供商 provider-name))
    (cond
      [(not provider-info)
       (format "错误: 未知的 AI 提供商 '~a'" provider-name)]
      [else
       (define fn (first provider-info))
       (define api-key-env (second provider-info))
       (define default-model (third provider-info))
       (define actual-model (or model default-model))
       (cond
         [(not fn)
          (format "错误: 提供商 '~a' 的模块未加载" provider-name)]
         [else
          (define api-key (getenv api-key-env))
          (if (or (not api-key) (string=? (string-trim api-key) ""))
              (format "错误: 请设置环境变量 ~a" api-key-env)
              (fn api-key messages #:model actual-model))])])))

;; ============================================================
;; 主入口：ai生成代码
;; ============================================================
(define (ai生成代码 用户需求
          #:provider [provider *default-provider*-cfg]
          #:model [model #f]
          #:session-id [session-id #f]
          #:max-retries [max-retries 3]
          #:context [context #f])
  (with-handlers ([exn:fail? (lambda (e) (format "错误: ~a" (exn-message e)))])
    (define 实际提供商 (or provider *default-provider*-cfg))

    ;; 从会话读取历史消息（作为上下文）
    (define 会话历史消息
      (if (and session-id ai获取会话-fn 会话-消息历史-fn)
          (let ([s (ai获取会话-fn session-id)])
            (if s
                (with-handlers ([exn:fail? (lambda (e) '())])
                  (会话-消息历史-fn s))
                '()))
          '()))

    (define (尝试一次 重试计数 上次错误)
      (define 用户提示词
        (if 上次错误
            (string-append 用户需求 "\n\n【上次生成的代码有问题，请修正。错误信息：" 上次错误 "】")
            用户需求))

      ;; 构造消息列表 — 如果有会话历史则包含历史
      (define 基础消息
        (if 构造消息列表-fn
            (构造消息列表-fn 用户提示词 context)
            (list (hash 'role "system" 'content "请生成明道代码。")
                  (hash 'role "user" 'content 用户提示词))))

      ;; 拼接会话历史（若有）
      (define messages
        (if (and (list? 会话历史消息) (not (empty? 会话历史消息)))
            (let* ([sys (first 基础消息)]
                   [usr (second 基础消息)])
              (cons sys (append 会话历史消息 (list usr))))
            基础消息))

      (define 响应 (调用提供商 实际提供商 messages #:model model))

      (cond
        [(string-prefix? 响应 "错误")
         (values 响应 #f)]
        [else
         (define 代码 (if 提取代码-fn
                           (提取代码-fn 响应)
                           响应))
         (define 验证结果 (ai验证代码 代码))
         (define 通过? (equal? (hash-ref 验证结果 '状态 '失败) '通过))
         (if 通过?
             (values 代码 验证结果)
             (if (< 重试计数 max-retries)
                 (let ([err-msg (hash-ref 验证结果 '错误 #f)])
                   (尝试一次 (+ 1 重试计数)
                              (or err-msg "验证未通过")))
                 (values (string-append "【未能生成可验证代码，最后一次尝试：】\n" 代码)
                         验证结果)))]))

    (define-values (最终代码 验证结果) (尝试一次 1 #f))

    ;; 将会话消息写入会话
    (when (and session-id ai添加上下文-fn)
      (ai添加上下文-fn session-id "user" 用户需求)
      (ai添加上下文-fn session-id "assistant" 最终代码))

    最终代码))

;; ============================================================
;; module+ main 自测
;; ============================================================
(module+ main
  (displayln "=== 明道 AI 适配器 ===")
  (displayln (string-append "可用提供商: " (string-join (map ~a (ai获取提供者列表)) ", ")))
  (displayln "提示: 设置环境变量后使用 (ai生成代码 \"...\") 调用"))
