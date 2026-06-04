#lang racket/base
;; 明道语言 Playground — 网页交互式编程环境

;; 在无头环境中设置环境变量，避免GUI初始化问题
(environment-variables-set! (current-environment-variables)
                           #"PLT_DISPLAY_BACKEND"
                           #"none")

(require "lang/tokenizer.rkt"
         "lang/parser.rkt"
         web-server/servlet
         web-server/servlet-env
         web-server/http/request-structs
         net/uri-codec
         racket/string
         racket/port
         racket/file)

;; 创建持久化命名空间 - 避免导入必要的模块，避免GUI依赖
(define ns
  (let ([ns (make-base-namespace)])
    (parameterize ([current-namespace ns])
      ;; 只导入我们需要的基础模块
      ;; 避免导入完整的main.rkt，因为它可能会引入GUI依赖
      (eval `(require "core/base.rkt" "runtime.rkt" racket/control))
      (void))
    ns))

;; 当前运行的求值线程（用于停止功能）
(define current-eval-thread #f)

;; 加载并执行明道文件（支持递归导入）
(define (mingdao-load-file filepath)
  (define full-path
    (if (absolute-path? filepath)
        filepath
        (let* ([cwd (current-directory)]
               [try1 (build-path cwd filepath)]
               [try2 (build-path cwd "mingdao" filepath)])
          (if (file-exists? try1) try1 try2))))
  (cond
    [(not (file-exists? full-path))
     (displayln (format "错误: 找不到文件 ~a" filepath))]
    [else
     (define code (port->string (open-input-file full-path)))
     (define tokens (tokenize code))
     (define ast (parse tokens))
     (for ([expr ast])
       (cond
         [(and (list? expr) (eq? (car expr) 'mingdao-import))
          (mingdao-load-file (cadr expr))]
         [(and (list? expr) (eq? (car expr) 'mingdao-export))
          (void)]
         [else
          (call-with-values
            (λ () (eval expr))
            (λ results
              (when (and (pair? results) (not (void? (car results))))
                (displayln (car results)))))]))]))

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
           (mingdao-load-file (cadr expr))]
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
               (mingdao-load-file (cadr expr))]
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

;; HTML 页面
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
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans SC", sans-serif;
    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
    min-height: 100vh;
    color: #e0e0e0;
  }
  .header {
    background: rgba(255,255,255,0.05);
    backdrop-filter: blur(10px);
    border-bottom: 1px solid rgba(255,255,255,0.1);
    padding: 20px 40px;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .header h1 {
    font-size: 24px;
    font-weight: 700;
    background: linear-gradient(90deg, #64ffda, #48b1bf);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }
  .header .subtitle {
    font-size: 14px;
    color: #8892b0;
    margin-top: 4px;
  }
  .header .links a {
    color: #64ffda;
    text-decoration: none;
    margin-left: 20px;
    font-size: 14px;
  }
  .header .links a:hover { text-decoration: underline; }
  .main {
    max-width: 1200px;
    margin: 0 auto;
    padding: 30px 20px;
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
    min-height: calc(100vh - 100px);
  }
  @media (max-width: 768px) {
    .main { grid-template-columns: 1fr; }
    .header { flex-direction: column; text-align: center; }
    .header .links { margin-top: 10px; }
  }
  .panel {
    background: rgba(255,255,255,0.05);
    border-radius: 12px;
    border: 1px solid rgba(255,255,255,0.1);
    display: flex;
    flex-direction: column;
  }
  .panel-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    border-bottom: 1px solid rgba(255,255,255,0.1);
    font-size: 13px;
    font-weight: 600;
    color: #8892b0;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .panel-body {
    flex: 1;
    padding: 0;
    overflow: auto;
  }
  #code-input {
    width: 100%;
    height: 100%;
    min-height: 350px;
    background: rgba(0,0,0,0.3);
    border: none;
    color: #e0e0e0;
    font-family: "JetBrains Mono", "Fira Code", "Consolas", monospace;
    font-size: 14px;
    line-height: 1.6;
    padding: 16px;
    resize: none;
    outline: none;
    tab-size: 4;
  }
  #code-input:focus {
    background: rgba(0,0,0,0.4);
  }
  #output {
    width: 100%;
    height: 100%;
    min-height: 350px;
    max-height: 500px;
    background: rgba(0,0,0,0.3);
    border: none;
    color: #64ffda;
    font-family: "JetBrains Mono", "Fira Code", "Consolas", monospace;
    font-size: 14px;
    line-height: 1.6;
    padding: 16px;
    overflow-y: auto;
    white-space: pre-wrap;
    word-break: break-all;
  }
  #output .error {
    color: #ff6b6b;
  }
  .toolbar {
    display: flex;
    gap: 8px;
    padding: 12px 16px;
    border-top: 1px solid rgba(255,255,255,0.1);
    flex-wrap: wrap;
  }
  .btn {
    padding: 8px 20px;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    font-family: inherit;
  }
  .btn-run {
    background: linear-gradient(90deg, #64ffda, #48b1bf);
    color: #1a1a2e;
  }
  .btn-run:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 15px rgba(100,255,218,0.3);
  }
  .btn-run:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    transform: none;
  }
  .btn-stop {
    background: linear-gradient(90deg, #ff6b6b, #ee5a24);
    color: #fff;
  }
  .btn-stop:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 15px rgba(255,107,107,0.3);
  }
  .btn-clear {
    background: rgba(255,255,255,0.1);
    color: #e0e0e0;
  }
  .btn-clear:hover {
    background: rgba(255,255,255,0.2);
  }
  .btn-example {
    background: rgba(100,255,218,0.1);
    color: #64ffda;
    border: 1px solid rgba(100,255,218,0.3);
    font-size: 12px;
    padding: 4px 12px;
  }
  .btn-example:hover {
    background: rgba(100,255,218,0.2);
  }
  .status {
    font-size: 12px;
    color: #8892b0;
    padding: 0 16px;
  }
  .status .dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    margin-right: 6px;
  }
  .status .dot.online { background: #64ffda; }
  .status .dot.offline { background: #ff6b6b; }
  ::-webkit-scrollbar { width: 8px; height: 8px; }
  ::-webkit-scrollbar-track { background: rgba(0,0,0,0.2); }
  ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.2); border-radius: 4px; }
  ::-webkit-scrollbar-thumb:hover { background: rgba(255,255,255,0.3); }
</style>
</head>
<body>
<div class="header">
  <div>
    <h1>明道语言 Playground</h1>
    <div class="subtitle">明明白白写代码，探索编程之道。</div>
  </div>
  <div class="links">
    <a href="#" onclick="loadExample('hello')">Hello</a>
    <a href="#" onclick="loadExample('fib')">斐波那契</a>
    <a href="#" onclick="loadExample('loop')">循环</a>
    <a href="#" onclick="loadExample('sort')">冒泡排序</a>
    <a href="#" onclick="loadExample('pascal')">杨辉三角</a>
    <a href="#" onclick="loadExample('sieve-old')">素数筛(原始)</a>
    <a href="#" onclick="loadExample('sieve')">素数筛(优化)</a>
    <a href="#" onclick="loadExample('hanoi-nospace')">汉诺塔(无空格)</a>
  </div>
</div>

<div class="main">
  <div class="panel">
    <div class="panel-header">
      <span>代码编辑器</span>
      <span class="status"><span class="dot online"></span>明道 v1.0</span>
    </div>
    <div class="panel-body">
      <textarea id="code-input" spellcheck="false">打印, "你好，明道世界！"</textarea>
    </div>
    <div class="toolbar">
      <button class="btn btn-run" id="run-btn" onclick="runCode()">▶ 运行</button>
      <button class="btn btn-stop" id="stop-btn" onclick="stopCode()" style="display:none">⏹ 停止</button>
      <button class="btn btn-clear" onclick="clearOutput()">清空输出</button>
      <button class="btn btn-example" onclick="loadExample('hanoi')">汉诺塔</button>
      <button class="btn btn-example" onclick="loadExample('hanoi-nospace')">汉诺塔(无空格)</button>
      <button class="btn btn-example" onclick="loadExample('turing')">图灵机</button>
      <button class="btn btn-example" onclick="loadExample('pascal')">杨辉三角</button>
      <button class="btn btn-example" onclick="loadExample('sieve-old')">素数筛(原始)</button>
      <button class="btn btn-example" onclick="loadExample('sieve')">素数筛(优化)</button>
    </div>
  </div>
  <div class="panel">
    <div class="panel-header">
      <span>运行结果</span>
      <span class="status" id="exec-status">就绪</span>
    </div>
    <div class="panel-body">
      <div id="output">等待运行...</div>
    </div>
  </div>
</div>

<script>
const examples = {
  hello: '打印, "你好，明道世界！"\n\n定义 x 就是 42\n3 加 4, 打印',
  fib: `定义 斐波那契 就是函 n：
    如果 n 小于等于 1 那么：
        返回 n
    定义 a 就是 0
    定义 b 就是 1
    对于 i 从 2 到 n 加 1：
        定义 temp 就是 a 加 b
        赋值 a 为 b
        赋值 b 为 temp
    返回 b

对于 i 从 0 到 41：
    斐波那契, i, 打印`,
  hanoi: `定义 汉诺塔 就是函 n, 源, 目标, 辅助：
    如果 n 等于 0 那么：
        返回
    否则：
        汉诺塔, n 减 1, 源, 辅助, 目标
        定义 消息 就是 消息拼接, "从 ", 源, " 移动到 ", 目标
        打印, 消息
        汉诺塔, n 减 1, 辅助, 目标, 源

汉诺塔, 3, "A", "C", "B"`,
  'hanoi-nospace': `定义汉诺塔就是函n,源,目标,辅助：
 如果n等于0那么：
  返回
 否则：
  汉诺塔,(n,减,1),源,辅助,目标
  定义消息就是消息拼接,"从",源,"移动到",目标
  打印,消息
  汉诺塔,(n,减,1),辅助,目标,源

汉诺塔,3,"A","C","B"`,
  loop: `定义 n 就是 1
当满足 n 小于等于 5 那么：
    打印, n
    赋值 n 为 n 加 1

打印, "--- 循环结束 ---"`,
  sort: `定义 冒泡排序 就是函 arr：
    定义 n 就是 arr, 长度
    对于 i 从 0 到 n 减 1：
        对于 j 从 0 到 n 减 1 减 i：
            如果 arr, j, 索引 大于 arr, j 加 1, 索引 那么：
                定义 当前 就是 索引, arr, j
                定义 下一个 就是 索引, arr, j 加 1
                赋值 arr 为 列表修改, arr, j, 下一个
                赋值 arr 为 列表修改, arr, j 加 1, 当前
    返回 arr

定义 数据 就是 列表 5, 3, 8, 1, 9, 2
数据, 冒泡排序, 打印`,
  turing: `定义 运行 就是函 状态, 纸带, 位置, 规则表：
    定义 当前符号 就是 索引, 纸带, 位置
    如果 当前符号 等于 空值 那么：
        返回 纸带
    定义 索引位置 就是 2 乘 状态 加 当前符号
    定义 规则 就是 索引, 规则表, 索引位置
    如果 规则 等于 空值 那么：
        返回 纸带
    否则：
        定义 写入 就是 索引, 规则, 0
        定义 移动 就是 索引, 规则, 1
        定义 新状态 就是 索引, 规则, 2
        赋值 纸带 为 列表修改, 纸带, 位置, 写入
        如果 移动 等于 1 那么：
            赋值 位置 为 位置 加 1
        否则：
            赋值 位置 为 位置 减 1
        运行, 新状态, 纸带, 位置, 规则表

定义 纸带 就是 列表 1, 0, 1, 0, 0, 1, 1, 0
定义 规则表 就是 列表
    列表 1, 1, 0,
    列表 0, 1, 1,
    列表 1, 1, 1,
    列表 0, 0, 2
定义 结果 就是 运行, 0, 纸带, 0, 规则表
打印, 结果`,
  pascal: `定义 下一行 就是函 当前行：
    定义 n 就是 当前行, 长度
    定义 新行 就是 列表 1
    对于 j 从 0 到 n 减 1：
        定义 左 就是 索引, 当前行, j
        定义 右 就是 索引, 当前行, j 加 1
        定义 和 就是 左 加 右
        赋值 新行 为 列表修改, 新行, j 加 1, 和
    赋值 新行 为 列表修改, 新行, n, 1
    返回 新行

定义 杨辉三角 就是函 行数：
    定义 当前行 就是 列表 1
    当前行, 打印
    对于 i 从 1 到 行数 加 1：
        赋值 当前行 为 下一行, 当前行
        当前行, 打印

杨辉三角, 8`,
  sieve: `消息拼接, "═══════════════════════════════════════", 打印
消息拼接, "  【素数筛 · 优化版】", 打印
消息拼接, "  优化①：只检查到 √n，而非一直检查到 n", 打印
消息拼接, "        (整数开方函数将检查范围从 O(n) 降到 O(√n))", 打印
消息拼接, "  优化②：单独处理偶数 2，之后只检查奇数", 打印
消息拼接, "        (跳过一半的检查量)", 打印
消息拼接, "  优化③：找到因数后立即跳出循环", 打印
消息拼接, "        (提前终止，避免不必要的计算)", 打印
消息拼接, "  时间复杂度：O(n√n)  参数：10000", 打印
消息拼接, "═══════════════════════════════════════", 打印

定义 整数开方 就是函 n：
    定义 结果 就是 0
    对于 i 从 1 到 n 加 1：
        如果 i 乘 i 大于 n 那么：
            跳出
        赋值 结果 为 i
    返回 结果

定义 是素数判断 就是函 n：
    如果 n 小于 2 那么：
        返回 假值
    如果 n 等于 2 那么：
        返回 真值
    如果 n 模 2 等于 0 那么：
        返回 假值
    定义 上限 就是 整数开方, n
    定义 结果 就是 真值
    对于 i 从 3 到 上限 加 1：
        如果 n 模 i 等于 0 那么：
            赋值 结果 为 假值
            跳出
    返回 结果

定义 素数筛 就是函 上限：
    定义 标题 就是 消息拼接, "2 到 ", 上限, " 之间的素数："
    打印, 标题
    2, 打印
    对于 i 从 3 到 上限 加 1：
        如果 (是素数判断, i) 等于 真值 那么：
            i, 打印

素数筛, 10000`,
  'sieve-old': `定义 是素数判断 就是函 n：
    如果 n 小于 2 那么：
        返回 假值
    定义 结果 就是 真值
    对于 i 从 2 到 n 减 1：
        如果 n 模 i 等于 0 那么：
            赋值 结果 为 假值
    返回 结果

定义 素数筛 就是函 上限：
    定义 标题 就是 消息拼接, "2 到 ", 上限, " 之间的素数："
    打印, 标题
    对于 i 从 2 到 上限 加 1：
        如果 (是素数判断, i) 等于 真值 那么：
            i, 打印

素数筛, 1000`
};

function loadExample(name) {
  const ta = document.getElementById('code-input');
  if (examples[name]) {
    ta.value = examples[name];
    ta.style.minHeight = Math.max(350, examples[name].split('\\n').length * 22) + 'px';
  }
}

function clearOutput() {
  document.getElementById('output').textContent = '等待运行...';
  document.getElementById('exec-status').textContent = '就绪';
  document.getElementById('output').className = '';
}

async function runCode() {
  const code = document.getElementById('code-input').value;
  if (!code.trim()) return;
  const btn = document.getElementById('run-btn');
  const stopBtn = document.getElementById('stop-btn');
  const output = document.getElementById('output');
  const status = document.getElementById('exec-status');
  btn.disabled = true;
  btn.textContent = '⏳ 运行中...';
  stopBtn.style.display = 'inline-block';
  status.textContent = '运行中...';
  output.textContent = '';
  output.className = '';
  try {
    const resp = await fetch('/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'code=' + encodeURIComponent(code)
    });
    const text = await resp.text();
    if (text === '#t') {
      output.textContent = '(无输出)';
    } else {
      output.textContent = text;
    }
    status.textContent = '✓ 完成';
  } catch (e) {
    output.textContent = '连接错误: ' + e.message;
    output.className = 'error';
    status.textContent = '✗ 错误';
  } finally {
    btn.disabled = false;
    btn.textContent = '▶ 运行';
    stopBtn.style.display = 'none';
  }
}

async function stopCode() {
  const stopBtn = document.getElementById('stop-btn');
  stopBtn.disabled = true;
  stopBtn.textContent = '⏳ 正在停止...';
  try {
    await fetch('/stop', { method: 'POST' });
  } catch (e) {
    // 忽略 stop 请求的错误
  }
  const output = document.getElementById('output');
  const status = document.getElementById('exec-status');
  output.textContent += '\n⏹ 正在停止...';
  status.textContent = '正在停止';
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

;; 处理 /run 请求
(define (handle-run req)
  (with-handlers ([exn:fail? (λ (e)
      (response/full 500 #"Error" (current-seconds)
                     #"text/plain; charset=utf-8" '()
                     (list (string->bytes/utf-8
                            (format "~a" (exn-message e))))))])
    (define body-bytes (or (request-post-data/raw req) #""))
    (define body-str (bytes->string/utf-8 body-bytes))
    (displayln (format "收到 POST body: ~a" body-str) (current-error-port))
    (define code-str
      (let* ([pairs (regexp-split #px"&" body-str)]
             [code-pair (findf (λ (s) (string-prefix? s "code=")) pairs)])
        (if code-pair
            (let* ([encoded (substring code-pair 5)]
                   ;; 将 + 转换为空格（form-urlencoded 标准）
                   [with-spaces (regexp-replace* #px"\\+" encoded " ")]
                   [decoded (uri-decode with-spaces)])
              decoded)
            #f)))
    (define output
      (with-handlers ([exn:fail? (λ (e) (format "错误: ~a" (exn-message e)))])
        (if code-str
            (eval-mingdao-with-stop code-str)
            "缺少 code 参数")))
    (response/full 200 #"OK" (current-seconds)
                   #"text/plain; charset=utf-8" '()
                   (list (if (string=? output "")
                             #"#t"
                             (string->bytes/utf-8 output))))))

;; 处理 /stop 请求
(define (handle-stop req)
  (when current-eval-thread
    (displayln "正在中断求值线程..." (current-error-port))
    (break-thread current-eval-thread)
    (set! current-eval-thread #f))
  (response/full 200 #"OK" (current-seconds)
                 #"text/plain; charset=utf-8" '()
                 (list #"stopped")))

;; 主页
(define (start req)
  (define method (request-method req))
  (define uri (request-uri req))
    (define path (url-path uri))
    (define path-strs (map path/param-path path))
    (displayln (format "请求: ~s 路径:~a" method path-strs) (current-error-port))
    (cond
      [(and (bytes=? method #"POST")
            (= (length path-strs) 1)
            (equal? (car path-strs) "run"))
     (handle-run req)]
    [(and (bytes=? method #"POST")
            (= (length path-strs) 1)
            (equal? (car path-strs) "stop"))
     (handle-stop req)]
    [else
     (response/full 200 #"OK" (current-seconds)
                    #"text/html; charset=utf-8" '()
                    (list (string->bytes/utf-8 page-template)))]))

;; 启动服务
(define (main)
  (printf "明道语言 Playground 启动中...\n")
  (printf "访问地址: http://localhost:8080\n")
  (printf "按 Ctrl+C 停止服务器\n")
  (serve/servlet start
   #:port 8080
   #:servlet-path "/"
   #:servlet-regexp #rx"^/"
   #:server-root-path (current-directory)
   #:launch-browser? #f))

(main)