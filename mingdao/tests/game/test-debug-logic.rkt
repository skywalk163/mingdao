#lang racket/base
(require racket/string
         racket/port
         racket/file
         racket/path
         racket/list
         (file "../../lang/tokenizer.rkt")
         (file "../../lang/parser.rkt"))

(define script-path (path->complete-path (find-system-path 'run-file) (current-directory)))
(current-directory (build-path (path-only script-path) ".." ".."))

;; 模拟导入：仅注册前面模块的函数，不注册logic自身的
(define known-funcs '())
(for ([path '("examples/plane-shooter/helper.mingdao"
              "examples/plane-shooter/state.mingdao"
              "examples/plane-shooter/drawing.mingdao")])
  (define code (port->string (open-input-file (build-path (current-directory) path))))
  (for ([line (in-list (string-split code "\n"))])
    (define trimmed (string-trim line))
    (when (and (string-prefix? trimmed "定义 ")
               (string-contains? trimmed "就是函"))
      (define parts (string-split trimmed))
      (set! known-funcs (cons (list-ref parts 1) known-funcs)))))

(printf "已注册函数 (~a 个): ~a~n~n" (length known-funcs) known-funcs)

;; 逐个语句解析logic.mingdao
(define code (port->string (open-input-file
  (build-path (current-directory) "examples/plane-shooter/logic.mingdao"))))

;; 用整体tokenize+解析来捕获错误
(define tokens (tokenize code))
(printf "总令牌数: ~a~n" (length tokens))

(with-handlers ([exn:fail? (lambda (e)
                             (printf "错误: ~a~n" (exn-message e))
                             (printf "~n=== 重新尝试: 先注册logic自身的函数 ===~n")
                             ;; Now add logic's own functions
                             (define logic-code (port->string (open-input-file
                               (build-path (current-directory) "examples/plane-shooter/logic.mingdao"))))
                             (for ([line (in-list (string-split logic-code "\n"))])
                               (define trimmed (string-trim line))
                               (when (and (string-prefix? trimmed "定义 ")
                                          (string-contains? trimmed "就是函"))
                                 (define parts (string-split trimmed))
                                 (set! known-funcs (cons (list-ref parts 1) known-funcs))))
                             (printf "已注册函数 (~a 个): ~a~n" (length known-funcs) known-funcs)
                             (define ast (parse tokens known-funcs))
                             (printf "解析成功! ~a 个表达式~n" (length ast)))])
  (define ast (parse tokens known-funcs))
  (printf "解析成功! ~a 个表达式~n" (length ast)))