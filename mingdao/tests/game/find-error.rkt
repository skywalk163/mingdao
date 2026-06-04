#lang racket
(require "../../lang/tokenizer.rkt"
         "../../lang/parser.rkt"
         racket/path
         racket/list
         racket/string)

(current-directory "g:\\dumategithub\\langbyracket\\mingdao")
(displayln (current-directory))

(define (scan-funcs path)
  (define code (port->string (open-input-file (build-path (current-directory) path))))
  (define names '())
  (for ([line (in-list (string-split code "\n"))])
    (define trimmed (string-trim line))
    (when (string-prefix? trimmed "定义 ")
      (define parts (string-split trimmed))
      (when (and (>= (length parts) 3) (equal? (list-ref parts 2) "就是函"))
        (set! names (cons (list-ref parts 1) names)))))
  names)

(define all-names
  (append
    (scan-funcs "examples/plane-shooter/helper.mingdao")
    (scan-funcs "examples/plane-shooter/state.mingdao")
    (scan-funcs "examples/plane-shooter/drawing.mingdao")
    (scan-funcs "examples/plane-shooter/collision.mingdao")
    (scan-funcs "examples/plane-shooter/logic.mingdao")))

(printf "已注册函数 (~a 个): ~a\n" (length all-names) all-names)

(define logic-code (port->string (open-input-file
  (build-path (current-directory) "examples/plane-shooter/logic.mingdao"))))

(define lines (string-split logic-code "\n"))
(printf "总行数: ~a\n\n" (length lines))

(define (try-parse-line i line funcs)
  (define trimmed (string-trim line))
  (when (not (= 0 (string-length trimmed)))
    (with-handlers ([exn:fail? (lambda (e)
                                 (printf "行 ~a: 错误: ~a\n" (+ i 1) (exn-message e))
                                 (printf "  内容: ~a\n" trimmed))])
      (let ([tokens (tokenize (string-append trimmed "\n"))]
            [ast (parse tokens funcs)])
        (void)))))

;; Try parsing line by line
(for ([i (in-range (length lines))])
  (define line (list-ref lines i))
  (define trimmed (string-trim line))
  (when (and (not (= 0 (string-length trimmed)))
             (not (string-prefix? trimmed ";;")))
    (try-parse-line i line all-names)))

;; Now try full parsing
(printf "\n=== 尝试完整解析 ===\n")
(define tokens (tokenize logic-code))
(printf "词法单元数: ~a\n" (length tokens))
(with-handlers ([exn:fail? (lambda (e)
                             (printf "完整解析失败: ~a\n" (exn-message e)))])
  (define ast (parse tokens all-names))
  (printf "解析成功! ~a 个表达式\n" (length ast)))