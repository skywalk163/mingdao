#lang racket/base
;; 明道语言 Playground - 轻量级版本（纯socket实现，无GUI依赖）

(require "lang/tokenizer.rkt"
         "lang/parser.rkt"
         net/uri-codec
         racket/string
         racket/port
         racket/list
         racket/tcp)

;; 创建持久化命名空间
(define ns
  (let ([ns (make-base-namespace)])
    (parameterize ([current-namespace ns])
      (eval `(require "core/base.rkt" "runtime.rkt" racket/control))
      (void))
    ns))

;; 当前运行的求值线程（用于停止功能）
(define current-eval-thread #f)

;; 求值明道代码，返回输出
(define (eval-mingdao code)
  (define output-port (open-output-string))
  (parameterize ([current-output-port output-port]
                 [current-error-port output-port]
                 [current-namespace ns])
    (with-handlers ([exn:fail?
                     (λ (e)
                       (displayln (format "错误: ~a" (exn-message e))))])
      (define tokens (tokenize code))
      (define ast (parse tokens))
      (for ([expr ast])
        (cond
          [(and (list? expr) (eq? (car expr) 'mingdao-import))
           (void)]
          [(and (list? expr) (eq? (car expr) 'mingdao-export))
           (void)]
          [else
           (call-with-values
             (λ () (eval expr))
             (λ results
               (when (and (pair? results) (not (void? (car results))))
                 (displayln (car results)))))]))))
  (get-output-string output-port))

;; 可中断的求值函数（在独立线程中运行）
(define (eval-mingdao-with-stop code)
  (define output-port (open-output-string))
  (define (run-eval)
    (parameterize ([current-output-port output-port]
                   [current-error-port output-port]
                   [current-namespace ns])
      (with-handlers ([exn:break?
                       (λ (e) (displayln "程序已被用户停止"))])
        (with-handlers ([exn:fail?
                         (λ (e) (displayln (format "错误: ~a" (exn-message e))))])
          (define tokens (tokenize code))
          (define ast (parse tokens))
          (for ([expr ast])
            (cond
              [(and (list? expr) (eq? (car expr) 'mingdao-import))
               (void)]
              [(and (list? expr) (eq? (car expr) 'mingdao-export))
               (void)]
              [else
               (call-with-values
                 (λ () (eval expr))
                 (λ results
                   (when (and (pair? results) (not (void? (car results))))
                     (displayln (car results)))))]))))))
  (define t (thread run-eval))
  (set! current-eval-thread t)
  (thread-wait t)
  (set! current-eval-thread #f)
  (get-output-string output-port))

;; HTML页面
(define page-template
  #<<HTML
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>明道语言 Playground</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
    min-height: 100vh;
    color: #e0e0e0;
  }
  .header {
    background: rgba(255,255,255,0.05);
    backdrop-filter: blur(10px);
    border-bottom: 1px solid rgba(255,255,255,0.1);
    padding: 20px;
    text-align: center;
  }
  .main {
    max-width: 1000px;
    margin: 0 auto;
    padding: 20px;
  }
  .panel {
    background: rgba(255,255,255,0.05);
    border-radius: 8px;
    margin-bottom: 15px;
    border: 1px solid rgba(255,255,255,0.1);
  }
  .panel-header {
    padding: 10px 15px;
    border-bottom: 1px solid rgba(255,255,255,0.1);
    font-weight: bold;
    color: #8892b0;
  }
  .panel-body {
    padding: 10px;
  }
  textarea, #output {
    width: 100%;
    min-height: 300px;
    background: rgba(0,0,0,0.3);
    border: none;
    color: #e0e0e0;
    font-family: monospace;
    font-size: 14px;
    padding: 10px;
    resize: vertical;
    outline: none;
  }
  #output {
    color: #64ffda;
    white-space: pre-wrap;
  }
  .toolbar {
    display: flex;
    gap: 10px;
    padding: 10px;
    flex-wrap: wrap;
  }
  .btn {
    padding: 8px 20px;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    font-weight: bold;
  }
  .btn-run {
    background: linear-gradient(90deg, #64ffda, #48b1bf);
    color: #1a1a2e;
  }
  .btn-stop {
    background: linear-gradient(90deg, #ff6b6b, #ee5a24);
    color: white;
  }
  .btn-clear {
    background: rgba(255,255,255,0.1);
    color: #e0e0e0;
  }
</style>
</head>
<body>
<div class="header">
  <h1>明道语言 Playground</h1>
  <div>明明白白写代码，探索编程之道</div>
</div>
<div class="main">
  <div class="panel">
    <div class="panel-header">代码编辑器</div>
    <div class="panel-body">
      <textarea id="code-input" spellcheck="false">打印, "你好，明道世界！"</textarea>
    </div>
    <div class="toolbar">
      <button class="btn btn-run" onclick="runCode()">▶ 运行</button>
      <button class="btn btn-stop" onclick="stopCode()" style="display:none">⏹ 停止</button>
      <button class="btn btn-clear" onclick="clearOutput()">清空输出</button>
    </div>
  </div>
  <div class="panel">
    <div class="panel-header">运行结果</div>
    <div class="panel-body">
      <div id="output">等待运行...</div>
    </div>
  </div>
</div>
<script>
async function runCode() {
  const code = document.getElementById('code-input').value;
  if (!code.trim()) return;
  const btn = document.querySelector('.btn-run');
  const stopBtn = document.querySelector('.btn-stop');
  const output = document.getElementById('output');
  btn.disabled = true;
  btn.textContent = '⏳ 运行中...';
  stopBtn.style.display = 'inline-block';
  output.textContent = '';
  try {
    const resp = await fetch('/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'code=' + encodeURIComponent(code)
    });
    const text = await resp.text();
    output.textContent = text || '(无输出)';
  } catch (e) {
    output.textContent = '错误: ' + e.message;
  } finally {
    btn.disabled = false;
    btn.textContent = '▶ 运行';
    stopBtn.style.display = 'none';
  }
}
async function stopCode() {
  await fetch('/stop', { method: 'POST' });
}
function clearOutput() {
  document.getElementById('output').textContent = '等待运行...';
}
document.getElementById('code-input').addEventListener('keydown', function(e) {
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
    runCode();
  }
});
</script>
</body>
</html>
HTML
)

;; 解析HTTP请求
(define (parse-http-request input-port)
  (define line (read-line input-port))
  (if (eof-object? line)
      #f
      (let* ([parts (string-split line " ")]
             [method (first parts)]
             [uri (second parts)]
             [version (third parts)])
        ;; 读取请求头
        (let loop ([headers '()])
          (define header-line (read-line input-port))
          (if (or (eof-object? header-line) (string=? header-line ""))
              (let* ([uri-parts (string-split uri "?")]
                     [path (first uri-parts)]
                     [query (if (> (length uri-parts) 1) (second uri-parts) "")]
                     [content-length (let ([cl (assoc "Content-Length" headers string-ci=?)])
                                       (if cl (string->number (cdr cl)) 0))]
                     [content (if (> content-length 0)
                                  (let ([buf (make-bytes content-length)])
                                    (read-bytes! buf input-port)
                                    buf)
                                  #"")])
                (list method path query content))
              (let* ([h-parts (string-split header-line ": " 2)]
                     [h-name (first h-parts)]
                     [h-value (if (> (length h-parts) 1) (second h-parts) "")])
                (loop (cons (cons h-name h-value) headers))))))))

;; 生成HTTP响应
(define (make-response status message body content-type)
  (define body-bytes (string->bytes/utf-8 body))
  (format "HTTP/1.1 ~a ~a\r\nContent-Type: ~a\r\nContent-Length: ~a\r\nConnection: close\r\n\r\n"
          status message content-type (bytes-length body-bytes)))

;; 处理HTTP请求
(define (handle-request method path content)
  (cond
    [(and (equal? method "POST") (equal? path "/run"))
     (define content-str (bytes->string/utf-8 content))
     (define code-str
       (let* ([pairs (regexp-split #px"&" content-str)]
              [code-pair (findf (λ (s) (string-prefix? s "code=")) pairs)])
         (if code-pair
             (let* ([encoded (substring code-pair 5)]
                    [with-spaces (regexp-replace* #px"\\+" encoded " ")]
                    [decoded (uri-decode with-spaces)])
               decoded)
             #f)))
     (define output
       (if code-str
           (eval-mingdao-with-stop code-str)
           "缺少 code 参数"))
     (cons (make-response 200 "OK" output "text/plain; charset=utf-8")
           (string->bytes/utf-8 output))]
    
    [(and (equal? method "POST") (equal? path "/stop"))
     (when current-eval-thread
       (break-thread current-eval-thread)
       (set! current-eval-thread #f))
     (cons (make-response 200 "OK" "stopped" "text/plain; charset=utf-8")
           #"stopped")]
    
    [(equal? path "/")
     (cons (make-response 200 "OK" page-template "text/html; charset=utf-8")
           (string->bytes/utf-8 page-template))]
    
    [else
     (cons (make-response 404 "Not Found" "404 Not Found" "text/plain; charset=utf-8")
           #"404 Not Found")]))

;; 处理客户端连接
(define (handle-client client-socket)
  (with-handlers ([exn:fail? (λ (e) (void))])
    (define request (parse-http-request client-socket))
    (when request
      (define method (first request))
      (define path (second request))
      (define content (fourth request))
      (define response (handle-request method path content))
      (write-string (car response) client-socket)
      (write-bytes (cdr response) client-socket)
      (flush-output client-socket)))
  (close-input-port client-socket))

;; 启动HTTP服务器
(define (start-server port)
  (define listener (tcp-listen port 5 #t "0.0.0.0"))
  (printf "明道语言 Playground (轻量级版本) 启动中...\n")
  (printf "访问地址: http://localhost:~a\n" port)
  (printf "外部访问: http://<服务器IP>:~a\n" port)
  (printf "按 Ctrl+C 停止服务器\n")
  (let loop ()
    (define client (tcp-accept listener))
    (thread (λ () (handle-client client)))
    (loop)))

;; 主函数
(define (main)
  (start-server 8080))

(main)