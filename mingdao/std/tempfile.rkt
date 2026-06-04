#lang racket/base
(require racket/file racket/path racket/random racket/system)

(provide 临时/文件 临时/目录 临时/命名文件 临时/命名目录
         临时/临时名 临时/mkstemp 临时/mkdtemp 临时/生成名
         临时/默认目录 临时/后缀 临时/前缀)

(define 临时/默认目录
  (find-system-path 'temp-dir))

(define 临时/后缀 "")

(define 临时/前缀 "tmp")

(define (临时/生成名 [前缀 临时/前缀] [后缀 临时/后缀])
  (define rand-hex
    (list->string (for/list ([i (in-range 8)]) (string-ref "0123456789abcdef" (random 16)))))
  (path->string (build-path (临时/默认目录) (string-append 前缀 rand-hex 后缀))))

(define (临时/临时名 [前缀 临时/前缀] [后缀 临时/后缀])
  (临时/生成名 前缀 后缀))

(define (临时/mkstemp [前缀 临时/前缀] [后缀 临时/后缀])
  (define tmppath (临时/生成名 前缀 后缀))
  (call-with-output-file tmppath #:exists 'never
    (λ (p) (display "" p)))
  (values tmppath (open-input-output-file tmppath #:exists 'append)))

(define (临时/mkdtemp [前缀 临时/前缀] [后缀 临时/后缀])
  (define tmppath (临时/生成名 前缀 后缀))
  (make-directory tmppath)
  tmppath)

(define (临时/命名文件 [模式 'create] [后缀 ""] [前缀 "tmp"] [目录 临时/默认目录])
  (define rand-hex
    (list->string (for/list ([i (in-range 8)]) (string-ref "0123456789abcdef" (random 16)))))
  (define filepath (build-path 目录 (string-append 前缀 rand-hex 后缀)))
  (define port (open-output-file filepath #:exists 'create))
  (values (path->string filepath) port))

(define (临时/命名目录 [后缀 ""] [前缀 "tmp"] [目录 临时/默认目录])
  (define rand-hex
    (list->string (for/list ([i (in-range 8)]) (string-ref "0123456789abcdef" (random 16)))))
  (define dirpath (build-path 目录 (string-append 前缀 rand-hex 后缀)))
  (make-directory dirpath)
  (path->string dirpath))

(define (临时/文件 [模式 'create] [后缀 ""] [前缀 "tmp"] [目录 临时/默认目录])
  (临时/命名文件 模式 后缀 前缀 目录))

(define (临时/目录 [后缀 ""] [前缀 "tmp"] [目录 临时/默认目录])
  (临时/命名目录 后缀 前缀 目录))