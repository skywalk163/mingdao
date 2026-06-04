#lang racket/base

(require racket/string
         racket/port
         racket/file
         racket/path
         racket/list
         (file "../../lang/tokenizer.rkt")
         (file "../../lang/parser.rkt"))

;; ============================================================
;; 模块化解析测试：逐一测试每个模块文件
;; ============================================================

;; 切换到 mingdao 根目录（脚本在 mingdao/examples/plane-shooter/tests/ 下）
(define script-path (path->complete-path (find-system-path 'run-file) (current-directory)))
(current-directory (build-path (path-only script-path) ".." ".."))

;; 扫描所有模块，收集用户定义的函数名
(define (collect-function-names path)
  (define code (with-input-from-file path (lambda () (port->string))))
  (define lines (string-split code "\n"))
  (define names '())
  (for ([line lines])
    (define trimmed (string-trim line))
    (when (string-prefix? trimmed "定义 ")
      ;; 匹配 "定义 函数名 就是函" 模式
      (define parts (string-split trimmed))
      (when (and (>= (length parts) 3)
                 (equal? (list-ref parts 2) "就是函"))
        (set! names (cons (list-ref parts 1) names)))))
  names)

(define all-module-paths
  '("examples/plane-shooter/constants.mingdao"
    "examples/plane-shooter/helper.mingdao"
    "examples/plane-shooter/state.mingdao"
    "examples/plane-shooter/drawing.mingdao"
    "examples/plane-shooter/logic.mingdao"
    "examples/plane-shooter/collision.mingdao"    
    "examples/plane-shooter/main.mingdao"))

;; 收集所有用户定义函数名
(define all-user-functions
  (apply append (map collect-function-names all-module-paths)))

(printf "用户定义函数: ~a~n~n" all-user-functions)

(define (test-module name path)
  (printf "=== 测试模块: ~a ===~n" name)
  (define code (with-input-from-file path (lambda () (port->string))))
  (printf "  文件大小: ~a 字符~n" (string-length code))
  (define tokens (tokenize code))
  (printf "  词法单元数: ~a~n" (length tokens))
  (define ast (parse tokens all-user-functions))
  (printf "  AST 表达式数: ~a~n" (length ast))
  
  ;; 统计定义、函数调用等
  (define define-count 0)
  (define call-count 0)
  (define import-count 0)
  (define export-count 0)
  (for ([expr ast])
    (cond
      [(and (list? expr) (eq? (car expr) 'define)) (set! define-count (add1 define-count))]
      [(and (list? expr) (eq? (car expr) 'mingdao-import)) (set! import-count (add1 import-count))]
      [(and (list? expr) (eq? (car expr) 'mingdao-export)) (set! export-count (add1 export-count))]
      [(list? expr) (set! call-count (add1 call-count))]))
  (printf "  define: ~a, 函数调用: ~a, 导入: ~a, 导出: ~a~n"
          define-count call-count import-count export-count)
  
  ;; 显示前5个表达式概要
  (printf "  前5个表达式:~n")
  (for ([expr (take ast (min 5 (length ast)))])
    (cond
      [(and (list? expr) (eq? (car expr) 'define))
       (printf "    [定义] ~a~n" (cadr expr))]
      [(and (list? expr) (eq? (car expr) 'mingdao-import))
       (printf "    [导入] ~a~n" (cadr expr))]
      [(and (list? expr) (eq? (car expr) 'mingdao-export))
       (printf "    [导出] ~a~n" (cdr expr))]
      [else
       (printf "    [调用] ~a~n" (car expr))]))
  (printf "  [OK] ~a 解析通过~n~n" name))

(printf "~n========================================~n")
(printf "飞机射击游戏 - 模块解析测试~n")
(printf "========================================~n~n")

;; 测试每个模块
(test-module "constants" "examples/plane-shooter/constants.mingdao")
(test-module "helper" "examples/plane-shooter/helper.mingdao")
(test-module "state" "examples/plane-shooter/state.mingdao")
(test-module "drawing" "examples/plane-shooter/drawing.mingdao")
(test-module "logic" "examples/plane-shooter/logic.mingdao")
(test-module "collision" "examples/plane-shooter/collision.mingdao")

;; ============================================================
;; SVO 语序逻辑测试
;; ============================================================

(printf "=== SVO 语序逻辑测试 ===~n")

(define (test-svo desc code)
  (printf "  测试: ~a~n" desc)
  (printf "    输入: ~a~n" (string-trim code))
  (define tokens (tokenize code))
  (define ast (parse tokens))
  (for ([expr ast])
    (printf "    输出: ~s~n" expr))
  (printf "    [OK]~n"))

;; 测试 SVO 索引语法（SOV 顺序）
(test-svo "SOV: 子弹, 0, 索引"
          "定义 bx 就是 子弹, 0, 索引\n")

(test-svo "SOV: 敌机, 2, 索引"
          "定义 vx 就是 敌机, 2, 索引\n")

(test-svo "VSO: 索引, 列表, i"
          "定义 item 就是 索引, 列表, i\n")

;; 测试函数调用 - 注册的函数
(test-svo "函数调用: 打印, 你好"
          "打印, 你好\n")

(test-svo "函数调用: 创建窗口, 800, 600, title"
          "创建窗口, 800, 600, title\n")

;; 测试列表创建
(test-svo "列表创建: 列表 1, 2, 3"
          "定义 lst 就是 列表 1, 2, 3\n")

;; 测试追加拆分后的语法
(test-svo "追加两步: 定义列表 + 追加"
          "定义 新子弹 就是 列表 1, 2, 3\n追加, 子弹列表, 新子弹\n")

;; 测试空值
(test-svo "空值参数: 重置游戏, 空值"
          "重置游戏, 空值\n")

(printf "~n=== 所有模块解析测试完成 ===~n")

;; ============================================================
;; 集成测试说明
;; ============================================================

(printf "~n=== 集成测试（加载并执行）===~n")
(printf "跳过集成执行测试，因为需要创建窗口（GUI 环境）~n")
(printf "请通过以下方式运行完整游戏：~n")
(printf "  cd mingdao~n")
(printf "  racket -e '(require \"main.rkt\") (导入 \"examples/plane-shooter/main.mingdao\")'~n")
(printf "~n=== 所有测试通过 ===~n")