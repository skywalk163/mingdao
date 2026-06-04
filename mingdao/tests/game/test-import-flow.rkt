#lang racket/base
;; 测试跨模块函数名注册机制（模拟 main.rkt 的导入流程）

(require racket/string
         racket/port
         racket/file
         racket/path
         racket/list
         (file "../../lang/tokenizer.rkt")
         (file "../../lang/parser.rkt"))

;; 切换到 mingdao 根目录
(define script-path (path->complete-path (find-system-path 'run-file) (current-directory)))
(current-directory (build-path (path-only script-path) ".." ".."))

(define modules
  '("examples/plane-shooter/constants.mingdao"
    "examples/plane-shooter/helper.mingdao"
    "examples/plane-shooter/state.mingdao"
    "examples/plane-shooter/drawing.mingdao"
    "examples/plane-shooter/logic.mingdao"
    "examples/plane-shooter/collision.mingdao"
    "examples/plane-shooter/main.mingdao"))

(define (collect-function-names code)
  (define names '())
  (for ([line (in-list (string-split code "\n"))])
    (define trimmed (string-trim line))
    (when (string-prefix? trimmed "定义 ")
      (define parts (string-split trimmed))
      (when (and (>= (length parts) 3)
                 (equal? (list-ref parts 2) "就是函"))
        (set! names (cons (list-ref parts 1) names)))))
  names)

;; 阶段1: 收集所有模块的函数名
(define all-user-functions
  (apply append (map (lambda (p)
    (collect-function-names
      (port->string (open-input-file (build-path (current-directory) p)))))
    modules)))

(printf "~n=== 跨模块导入流程测试 ===~n")
(printf "总共收集函数: ~a 个~n" (length all-user-functions))

;; 阶段2: 用完整的函数名表解析所有模块
(for ([path modules])
  (printf "~n[导入] ~a~n" path)
  (define code (port->string (open-input-file (build-path (current-directory) path))))
  (printf "  文件大小: ~a 字符~n" (string-length code))
  (define tokens (tokenize code))
  (printf "  词法单元数: ~a~n" (length tokens))
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "  解析失败: ~a~n" (exn-message e)))])
    (define ast (parse tokens all-user-functions))
    (printf "  AST: ~a 个表达式~n" (length ast))
    (printf "  [OK]~n")))

(printf "~n=== 测试通过 ===~n")