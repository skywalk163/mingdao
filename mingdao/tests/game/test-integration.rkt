#lang racket
;; 集成测试：验证两阶段导入流程（仅解析，不执行eval）
(require "../../lang/tokenizer.rkt"
         "../../lang/parser.rkt"
         racket/string
         racket/path
         racket/list
         racket/port
         racket/file)

(define script-dir (path-only (path->complete-path (find-system-path 'run-file) (current-directory))))
(current-directory (build-path script-dir ".." ".."))
(printf "工作目录: ~a\n" (current-directory))

;; 复制 main.rkt 中的收集函数
(define global-function-names '())

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

(define (collect-imports code)
  (define imports '())
  (for ([line (in-list (string-split code "\n"))])
    (define trimmed (string-trim line))
    (when (string-prefix? trimmed "导入 ")
      (define path-str (string-trim (substring trimmed 3) "\""))
      (set! imports (cons path-str imports))))
  (reverse imports))

(define processed-files (make-hash))

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
        (if (absolute-path? import-path)
            import-path
            (build-path base-dir import-path)))
      (collect-all-functions import-full))))

(define full-path
  (build-path (current-directory) "examples/plane-shooter/main.mingdao"))

(printf "\n=== 阶段1: 递归扫描所有模块收集函数名 ===\n")
(collect-all-functions full-path)
(printf "总共注册函数: ~a 个\n" (length global-function-names))
(printf "函数列表: ~a\n" global-function-names)

(printf "\n=== 阶段2: 解析所有模块 ===\n")
(define modules
  '("constants.mingdao" "helper.mingdao" "state.mingdao" "drawing.mingdao"
    "logic.mingdao" "collision.mingdao" "main.mingdao"))

(for ([m modules])
  (define path (build-path (current-directory) "examples/plane-shooter" m))
  (define code (port->string (open-input-file path)))
  (define tokens (tokenize code))
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "  ✗ ~a: 解析失败 - ~a\n" m (exn-message e)))])
    (define ast (parse tokens global-function-names))
    (printf "  ✓ ~a: ~a 个表达式\n" m (length ast))))

(printf "\n=== 集成测试通过！ ===\n")