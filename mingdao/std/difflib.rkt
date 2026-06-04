#lang racket/base

(require racket/list racket/string racket/match)

(provide
 差异/比较 差异/上下文差异 统一差异 html差异
 差异/比例 差异/匹配块 差异/最佳匹配
 差异/序列匹配器 差异/分组 差异/相近 差异/相同率)

(struct 匹配块 (a b size) #:transparent)

(define (差异/序列匹配器 a b)
  (define n (string-length a))
  (define m (string-length b))
  (define matching-blocks '())
  (let loop ((i 0) (j 0))
    (cond
      [(and (>= i n) (>= j m))
       (set! matching-blocks (reverse (cons (匹配块 n m 0) matching-blocks)))
       matching-blocks]
      [(>= i n)
       (set! matching-blocks (reverse (cons (匹配块 n m 0) matching-blocks)))
       matching-blocks]
      [(>= j m)
       (set! matching-blocks (reverse (cons (匹配块 n m 0) matching-blocks)))
       matching-blocks]
      [else
       (let find-match ((ii i) (jj j) (best-len 0) (best-i i) (best-j j))
         (if (>= ii n)
           (if (> best-len 0)
             (begin
               (set! matching-blocks (cons (匹配块 best-i best-j best-len) matching-blocks))
               (loop (+ best-i best-len) (+ best-j best-len)))
             (loop (+ i 1) j))
           (let scan ((jj j) (best-len best-len) (best-i best-i) (best-j best-j))
             (if (>= jj m)
               (find-match (+ ii 1) j best-len best-i best-j)
               (if (char=? (string-ref a ii) (string-ref b jj))
                 (let ((len (let extend ((ii ii) (jj jj) (len 0))
                              (if (and (< ii n) (< jj m)
                                       (char=? (string-ref a ii) (string-ref b jj)))
                                (extend (+ ii 1) (+ jj 1) (+ len 1))
                                len))))
                   (if (> len best-len)
                     (scan jj len ii jj)
                     (scan (+ jj 1) best-len best-i best-j)))
                 (scan (+ jj 1) best-len best-i best-j))))))])))

(define (差异/匹配块 a b)
  (差异/序列匹配器 a b))

(define (差异/比较 a-lines b-lines)
  (define result '())
  (define ai 0)
  (define bi 0)
  (define a-len (length a-lines))
  (define b-len (length b-lines))
  (let loop ()
    (cond
      [(and (< ai a-len) (< bi b-len) (equal? (list-ref a-lines ai) (list-ref b-lines bi)))
       (set! result (append result (list (format "  ~a" (list-ref a-lines ai)))))
       (set! ai (+ ai 1))
       (set! bi (+ bi 1))
       (loop)]
      [(and (< ai a-len) (< bi b-len))
       (set! result (append result (list (format "- ~a" (list-ref a-lines ai)))))
       (set! result (append result (list (format "+ ~a" (list-ref b-lines bi)))))
       (set! ai (+ ai 1))
       (set! bi (+ bi 1))
       (loop)]
      [(< ai a-len)
       (set! result (append result (list (format "- ~a" (list-ref a-lines ai)))))
       (set! ai (+ ai 1))
       (loop)]
      [(< bi b-len)
       (set! result (append result (list (format "+ ~a" (list-ref b-lines bi)))))
       (set! bi (+ bi 1))
       (loop)]
      [else result])))

(define (差异/上下文差异 a-lines b-lines #:n [context 3])
  (define diff (差异/比较 a-lines b-lines))
  (define total (length diff))
  (define (get-context idx)
    (let ((start (max 0 (- idx context)))
          (end (min total (+ idx context 1))))
      (take (drop diff start) (- end start))))
  (define result '("***************"))
  (let loop ((i 0) (out result))
    (if (>= i total)
      out
      (let ((line (list-ref diff i)))
        (if (char=? (string-ref line 0) #\-)
          (let ((ctx (get-context i)))
            (loop (+ i 1) (append out ctx)))
          (loop (+ i 1) out))))))

(define (统一差异 a-lines b-lines #:fromfile [from "a"] #:tofile [to "b"])
  (define diff (差异/比较 a-lines b-lines))
  (append
    (list (format "--- ~a" from) (format "+++ ~a" to))
    (let loop ((i 0) (out '()))
      (if (>= i (length diff))
        out
        (let ((line (list-ref diff i)))
          (loop (+ i 1) (append out (list line))))))))

(define (html差异 a-lines b-lines)
  (define diff (差异/比较 a-lines b-lines))
  (define lines
    (map (lambda (line)
           (cond
             [(char=? (string-ref line 0) #\+) (format "<ins>~a</ins>" (substring line 2))]
             [(char=? (string-ref line 0) #\-) (format "<del>~a</del>" (substring line 2))]
             [else (format "<span>~a</span>" line)]))
         diff))
  (string-join lines "<br>\n"))

(define (差异/比例 a b)
  (define blocks (差异/序列匹配器 a b))
  (define total-matched
    (foldl (lambda (block sum) (+ sum (匹配块-size block))) 0 blocks))
  (define total-len (+ (string-length a) (string-length b)))
  (if (zero? total-len) 1.0 (/ (* 2 total-matched) total-len)))

(define (差异/相同率 a b)
  (差异/比例 a b))

(define (差异/最佳匹配 word wordlist #:cutoff [cutoff 0.6])
  (define scored
    (sort
      (map (lambda (w) (cons (差异/比例 word w) w)) wordlist)
      (lambda (x y) (> (car x) (car y)))
      #:key car))
  (filter (lambda (pair) (>= (car pair) cutoff)) scored))

(define (差异/相近 word wordlist #:n [n 5] #:cutoff [cutoff 0.6])
  (define matches (差异/最佳匹配 word wordlist #:cutoff cutoff))
  (map cdr (take matches (min n (length matches)))))

(define (差异/分组 seq n)
  (let loop ((s seq) (result '()))
    (if (null? s)
      (reverse result)
      (loop (drop s (min n (length s)))
            (cons (take s (min n (length s))) result)))))