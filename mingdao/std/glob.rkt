#lang racket/base
(require racket/list racket/path racket/string racket/match)

(provide glob/匹配 glob/列表 glob/递归列表 glob/转义
         glob/匹配单个 glob/过滤 glob/根目录)

(define (glob-模式转正则 pattern)
  (define special-chars '(#\. #\+ #\^ #\$ #\( #\) #\[ #\] #\{ #\} #\\ #\|))
  (define chars (string->list pattern))
  (define (process-chars chars)
    (match chars
      ['() (list->string '(#\$))]
      [(cons #\? rest) (cons #\. (process-chars rest))]
      [(cons #\* (cons #\* rest)) (cons #\. (cons #\* (cons #\? (process-chars rest))))]
      [(cons #\* rest) (cons #\[ (cons #\^ (cons #\/ (cons #\] (cons #\. (cons #\* (process-chars rest)))))))]
      [(cons c rest)
       (if (member c special-chars)
           (cons #\\ (cons c (process-chars rest)))
           (cons c (process-chars rest)))]))
  (string-append "^" (list->string (process-chars chars))))

(define (glob/匹配模式 pattern path)
  (define re (regexp (glob-模式转正则 pattern)))
  (regexp-match? re path))

(define (glob/匹配 pattern path)
  (regexp-match? (regexp (string-append "^" (glob-模式转正则 pattern) "$")) path))

(define (glob/匹配单个 pattern path)
  (define re (regexp (glob-模式转正则 pattern)))
  (regexp-match? re (path->string path)))

(define (glob/列表 pattern)
  (define dir (if (string-contains? pattern "\\")
                  (substring pattern 0 (string-length pattern))
                  "."))
  (define base-dir (if (regexp-match? #px"[\\/]" pattern)
                       (let ([parts (regexp-split #px"[\\/]" pattern)])
                         (if (> (length parts) 1)
                             (string-join (drop-right parts 1) "\\")
                             "."))
                       "."))
  (define file-pat (if (regexp-match? #px"[\\/]" pattern)
                       (let ([parts (regexp-split #px"[\\/]" pattern)])
                         (last parts))
                       pattern))
  (define files (if (directory-exists? base-dir)
                    (directory-list base-dir)
                    '()))
  (define matched
    (filter (λ (f)
              (define name (path->string f))
              (glob/匹配 file-pat name))
            files))
  (map (λ (f) (string-append base-dir "\\" (path->string f))) matched))

(define (glob/递归列表 pattern)
  (define dir (if (regexp-match? #px"[\\/]" pattern)
                  (let ([parts (regexp-split #px"[\\/]" pattern)])
                    (string-join (drop-right parts 1) "\\"))
                  "."))
  (define file-pat (if (regexp-match? #px"[\\/]" pattern)
                       (let ([parts (regexp-split #px"[\\/]" pattern)])
                         (last parts))
                       pattern))
  (define (walk-dir dir-path)
    (define entries (if (directory-exists? dir-path)
                        (map (λ (e) (build-path dir-path e)) (directory-list dir-path))
                        '()))
    (append (filter (λ (e) (glob/匹配单个 file-pat e))
                    entries)
            (append-map (λ (e)
                          (if (directory-exists? e)
                              (walk-dir e)
                              '()))
                        entries)))
  (map path->string (walk-dir dir)))

(define (glob/转义 pattern)
  (define special-chars '(#\* #\? #\[ #\] #\{ #\}))
  (list->string
   (apply append
          (map (λ (c)
                 (if (member c special-chars)
                     (list #\\ c)
                     (list c)))
               (string->list pattern)))))

(define (glob/过滤 pattern paths)
  (filter (λ (p) (glob/匹配 pattern p)) paths))

(define (glob/根目录 pattern)
  (if (regexp-match? #px"^[a-zA-Z]:[\\/]" pattern)
      (substring pattern 0 3)
      (if (regexp-match? #px"[\\/]" pattern)
          (let ([parts (regexp-split #px"[\\/]" pattern)])
            (first parts))
          ".")))