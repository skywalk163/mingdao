#lang racket/base

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         racket/port
         racket/pretty)

(define code (port->string (open-input-file "examples/plane-shooter.mingdao")))
(printf "文件读取成功，长度：~a 字符\n" (string-length code))

(define tokens (tokenize code))
(printf "词法分析成功，生成 ~a 个Token\n" (length tokens))

(with-handlers ([exn:fail? (lambda (e) 
                             (printf "解析失败：~a\n" (exn-message e))
                             (exit 1))])
  (define ast (parse tokens))
  (printf "语法分析成功，生成 ~a 个AST节点\n" (length ast))
  (displayln "所有解析测试通过！"))