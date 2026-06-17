#lang racket/base

;; AI 提供商配置模块
;; 定义所有支持的 LLM 提供商及其端点、API 密钥环境变量和默认模型

(require racket/hash
         racket/string)

(provide *ai-providers*
         *default-provider*
         get-provider
         get-api-key
         list-providers)

;; 所有支持的 AI 提供商配置
;; 每个提供商是一个 hash，包含：
;;   'name            — 显示名称
;;   'api-key-env     — API 密钥环境变量名
;;   'base-url        — API 基础 URL
;;   'chat-path       — 聊天补全端点路径
;;   'default-model   — 默认模型名称字符串
;;   'supported-models — 支持模型的列表
(define *ai-providers*
  (hash "deepseek"
        (hash 'name "DeepSeek"
              'api-key-env "DEEPSEEK_API_KEY"
              'base-url "https://api.deepseek.com"
              'chat-path "/chat/completions"
              'default-model "deepseek-chat"
              'supported-models '("deepseek-chat" "deepseek-coder"))
        "glm"
        (hash 'name "智谱GLM"
              'api-key-env "ZHIPU_API_KEY"
              'base-url "https://open.bigmodel.cn/api/paas/v4"
              'chat-path "/chat/completions"
              'default-model "glm-4"
              'supported-models '("glm-4" "glm-4-flash" "glm-4-plus" "glm-3-turbo"))
        "wenxin"
        (hash 'name "百度文心"
              'api-key-env "WENXIN_API_KEY"
              'base-url "https://qianfan.baidubce.com/v2"
              'chat-path "/chat/completions"
              'default-model "ernie-4.0"
              'supported-models '("ernie-4.0" "ernie-3.5"))
        "tongyi"
        (hash 'name "阿里通义"
              'api-key-env "TONGYI_API_KEY"
              'base-url "https://dashscope.aliyuncs.com/compatible-mode/v1"
              'chat-path "/chat/completions"
              'default-model "qwen-turbo"
              'supported-models '("qwen-turbo" "qwen-plus" "qwen-max"))
        "openai"
        (hash 'name "OpenAI"
              'api-key-env "OPENAI_API_KEY"
              'base-url "https://api.openai.com/v1"
              'chat-path "/chat/completions"
              'default-model "gpt-4o-mini"
              'supported-models '("gpt-4o" "gpt-4o-mini" "gpt-4-turbo" "gpt-3.5-turbo"))))

;; 默认提供商名称
(define *default-provider* "deepseek")

;; 根据名称获取提供商配置 hash
;; 如果名称不存在则抛出错误
(define (get-provider name)
  (hash-ref *ai-providers* name
            (lambda ()
              (error 'get-provider "未知的 AI 提供商：~a；可用提供商：~a"
                     name (string-join (list-providers) ", ")))))

;; 获取提供商的 API 密钥
;; 从环境变量中读取，如果未设置则返回 #f
(define (get-api-key provider-name)
  (define provider (get-provider provider-name))
  (getenv (hash-ref provider 'api-key-env)))

;; 返回所有提供商名称的排序后的列表
(define (list-providers)
  (sort (hash-keys *ai-providers*) string<?))
