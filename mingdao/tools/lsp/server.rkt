#lang racket/base

(require racket/port
         racket/string
         racket/match
         racket/date
         json
         "transport.rkt"
         "text-sync.rkt"
         "diagnostics.rkt"
         "completion.rkt")

(provide start-lsp-server)

;; LSP服务器状态
(struct lsp-server-state (transport
                         text-sync
                         diagnostics
                         completion
                         workspace-folders
                         capabilities))

;; 初始化服务器（精简，capabilities稍后由initialize填充）
(define (initialize-server transport)
  (lsp-server-state transport
                     (make-text-sync)
                     (make-diagnostics)
                     (make-completion)
                     '()
                     #f))

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
                               (server-loop state))])
    (define request (transport-read (lsp-server-state-transport state)))
    (when request
      (handle-request state request)
      (server-loop state))))

;; 处理请求
(define (handle-request state request)
  (match request
    [(hash-table ('jsonrpc "2.0")
                 ('id id)
                 ('method "initialize")
                 ('params params))
     (handle-initialize state id params)]
    [(hash-table ('jsonrpc "2.0")
                 ('method "initialized"))
     (handle-initialized state)]
    [(hash-table ('jsonrpc "2.0")
                 ('method "shutdown")
                 ('id id))
     (handle-shutdown state id)]
    [(hash-table ('jsonrpc "2.0")
                 ('method "exit"))
     (handle-exit state)]
    [(hash-table ('jsonrpc "2.0")
                 ('method "textDocument/didOpen")
                 ('params params))
     (handle-did-open state params)]
    [(hash-table ('jsonrpc "2.0")
                 ('method "textDocument/didChange")
                 ('params params))
     (handle-did-change state params)]
    [(hash-table ('jsonrpc "2.0")
                 ('method "textDocument/didClose")
                 ('params params))
     (handle-did-close state params)]
    [(hash-table ('jsonrpc "2.0")
                 ('id id)
                 ('method "textDocument/completion")
                 ('params params))
     (handle-completion state id params)]
    [(hash-table ('jsonrpc "2.0")
                 ('id id)
                 ('method "textDocument/hover")
                 ('params params))
     (handle-hover state id params)]
    [(hash-table ('jsonrpc "2.0")
                 ('id id)
                 ('method "textDocument/definition")
                 ('params params))
     (handle-definition state id params)]
    [(hash-table ('jsonrpc "2.0")
                 ('id id)
                 ('method "textDocument/formatting")
                 ('params params))
     (handle-formatting state id params)]
    [(hash-table ('jsonrpc "2.0")
                 ('id id)
                 ('method "textDocument/documentSymbol"))
     (handle-document-symbol state id)]
    [_
     ;; 对未知的通知（无id）直接忽略，对请求（有id）返回空
     (define id (hash-ref request 'id #f))
     (when id
       (transport-write (lsp-server-state-transport state)
                        (hash 'jsonrpc "2.0"
                              'id id
                              'result (hash))))]))

;; ============================================================
;; Initialize / Shutdown / Exit
;; ============================================================

(define (handle-initialize state id params)
  (define capabilities
    (hash 'textDocumentSync 1
          'completionProvider (hash 'triggerCharacters '("(" " " "."))
          'definitionProvider #t
          'documentFormattingProvider #t
          'hoverProvider #t
          'documentSymbolProvider #t))
  (define response (hash 'capabilities capabilities))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result response)))

(define (handle-initialized state)
  (displayln "客户端已初始化"))

(define (handle-shutdown state id)
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result (hash))))

(define (handle-exit state)
  (displayln "服务器退出")
  (exit 0))

;; ============================================================
;; 文本同步
;; ============================================================

(define (handle-did-open state params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define text (hash-ref doc 'text))
  (text-sync-open (lsp-server-state-text-sync state) uri text)
  (update-diagnostics state uri))

(define (handle-did-change state params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define changes (hash-ref params 'contentChanges))
  (text-sync-change (lsp-server-state-text-sync state) uri changes)
  (update-diagnostics state uri))

(define (handle-did-close state params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (text-sync-close (lsp-server-state-text-sync state) uri)
  ;; 清除诊断
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'method "textDocument/publishDiagnostics"
                         'params (hash 'uri uri 'diagnostics '()))))

;; ============================================================
;; 诊断
;; ============================================================

(define (update-diagnostics state uri)
  (define diagnostics (diagnostics-compute (lsp-server-state-diagnostics state)
                                           (lsp-server-state-text-sync state)
                                           uri))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'method "textDocument/publishDiagnostics"
                         'params (hash 'uri uri
                                        'diagnostics diagnostics))))

;; ============================================================
;; 代码补全
;; ============================================================

(define (handle-completion state id params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define pos (hash-ref params 'position))
  (define line (hash-ref pos 'line))
  (define char (hash-ref pos 'character))
  (define text (text-sync-get-text (lsp-server-state-text-sync state) uri))
  (define completions
    (if text
        (completion-get (lsp-server-state-completion state) uri line char text)
        (completion-get (lsp-server-state-completion state) uri line char "")))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result completions)))

;; ============================================================
;; Hover — 悬停时显示类型/文档信息
;; ============================================================

(define (handle-hover state id params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define pos (hash-ref params 'position))
  (define line (hash-ref pos 'line))
  (define char (hash-ref pos 'character))
  (define text (text-sync-get-text (lsp-server-state-text-sync state) uri))
  (define hover-info
    (if text
        (compute-hover text line char)
        #f))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result hover-info)))

(define (compute-hover text line char)
  (define lines (string-split text "\n" #:trim? #f))
  (define current-line (list-ref lines (min line (sub1 (length lines)))))
  (define current-word (extract-word-at-pos current-line char))
  (when current-word
    (hash 'contents
          (hash 'kind "markdown"
                'value (format "**`~a`**\n\n~a\n\n---\n明道语言关键字"
                               current-word (get-hover-doc current-word))))))

(define (extract-word-at-pos line-str char)
  (define len (string-length line-str))
  (when (and (>= char 0) (< char len))
    (define start
      (let loop ([pos char])
        (if (or (<= pos 0)
                (char-whitespace? (string-ref line-str (sub1 pos)))
                (char=? (string-ref line-str (sub1 pos)) #\，)
                (char=? (string-ref line-str (sub1 pos)) #\())
            pos
            (loop (sub1 pos)))))
    (define end
      (let loop ([pos char])
        (if (or (>= pos len)
                (char-whitespace? (string-ref line-str pos))
                (char=? (string-ref line-str pos) #\，)
                (char=? (string-ref line-str pos) #\)))
            pos
            (loop (add1 pos)))))
    (when (< start end)
      (substring line-str start end))))

;; 悬停文档
(define (get-hover-doc word)
  (cond
    [(member word '("定义" "常量")) "定义变量或常量\n\n`定义 变量名 就是 值`"]
    [(member word '("如果" "那么" "否则")) 
     "条件分支语句\n\n`如果 条件 那么：\n    ...\n否则：\n    ...`"]
    [(member word '("对于")) "循环语句\n\n`对于 i 从 0 到 10：\n    打印, i`"]
    [(member word '("返回")) "从函数返回值\n\n`返回 表达式`"]
    [(member word '("函数" "就是函")) "定义匿名函数\n\n`就是函 参数1, 参数2：\n    ...`"]
    [(member word '("打印")) "输出到控制台"]
    [(member word '("导入")) "导入模块"]
    [(member word '("类")) "定义类"]
    [(member word '("接口")) "定义接口"]
    [(member word '("列表")) "创建列表\n\n`列表 1, 2, 3`"]
    [(member word '("字典")) "创建字典"]
    [(member word '("赋值")) "对变量重新赋值\n\n`赋值 变量名 = 新值`"]
    [else (format "符号: ~a" word)]))

;; ============================================================
;; 定义跳转 — 跳转到变量/函数的定义处
;; ============================================================

(define (handle-definition state id params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define pos (hash-ref params 'position))
  (define line (hash-ref pos 'line))
  (define char (hash-ref pos 'character))
  (define text (text-sync-get-text (lsp-server-state-text-sync state) uri))
  (define location
    (if text
        (compute-definition text uri line char)
        #f))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result location)))

(define (compute-definition text uri line char)
  (define lines (string-split text "\n" #:trim? #f))
  (define current-line (list-ref lines (min line (sub1 (length lines)))))
  (define word (extract-word-at-pos current-line char))
  (when word
    ;; 搜索文档中`定义 word 就`或`定义 word 就是`开头的行
    (for/or ([ln lines] [i (in-naturals)])
      (when (regexp-match (format "定义 ~a 就" (regexp-quote word)) ln)
        (hash 'uri uri
              'range (hash 'start (hash 'line i 'character 0)
                           'end (hash 'line i 'character (string-length ln))))))))

;; ============================================================
;; 格式化 — 缩进格式化
;; ============================================================

(define (handle-formatting state id params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define options (hash-ref params 'options (hash)))
  (define tab-size (hash-ref options 'tabSize 4))
  (define insert-spaces? (hash-ref options 'insertSpaces #t))
  (define text (text-sync-get-text (lsp-server-state-text-sync state) uri))
  (define formatted
    (if text
        (format-mingdao-code text tab-size insert-spaces?)
        text))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result (list (hash 'range (hash 'start (hash 'line 0 'character 0)
                                                           'end (hash 'line 10000 'character 0))
                                              'newText formatted)))))

(define (format-mingdao-code text tab-size insert-spaces?)
  (define indent-unit (if insert-spaces?
                          (make-string tab-size #\space)
                          "\t"))
  (define lines (string-split text "\n" #:trim? #f))
  (define indent-level 0)
  
  (define (count-indent-tokens line)
    ;; 计算开/闭括号和关键字来调整缩进
    (define open-count
      (for/sum ([ch (in-string line)])
        (if (char=? ch #\（) 1 0)))
    (define close-count
      (for/sum ([ch (in-string line)])
        (if (char=? ch #\）) 1 0)))
    (- open-count close-count))
  
  (define formatted-lines
    (for/list ([line lines])
      (define trimmed (string-trim line))
      (define indent-change (count-indent-tokens trimmed))
      ;; 对 `否则` `否则若` `捕获` 等关键字减少一级缩进
      (define keyword-dedent?
        (or (string-prefix? trimmed "否则")
            (string-prefix? trimmed "捕获")
            (string-prefix? trimmed "始终")))
      (when keyword-dedent?
        (set! indent-level (max 0 (sub1 indent-level))))
      ;; 生成缩进后的行
      (define result-line
        (if (string=? trimmed "")
            ""
            (string-append (make-string indent-level #\tab) trimmed)))
      ;; 更新缩进
      (when (and (not (string=? trimmed ""))
                 (or (string-suffix? trimmed "：")
                     (string-suffix? trimmed ":")
                     (> indent-change 0)))
        (set! indent-level (add1 indent-level)))
      result-line))
  
  (string-join formatted-lines "\n"))

;; ============================================================
;; 文档符号 — 列出文档中的定义
;; ============================================================

(define (handle-document-symbol state id)
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result '())))

;; ============================================================
;; 启动入口
;; ============================================================

(module+ main
  (start-lsp-server))