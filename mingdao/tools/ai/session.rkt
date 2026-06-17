#lang racket/base

;; 会话管理模块
;; 在内存中保存多个会话，每个会话有 ID、消息历史、当前提供商和模型

(require racket/hash
         racket/string
         racket/random
         racket/date)

(provide (struct-out 会话)
         *会话表*
         ai初始化会话
         ai获取会话
         ai关闭会话
         ai添加上下文
         ai列出会话
         ai清空会话)

;; 会话结构体：
;;   id         — 会话唯一标识符
;;   消息历史    — 消息列表，每一项为 (hash 'role ... 'content ...)
;;   提供商     — 字符串，如 "deepseek"
;;   模型       — 字符串或 #f
;;   创建时间    — 时间戳（秒）
;;   更新时间    — 时间戳（秒）
(struct 会话 (id 消息历史 提供商 模型 创建时间 更新时间)
  #:transparent
  #:mutable)

;; 全局会话表（可变 hash）
(define *会话表* (make-hash))

;; 生成一个会话 ID：前缀 "sess-" 加 6 位随机数
(define (生成会话id)
  (format "sess-~a" (number->string (random 1000000) 10)))

;; 获取当前时间的秒级时间戳
(define (当前时间戳)
  (date->seconds (current-date)))

;; 初始化一个新会话
;;   #:provider — 提供商名称，默认为 "deepseek"
;;   #:model    — 模型名称，默认为 #f
;; 返回新建会话的 id
(define (ai初始化会话 #:provider [provider "deepseek"] #:model [model #f])
  (define id (生成会话id))
  (define 现在 (当前时间戳))
  (define s (会话 id '() provider model 现在 现在))
  (hash-set! *会话表* id s)
  id)

;; 根据 id 获取会话；若不存在则返回 #f
(define (ai获取会话 id)
  (hash-ref *会话表* id (lambda () #f)))

;; 关闭（删除）指定 id 的会话；若会话不存在则静默返回
(define (ai关闭会话 id)
  (hash-remove! *会话表* id)
  (void))

;; 向指定会话追加一条消息
;;   role    — "user" 或 "assistant"
;;   content — 字符串
(define (ai添加上下文 id role content)
  (define s (ai获取会话 id))
  (when s
    (define 新消息 (hash 'role role 'content content))
    (set-会话-消息历史! s (append (会话-消息历史 s) (list 新消息)))
    (set-会话-更新时间! s (当前时间戳)))
  (void))

;; 返回当前所有会话 id 的列表
(define (ai列出会话)
  (hash-keys *会话表*))

;; 清空整个会话表
(define (ai清空会话)
  (hash-clear! *会话表*)
  (void))
