#lang racket/base

;; 依赖解析器 - 使用贪婪算法实现依赖解析

(require racket/base
         racket/list
         (file "version.rkt")
         (file "manifest.rkt"))

(provide
 ;; 解析结果
 make-resolve-result resolve-result?
 resolve-dependencies
 ;; 候选查找
 find-candidates
 ;; 最佳选择
 select-best
 ;; 访问器
 resolved-packages unresolved-deps conflicts
 ;; 注册表
 make-mock-registry
 ;; 包构造
 make-basic-package make-dep
 package? package-name package-version package-deps
 dep-name dep-constraints
 ;; 版本
 make-version version=? version>?
 parse-constraint)

;; 访问器别名
(define (resolved-packages result)
  (resolve-result-packages result))

(define (unresolved-deps result)
  (resolve-result-conflicts result))

(define (conflicts result)
  (resolve-result-conflicts result))

;; ==================== 解析结果结构 ====================

(struct resolve-result (packages conflicts) #:transparent)

(define (make-resolve-result packages [conflicts '()])
  (resolve-result packages conflicts))

;; ==================== 模拟注册表 ====================

;; 注册表结构: (hash-of package-name -> (listof (cons version package)))
(define (make-mock-registry packages)
  (define registry (make-hash))
  (for ([pkg packages])
    (let ([name (package-name pkg)]
          [ver (package-version pkg)])
      (hash-set! registry name
                 (cons (cons ver pkg)
                       (hash-ref registry name '())))))
  registry)

(define (registry-versions registry name)
  (hash-ref registry name '()))

;; ==================== 候选查找 ====================

(define (find-candidates registry name constraint)
  ;; 查找满足约束的所有候选版本
  (define versions (registry-versions registry name))
  (filter (lambda (ver-pkg)
            (matches-constraint? (car ver-pkg) constraint))
          versions))

(define (select-best candidates)
  ;; 选择最新版本 (贪婪策略)
  (if (null? candidates)
      #f
      (let* ([sorted (sort candidates
                           (lambda (a b)
                             (version>? a b))
                           #:key car)]
             [best (car sorted)])
        (cdr best))))

;; ==================== 贪婪解析算法 ====================

(define (resolve-dependencies registry requirements)
  ;; 贪婪解析:
  ;; 1. 对每个依赖,选择满足约束的最新版本
  ;; 2. 递归处理传递依赖
  ;; 3. 检测并报告冲突
  
  (define resolved (make-hash))  ; name -> package
  (define conflicts '())
  
  (define (resolve-one! name constraint)
    ;; 解析单个依赖
    (cond
      [(hash-has-key? resolved name)
       ;; 已解析,检查版本兼容性
       (let ([existing (hash-ref resolved name)])
         (unless (matches-constraint? (package-version existing) constraint)
           (set! conflicts (cons (list name constraint (package-version existing))
                                 conflicts))))]
      [else
       ;; 查找候选版本
       (let ([candidates (find-candidates registry name constraint)])
         (cond
           [(null? candidates)
            (set! conflicts (cons (list name constraint #f) conflicts))]
           [else
            (let ([pkg (select-best candidates)])
              (hash-set! resolved name pkg)
              ;; 递归解析传递依赖
              (for ([dep (package-deps pkg)])
                (resolve-one! (dep-name dep)
                              (car (dep-constraints dep)))))]))]))
  
  ;; 处理所有需求
  (for ([req requirements])
    (resolve-one! (dep-name req) (car (dep-constraints req))))
  
  ;; 返回结果
  (make-resolve-result
   (hash-values resolved)
   (reverse conflicts)))