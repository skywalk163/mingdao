#lang racket/base
(require racket/string)

(provide 自动换行 填充 缩进 去缩进 缩短)

(define (自动换行 text [width 70])
  (define words (string-split text))
  (let loop ([words words] [lines '()] [current ""])
    (if (null? words)
        (reverse (if (equal? current "") lines (cons current lines)))
        (let ([word (car words)]
              [rest (cdr words)])
          (if (equal? current "")
              (loop rest lines word)
              (if (<= (string-length (string-append current " " word)) width)
                  (loop rest lines (string-append current " " word))
                  (loop rest (cons current lines) word)))))))

(define (填充 text [width 70])
  (string-join (自动换行 text width) "\n"))

(define (缩进 text prefix)
  (define lines (string-split text "\n" #:trim? #f))
  (string-join (for/list ([line (in-list lines)])
                 (string-append prefix line))
               "\n"))

(define (去缩进 text)
  (define lines (string-split text "\n" #:trim? #f))
  (define non-empty-lines
    (filter (λ (line) (not (string=? line ""))) lines))
  (if (null? non-empty-lines)
      text
      (let* ([indent-levels
              (for/list ([line (in-list non-empty-lines)])
                (string-length (car (regexp-match #rx"^[ \t]*" line))))]
             [common-indent (apply min indent-levels)]
             [trimmed-lines
              (for/list ([line (in-list lines)])
                (if (< (string-length line) common-indent)
                    ""
                    (substring line common-indent)))])
        (string-join trimmed-lines "\n"))))

(define (缩短 text [width 70] [placeholder "...（省略）"])
  (if (<= (string-length text) width)
      text
      (string-append (substring text 0 (- width (string-length placeholder))) placeholder)))