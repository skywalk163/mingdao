#lang racket/base

(require racket/port
         racket/string
         racket/match
         racket/date
         racket/list
         json
         "transport.rkt"
         "text-sync.rkt"
         "diagnostics.rkt"
         "completion.rkt"
         "analysis.rkt"
         "../../lang/semantic.rkt")

(provide start-lsp-server)

;; 内置函数名列表
(define builtin-names
  '("打印" "长度" "索引" "列表" "列表修改" "消息拼接" "生成" "捕获" "任意" "新建"
    "定义类" "异步" "等待" "加" "减" "乘" "除" "模" "幂"
    "大于" "小于" "等于" "不等" "大于等于" "小于等于" "非" "与" "或"
    "转整数" "转浮点数" "数字转字符串" "字符串长度" "正弦" "余弦" "阶乘" "随机整数"
    "绝对值" "最大值" "最小值" "是整数" "是浮点数" "是字符串" "是数" "是空" "获取类型"
    "范围" "映射" "过滤" "追加" "拼接" "反转" "包含" "切片"))

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
    [(hash-table ('jsonrpc "2.0")
                 ('id id)
                 ('method "textDocument/references")
                 ('params params))
     (handle-references state id params)]
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
          'documentSymbolProvider #t
          'referencesProvider #t))
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
  (define text (text-sync-get-text (lsp-server-state-text-sync state) uri))
  (define diagnostics
    (if text
        (let* ([result (analyze-document text builtin-names)])
          (get-diagnostics result))
        '()))
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
  (define text (text-sync-get-text (lsp-server-state-text-sync state) uri))
  (define completions
    (if text
        (let* ([result (analyze-document text builtin-names)])
          (get-completions result builtin-names))
        (hash 'isIncomplete #f 'items '())))
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
        (let* ([result (analyze-document text builtin-names)]
               [word (find-symbol-at-pos line char (analysis-result-source-lines result))]
               [scope (analysis-result-global-scope result)])
          (get-hover-info word scope))
        #f))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result hover-info)))

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
        (let* ([result (analyze-document text builtin-names)]
               [word (find-symbol-at-pos line char (analysis-result-source-lines result))]
               [scope (analysis-result-global-scope result)]
               [found (and word (lookup-symbol word scope))])
          (when found
            (define info (car found))
            (when (symbol-info-line info)
              (hash 'uri uri
                    'range (hash 'start (hash 'line (symbol-info-line info)
                                              'character (symbol-info-col info))
                                 'end (hash 'line (symbol-info-line info)
                                            'character (+ (symbol-info-col info)
                                                          (string-length word))))))))
        #f))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result location)))

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
  ;; 获取第一个缓存文档的符号
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result '())))

;; ============================================================
;; 查找引用 — 在 AST 中搜索所有对符号的引用
;; ============================================================

(define (handle-references state id params)
  (define doc (hash-ref params 'textDocument))
  (define uri (hash-ref doc 'uri))
  (define pos (hash-ref params 'position))
  (define line (hash-ref pos 'line))
  (define char (hash-ref pos 'character))
  (define text (text-sync-get-text (lsp-server-state-text-sync state) uri))
  (define locations
    (if text
        (let* ([result (analyze-document text builtin-names)]
               [word (find-symbol-at-pos line char (analysis-result-source-lines result))])
          (if word
              (let* ([raw-locs (find-references-in-ast word (analysis-result-ast result))])
                (for/list ([loc raw-locs])
                  (match-define (list l c) loc)
                  (hash 'uri uri
                        'range (hash 'start (hash 'line l 'character c)
                                     'end (hash 'line l 'character (max 1 (+ c 1)))))))
              '()))
        '()))
  (transport-write (lsp-server-state-transport state)
                   (hash 'jsonrpc "2.0"
                         'id id
                         'result locations)))

;; ============================================================
;; 启动入口
;; ============================================================

(module+ main
  (start-lsp-server))