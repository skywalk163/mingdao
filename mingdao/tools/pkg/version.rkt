#lang racket/base

;; 版本处理模块 - 语义化版本 (SemVer) 实现
;; 参考 Cargo 的版本处理实现

(require racket/string
         racket/match)

(provide
 ;; 版本结构
 make-version version? version-major version-minor version-patch
 version-pre version-build
 ;; 版本比较
 version-compare version<? version<=? version=? version>=? version>?
 ;; 版本约束
 make-version-constraint version-constraint? version-constraint-op version-constraint-version
 matches-constraint?
 ;; 解析
 parse-version parse-constraint
 ;; 格式化
 version->string constraint->string)

;; ==================== 版本结构 ====================

(struct version (major minor patch pre build) #:transparent)

(define (make-version major minor patch [pre #f] [build #f])
  (version major minor patch pre build))

;; ==================== 版本解析 ====================

(define (parse-version str)
  ;; 解析 SemVer 格式: major.minor.patch[-pre][+build]
  (define re #rx"^([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:-([a-zA-Z0-9.-]+))?(?:\\+([a-zA-Z0-9.-]+))?$")
  (define m (regexp-match re str))
  (if m
      (let* ([major (string->number (list-ref m 1))]
             [minor (string->number (list-ref m 2))]
             [patch (string->number (list-ref m 3))]
             [pre (list-ref m 4)]
             [build (list-ref m 5)])
        (version major minor patch pre build))
      (error 'parse-version "无效的版本字符串: ~a" str)))

;; ==================== 版本比较 ====================

(define (version-compare v1 v2)
  ;; 比较两个版本，返回 'less, 'equal, 或 'greater
  (define (compare-nums a b)
    (cond [(< a b) 'less]
          [(> a b) 'greater]
          [else 'equal]))
  
  (define (compare-strings a b)
    (cond [(string<? a b) 'less]
          [(string>? a b) 'greater]
          [else 'equal]))
  
  (define (compare-pre v1-pre v2-pre)
    ;; 预发布版本比较
    (cond
      [(and (not v1-pre) (not v2-pre)) 'equal]
      [(not v1-pre) 'greater]
      [(not v2-pre) 'less]
      [else
       (let ([parts1 (string-split v1-pre ".")]
             [parts2 (string-split v2-pre ".")])
         (let loop ([i 0] [len1 (length parts1)] [len2 (length parts2)])
           (if (= i (min len1 len2))
               (cond [(< len1 len2) 'less]
                     [(> len1 len2) 'greater]
                     [else 'equal])
               (let* ([p1 (list-ref parts1 i)]
                      [p2 (list-ref parts2 i)]
                      [n1 (string->number p1)]
                      [n2 (string->number p2)])
                 (cond
                   [(and n1 n2)
                    (let ([cmp (compare-nums n1 n2)])
                      (if (eq? cmp 'equal)
                          (loop (+ i 1) len1 len2)
                          cmp))]
                   [(and n1 (not n2)) 'less]
                   [(and (not n1) n2) 'greater]
                   [else
                    (let ([cmp (compare-strings p1 p2)])
                      (if (eq? cmp 'equal)
                          (loop (+ i 1) len1 len2)
                          cmp))])))))]))
  
  (case (compare-nums (version-major v1) (version-major v2))
    [(less) 'less]
    [(greater) 'greater]
    [else
     (case (compare-nums (version-minor v1) (version-minor v2))
       [(less) 'less]
       [(greater) 'greater]
       [else
        (case (compare-nums (version-patch v1) (version-patch v2))
          [(less) 'less]
          [(greater) 'greater]
          [else (compare-pre (version-pre v1) (version-pre v2))])])]))

(define (version<? v1 v2)
  (eq? (version-compare v1 v2) 'less))

(define (version<=? v1 v2)
  (not (eq? (version-compare v1 v2) 'greater)))

(define (version=? v1 v2)
  (eq? (version-compare v1 v2) 'equal))

(define (version>=? v1 v2)
  (not (eq? (version-compare v1 v2) 'less)))

(define (version>? v1 v2)
  (eq? (version-compare v1 v2) 'greater))

;; ==================== 版本约束 ====================

;; 操作符: exact, caret (^), tilde (~), gte, lte, gt, lt
(struct version-constraint (op version) #:transparent)

(define (make-version-constraint op version)
  (version-constraint op version))

(define (parse-constraint str)
  ;; 解析约束字符串:
  ;; exact: "1.2.3" 或 "=1.2.3"
  ;; caret: "^1.2.3"
  ;; tilde: "~1.2.3"
  ;; gte: ">=1.2.3"
  ;; lte: "<=1.2.3"
  ;; gt: ">1.2.3"
  ;; lt: "<1.2.3"
  (define re #rx"^(\\^|~|>=|<=|>|<|=)?(.+)$")
  (define m (regexp-match re str))
  (if m
      (let* ([op-str (or (list-ref m 1) "=")]
             [version-str (list-ref m 2)]
             ;; 规范化简写版本 "2.0" -> "2.0.0"
             [normalized-ver (if (regexp-match? #rx"^[0-9]+\\.[0-9]+$" version-str)
                                 (string-append version-str ".0")
                                 version-str)]
             [op (case op-str
                   [("^") 'caret]
                   [("~") 'tilde]
                   [(">=") 'gte]
                   [("<=") 'lte]
                   [(">") 'gt]
                   [("<") 'lt]
                   [("=") 'exact]
                   [else (error 'parse-constraint "未知的操作符: ~a" op-str)])]
             [ver (parse-version normalized-ver)])
        (version-constraint op ver))
      (error 'parse-constraint "无效的约束字符串: ~a" str)))

;; ==================== 约束匹配 ====================

(define (matches-constraint? ver constraint)
  ;; 检查版本是否满足约束
  (define (check-caret ver target)
    ;; ^1.2.3 → >=1.2.3 <2.0.0
    (let* ([t-major (version-major target)]
           [t-minor (version-minor target)]
           [t-patch (version-patch target)]
           [lower (version t-major t-minor t-patch #f #f)]
           [upper (version (+ t-major 1) 0 0 #f #f)])
      (and (version>=? ver lower)
           (version<? ver upper)
           (or (not (version-pre ver))
               (and (version-pre lower) (version>=? ver lower))))))
  
  (define (check-tilde ver target)
    ;; ~1.2.3 → >=1.2.3 <1.3.0
    (let* ([t-major (version-major target)]
           [t-minor (version-minor target)]
           [t-patch (version-patch target)]
           [lower (version t-major t-minor t-patch #f #f)]
           [upper (version t-major (+ t-minor 1) 0 #f #f)])
      (and (version>=? ver lower)
           (version<? ver upper))))
  
  (let ([op (version-constraint-op constraint)]
        [target (version-constraint-version constraint)])
    (case op
      [(exact) (version=? ver target)]
      [(caret) (check-caret ver target)]
      [(tilde) (check-tilde ver target)]
      [(gte) (version>=? ver target)]
      [(lte) (version<=? ver target)]
      [(gt) (version>? ver target)]
      [(lt) (version<? ver target)]
      [else (error 'matches-constraint? "未知的操作符: ~a" op)])))

;; ==================== 格式化输出 ====================

(define (version->string ver)
  ;; 将版本转换为字符串
  (define base (format "~a.~a.~a"
                       (version-major ver)
                       (version-minor ver)
                       (version-patch ver)))
  (define pre-str (version-pre ver))
  (define build-str (version-build ver))
  (string-append
   base
   (if pre-str (string-append "-" pre-str) "")
   (if build-str (string-append "+" build-str) "")))

(define (constraint->string constraint)
  ;; 将约束转换为字符串
  (define op-str (case (version-constraint-op constraint)
                   [(exact) "="]
                   [(caret) "^"]
                   [(tilde) "~"]
                   [(gte) ">="]
                   [(lte) "<="]
                   [(gt) ">"]
                   [(lt) "<"]
                   [else (error 'constraint->string "未知的操作符")]))
  (string-append op-str (version->string (version-constraint-version constraint))))
