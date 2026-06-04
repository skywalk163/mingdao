#lang racket/base

(require racket/port
         racket/string
         racket/match
         racket/date
         json
         "transport.rkt
         "text-sync.rkt
         "diagnostics.rkt"
         "completion.rkt")

(provide start-lsp-server)

;; LSP服务器状态
(struct lsp-server-state (transport
                         text-sync
                         diagnostics
                         completion
                         workspace-folders))

;; 初始化服务器
(define (initialize-server transport)
  (lsp-server-state transport
                     (make-text-sync)
                     (make-diagnostics)
                     (make-completion)
                     '()))

;; 启动LSP服务器
(define (start-lsp-server)
  (displayln "明道语言 LSP服务器启动中...")
  (define transport (make-stdio-transport))
  (define server-state (initialize-server transport))
  (displayln "LSP服务器已启动，等待连接...")
  (server-loop server-state))

;; 服务器主循环
(define (server-loop state)
  (with-handlers ([exn:fail? (λ (e)
                              (eprintf "服务器错误: ~a\n" (exn-message e))
                              (server-loop state)])
    (define request (transport-read (lsp-server-state-transport state))
    (when request
      (handle-request state request)
      (server-loop state))))

;; 处理请求
(define (handle-request state request)
  (match request
    [(hash-table ('jsonrpc "2.0")
                 ('id id)
                 ('method "initialize")
                 ('params params)
     (handle-initialize state id params)]
    [(hash-table ('jsonrpc "2.0")
                 ('method "initialized")
     (handle-initialized state)]
    [(hash-table ('jsonrpc "2.0")
                 ('method "shutdown")
                 ('id id)
     (handle-shutdown state id)]
    [(hash-table ('jsonrpc "2.0")
                 ('method "exit")
     (handle-exit state)]
    [(hash-table ('jsonrpc "2.0")
                 ('method "textDocument/didOpen")
                 ('params params)
     (handle-did-open state params)]
    [(hash-table ('jsonrpc "2.0")
                 ('method "textDocument/didChange")
                 ('params params)
     (handle-did-change state params)]
    [(hash-table ('jsonrpc "2.0")
                 ('id id)
                 ('method "textDocument/completion")
                 ('params params)
     (handle-completion state id params)]
    [_
     (eprintf "未知请求: ~a\n" request)]))

;; 处理初始化
(define (handle-initialize state id params)
  (define response
    (hash 'capabilities
            (hash 'textDocumentSync 1
                  'completionProvider (hash 'triggerCharacters '("" "(" " " ".")
                  'definitionProvider #t
                  'documentFormattingProvider #t
                  'hoverProvider #t)))
  (transport-write (lsp-server-state-transport state)
                (hash 'jsonrpc "2.0"
                      'id id
                      'result response)))

;; 处理initialized
(define (handle-initialized state)
  (displayln "客户端已初始化"))

;; 处理shutdown
(define (handle-shutdown state id)
  (transport-write (lsp-server-state-transport state)
                    (hash 'jsonrpc "2.0"
                          'id id
                          'result (hash))))

;; 处理exit
(define (handle-exit state)
  (displayln "服务器退出")
  (exit 0))

;; 处理文档打开
(define (handle-did-open state params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define text (hash-ref doc 'text))
  (text-sync-open (lsp-server-state-text-sync state) uri text)
  (update-diagnostics state uri))

;; 处理文档变更
(define (handle-did-change state params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define changes (hash-ref params 'contentChanges))
  (text-sync-change (lsp-server-state-text-sync state) uri changes)
  (update-diagnostics state uri))

;; 处理代码补全
(define (handle-completion state id params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define pos (hash-ref params 'position))
  (define line (hash-ref pos 'line))
  (define char (hash-ref pos 'character))
  (define completions (completion-get (lsp-server-state-completion state) uri line char))
  (transport-write (lsp-server-state-transport state)
                    (hash 'jsonrpc "2.0"
                          'id id
                          'result completions)))

;; 更新诊断信息
(define (update-diagnostics state uri)
  (define diagnostics (diagnostics-compute (lsp-server-state-diagnostics state)
                                      (lsp-server-state-text-sync state)
                                      uri))
  (transport-write (lsp-server-state-transport state)
                (hash 'jsonrpc "2.0"
                      'method "textDocument/publishDiagnostics"
                      'params (hash 'uri uri
                                     'diagnostics diagnostics))))

;; 启动服务器
(module+ main
  (start-lsp-server))