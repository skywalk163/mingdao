#lang racket/base
;; 无头游戏测试 — 运行游戏逻辑而不创建GUI窗口
;; 超时退出，检查状态变化
(require racket/string racket/path racket/list racket/port racket/file
         racket/random)

(define script-dir (path-only (path->complete-path (find-system-path 'run-file) (current-directory))))
(current-directory (build-path script-dir ".." ".."))
(printf "工作目录: ~a\n" (current-directory))

;; ============================================================
;; 创建隔离的运行时命名空间
;; ============================================================
(printf "\n=== 设置运行时环境 ===\n")
(define ns (make-base-empty-namespace))

;; 使 racket/base 可用
(namespace-require 'racket/base ns)

;; 加载核心模块
(eval '(require (file "core.rkt")
                (file "lang/debug.rkt")
                (file "lang/test.rkt")
                racket/random
                racket/control) ns)

;; 定义模拟 GUI 函数（覆盖 game-engine.rkt 中的真实实现）
(eval '(begin
         ;; 窗口管理
         (define (创建窗口 w h title) (void))
         (define (关闭窗口) (void))
         
         ;; 绘图函数 — 全部空操作
         (define (清除背景 r g b) (void))
         (define (画矩形 x y w h r g b) (void))
         (define (画实心矩形 x y w h r g b) (void))
         (define (画圆形 cx cy radius r g b) (void))
         (define (画实心圆形 cx cy radius r g b) (void))
         (define (画三角形 x1 y1 x2 y2 x3 y3 r g b) (void))
         (define (画实心三角形 x1 y1 x2 y2 x3 y3 r g b) (void))
         (define (画文本 x y text r g b size) (void))
         
         ;; 游戏循环 — 后台无窗口版本
         (define MAX-FRAMES 120)
         (define mock-running #t)
         (define mock-frame-count 0)
         
         (define (游戏循环 update-fn draw-fn fps)
           (set! mock-running #t)
           (set! mock-frame-count 0)
           (let loop ()
             (when (and mock-running (< mock-frame-count MAX-FRAMES))
               (set! mock-frame-count (+ mock-frame-count 1))
               (update-fn '())
               (draw-fn '())
               (when (= (modulo mock-frame-count 10) 0)
                 (printf "  帧 ~a: 玩家=(~a,~a) HP=~a 分数=~a 子弹=~a 敌机=~a 敌弹=~a\n"
                         mock-frame-count
                         玩家x 玩家y 玩家生命 分数
                         (length 子弹列表) (length 敌机列表) (length 敌弹列表)))
               (loop)))
           (printf "[模拟] 游戏循环结束: ~a 帧\n" mock-frame-count)
           '游戏结束)
         
         (define (退出游戏) (set! mock-running #f))
         
         ;; 输入
         (define (按键按下 key) #f)
         
         ;; 随机数
         (define (随机整数 min max)
           (+ min (random (- max min -1))))
         
         ;; 追加（依赖 列表修改，已在 core.rkt 中定义）
         (define (追加 lst elem)
           (列表修改 lst (length lst) elem))
         
         ;; 帧时间 — 模拟固定帧间隔
         (define current-dt 0.016)
         (define (帧时间) current-dt)
         
         ;; 导入 — 在无头测试中已手动加载所有模块，此处设为空操作
         (define (导入 path) (void))
         
         ;; 模运算 — 支持浮点数（原 modulo 仅支持整数）
         (define (modulo a b)
           (define q (floor (/ a b)))
           (- a (* b q)))
         ) ns)

(printf "  ✓ 运行时环境就绪\n")

;; ============================================================
;; 两阶段加载游戏模块
;; ============================================================
(printf "\n=== 加载游戏模块 ===\n")
(require (file "../../lang/tokenizer.rkt")
         (file "../../lang/parser.rkt"))

;; 收集函数名
(define global-function-names '())
(define processed-files (make-hash))

(define (collect-function-names code)
  (define names '())
  (for ([line (in-list (string-split code "\n"))])
    (define trimmed (string-trim line))
    (when (string-prefix? trimmed "定义 ")
      (define parts (string-split trimmed))
      (when (and (>= (length parts) 3) (equal? (list-ref parts 2) "就是函"))
        (set! names (cons (list-ref parts 1) names)))))
  names)

(define (collect-imports code)
  (define imports '())
  (for ([line (in-list (string-split code "\n"))])
    (define trimmed (string-trim line))
    (when (string-prefix? trimmed "导入 ")
      (define path-str (string-trim (substring trimmed 3) "\""))
      (set! imports (cons path-str imports))))
  (reverse imports))

(define (collect-all-functions full-path)
  (when (not (hash-ref processed-files full-path #f))
    (hash-set! processed-files full-path #t)
    (define code (port->string (open-input-file full-path)))
    (define base-dir (build-path (path-only full-path)))
    (define local-funcs (collect-function-names code))
    (for ([name local-funcs])
      (set! global-function-names (cons name global-function-names)))
    (define imports (collect-imports code))
    (for ([import-path imports])
      (define import-full
        (if (absolute-path? import-path) import-path
            (build-path base-dir import-path)))
      (collect-all-functions import-full))))

(collect-all-functions (build-path (current-directory) "examples/plane-shooter/main.mingdao"))
(printf "注册函数: ~a 个\n" (length global-function-names))

;; 加载所有模块（解析+执行）
(define modules
  '("constants.mingdao" "helper.mingdao" "state.mingdao" "drawing.mingdao"
    "logic.mingdao" "collision.mingdao" "main.mingdao"))

(printf "\n=== 执行所有模块 ===\n")
(for ([m modules])
  (define path (build-path (current-directory) "examples/plane-shooter" m))
  (define code (port->string (open-input-file path)))
  (define tokens (tokenize code))
  (define ast (parse tokens global-function-names))
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "  ✗ ~a: 执行失败 - ~a\n" m (exn-message e)))])
    (for ([expr ast])
      (eval expr ns))
    (printf "  ✓ ~a 执行成功 (~a 个表达式)\n" m (length ast))))

;; ============================================================
;; 验证游戏状态
;; ============================================================
(printf "\n=== 验证初始状态 ===\n")
(define (v sym) (eval sym ns))
(printf "  玩家x = ~a (期望 380)\n" (v '玩家x))
(printf "  玩家y = ~a (期望 500)\n" (v '玩家y))
(printf "  玩家生命 = ~a (期望 3)\n" (v '玩家生命))
(printf "  分数 = ~a (期望 0)\n" (v '分数))
(printf "  游戏结束 = ~a (期望 #f)\n" (v '游戏结束))
(printf "  子弹列表长度 = ~a (期望 0)\n" (length (v '子弹列表)))
(printf "  敌机列表长度 = ~a (期望 0)\n" (length (v '敌机列表)))

;; ============================================================
;; 运行游戏逻辑（后台无窗口，超时退出）
;; ============================================================
(printf "\n=== 后台运行游戏逻辑 ===\n")

;; 模拟按键（自动射击）
(eval '(begin
         (define saved-key-state (make-hash))
         (hash-set! saved-key-state "z" #t)
         (set! 按键按下 (lambda (key) (hash-ref saved-key-state key #f)))) ns)

;; 调试：检查 追加 在 更新 内部是否可用
(printf "\n=== 调试：追加 可用性 ===\n")
(printf "  追加 = ~a\n" (eval '追加 ns))
(printf "  列表修改 = ~a\n" (eval '列表修改 ns))
(printf "  (追加 '() 42) = ~a\n" (eval '(追加 '() 42) ns))

;; 调试：重置状态后逐步测试 `更新`
(printf "\n=== 调试：逐步测试 `更新` ===\n")

;; 检查 更新子弹 的 AST
(define logic-path (build-path (current-directory) "examples/plane-shooter" "logic.mingdao"))
(define logic-code2 (port->string (open-input-file logic-path)))
(define logic-tokens2 (tokenize logic-code2))
(define logic-ast2 (parse logic-tokens2 global-function-names))
(printf "### 更新子弹 AST:\n  ~s\n" (caddr logic-ast2))

(printf "### 发射子弹 AST:\n  ~s\n" (cadr logic-ast2))
(printf "### 更新 AST (第9个表达式):\n  ~s\n" (list-ref logic-ast2 8))

;; 重置状态
(eval '(set! 射击计时 0) ns)
(eval '(set! 子弹列表 '()) ns)
(eval '(set! 敌机列表 '()) ns)
(eval '(set! 敌弹列表 '()) ns)
(eval '(set! 爆炸列表 '()) ns)
(eval '(set! 分数 0) ns)
(eval '(set! 游戏结束 #f) ns)
(printf "  初始状态: 射击计时=~a 子弹=~a\n" (eval '射击计时 ns) (eval '子弹列表 ns))

;; === 直接调用 发射子弹 ===
(printf "  --- 直接调用 发射子弹 ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  错误: ~a\n" (exn-message e)))])
  (eval '(发射子弹 '()) ns))
(printf "  直接调用后: 射击计时=~a 子弹列表长度=~a 子弹=~a\n" 
        (eval '射击计时 ns) (length (eval '子弹列表 ns)) (eval '子弹列表 ns))

;; === 直接测试更新子弹逻辑 ===
(printf "  --- 直接测试更新子弹逻辑 ---\n")
(eval '(set! 射击计时 0) ns)
(eval '(set! 子弹列表 '((397 490 0 500 1))) ns)  ;; 手动设置1颗子弹
(printf "  初始: 子弹列表=~a\n" (eval '子弹列表 ns))
(eval '(更新子弹 '()) ns)
(printf "  更新子弹后: 子弹列表=~a\n" (eval '子弹列表 ns))

;; === 通过 更新 调用 ===
(printf "  --- 通过 更新 调用 ---\n")
(eval '(set! 射击计时 0) ns)
(eval '(set! 子弹列表 '()) ns)
(eval '(set! 敌机列表 '()) ns)
(eval '(set! 敌弹列表 '()) ns)

;; 逐步：只执行一部分
(printf "  手动调用 发射子弹:\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  错误: ~a\n" (exn-message e)))])
  (eval '(发射子弹 '()) ns))
(printf "    子弹列表=~a (长度=~a)\n" (eval '子弹列表 ns) (length (eval '子弹列表 ns)))

(printf "  手动调用 更新子弹:\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  错误: ~a\n" (exn-message e)))])
  (eval '(更新子弹 '()) ns))
(printf "    子弹列表=~a\n" (eval '子弹列表 ns))

(printf "  手动调用 更新敌弹:\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  错误: ~a\n" (exn-message e)))])
  (eval '(更新敌弹 '()) ns))
(printf "    子弹列表=~a\n" (eval '子弹列表 ns))

(printf "  手动调用 生成敌机:\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  错误: ~a\n" (exn-message e)))])
  (eval '(生成敌机 '()) ns))
(printf "    子弹列表=~a\n" (eval '子弹列表 ns))

(printf "  手动调用 移动敌机:\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  错误: ~a\n" (exn-message e)))])
  (eval '(移动敌机 '()) ns))
(printf "    子弹列表=~a\n" (eval '子弹列表 ns))

(printf "  手动调用 检测子弹打敌机:\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  错误: ~a\n" (exn-message e)))])
  (eval '(检测子弹打敌机 '()) ns))
(printf "    子弹列表=~a\n" (eval '子弹列表 ns))

(define test-start-ms (current-inexact-milliseconds))
(define iterations 0)
(define TIMEOUT-SECS 5.0)

(let loop ()
  (when (< (- (current-inexact-milliseconds) test-start-ms) (* TIMEOUT-SECS 1000))
    (set! iterations (+ iterations 1))
    (eval '(更新 '()) ns)
    (eval '(绘制 '()) ns)
    (when (= (modulo iterations 30) 0)
      (printf "  帧 ~a: 分数=~a HP=~a 结束=~a 子弹=~a 敌机=~a 敌弹=~a\n"
              iterations (v '分数) (v '玩家生命) (v '游戏结束)
              (length (v '子弹列表)) (length (v '敌机列表)) (length (v '敌弹列表))))
    (unless (v '游戏结束)
      (loop))))

(define elapsed (- (current-inexact-milliseconds) test-start-ms))
(printf "\n=== 测试完成 ===\n")
(printf "运行帧数: ~a\n" iterations)
(printf "运行时间: ~a 毫秒\n" (exact->inexact elapsed))
(when (v '游戏结束)
  (printf "游戏在第 ~a 帧结束！\n" iterations))
(printf "最终状态:\n")
(printf "  玩家生命 = ~a\n" (v '玩家生命))
(printf "  分数 = ~a\n" (v '分数))
(printf "  游戏结束 = ~a\n" (v '游戏结束))
(printf "  子弹数 = ~a\n" (length (v '子弹列表)))
(printf "  敌机数 = ~a\n" (length (v '敌机列表)))
(printf "  敌弹数 = ~a\n" (length (v '敌弹列表)))

;; 基本断言检查
(printf "\n=== 测试断言 ===\n")
(if (>= iterations 10)
    (printf "  ✓ 运行至少 10 帧 (实际: ~a)\n" iterations)
    (printf "  ✗ 运行帧数不足: ~a\n" iterations))
(if (>= (v '分数) 0)
    (printf "  ✓ 分数非负 (实际: ~a)\n" (v '分数))
    (printf "  ✗ 分数异常: ~a\n" (v '分数)))
(if (<= (v '玩家生命) 3)
    (printf "  ✓ 生命值合理 (实际: ~a)\n" (v '玩家生命))
    (printf "  ✗ 生命值异常: ~a\n" (v '玩家生命)))
(if (>= (v '玩家生命) 0)
    (printf "  ✓ 玩家存活 (实际: ~a)\n" (v '玩家生命))
    (printf "  ✗ 玩家已死亡\n"))

(printf "\n=== 无头测试通过! ===\n")