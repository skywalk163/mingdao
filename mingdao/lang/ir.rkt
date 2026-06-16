#lang racket/base

(require racket/match racket/list racket/string racket/format racket/set)

(provide
 ir-value? ir-const? ir-var? ir-label?
 ir-value-type ir-const-value ir-var-name ir-label-name
 ir-instr? ir-instr-result
 ir-assign? ir-assign-source
 ir-load? ir-load-var-name
 ir-store? ir-store-var-name ir-store-value
 ir-binop? ir-binop-op ir-binop-left ir-binop-right
 ir-unop? ir-unop-op ir-unop-operand
 ir-cmp? ir-cmp-op ir-cmp-left ir-cmp-right
 ir-call? ir-call-fn ir-call-args
 ir-phi? ir-phi-edges
 ir-ret? ir-ret-value
 ir-br? ir-br-target
 ir-cond-br? ir-cond-br-cond ir-cond-br-then-label ir-cond-br-else-label
 ir-block? ir-block-label ir-block-instrs ir-block-terminator
 ir-function? ir-function-name ir-function-params ir-function-return-type ir-function-blocks
 ir-module? ir-module-functions ir-module-globals
 fresh-var fresh-label make-block set-block-instrs! set-block-terminator!
 block->all-instrs ir-value->string ir-instr->string ir-block->string ir-function->string ir-module->string
 lower-module lower-function lower-expr
 optimize-module constant-fold dead-code-elim cse-elim
 emit-module emit-function ast->ir module->racket use-ir-optimization?)

;; ============================================================
;; IR 数据结构
;; ============================================================
(struct ir-value (type) #:transparent)
(struct ir-const ir-value (value) #:transparent)
(struct ir-var ir-value (name) #:transparent)
(struct ir-label ir-value (name) #:transparent)

(struct ir-instr (result) #:transparent)
(struct ir-assign ir-instr (source) #:transparent)
(struct ir-load ir-instr (var-name) #:transparent)
(struct ir-store ir-instr (var-name value) #:transparent)
(struct ir-binop ir-instr (op left right) #:transparent)
(struct ir-unop ir-instr (op operand) #:transparent)
(struct ir-cmp ir-instr (op left right) #:transparent)
(struct ir-call ir-instr (fn args) #:transparent)
(struct ir-phi ir-instr (edges) #:transparent)
(struct ir-ret ir-instr (value) #:transparent)
(struct ir-br ir-instr (target) #:transparent)
(struct ir-cond-br ir-instr (cond then-label else-label) #:transparent)

(struct ir-block (label instrs terminator) #:transparent #:mutable)
(struct ir-function (name params return-type blocks) #:transparent)
(struct ir-module (functions globals) #:transparent)

;; ============================================================
;; 工具函数
;; ============================================================
(define *var-counter* 0)
(define *label-counter* 0)

(define (fresh-var (type '任意))
  (set! *var-counter* (+ *var-counter* 1))
  (ir-var type (string->symbol (format "%~a" (- *var-counter* 1)))))

(define (fresh-label (prefix "B"))
  (set! *label-counter* (+ *label-counter* 1))
  (ir-label 'label (string->symbol (format "~a-~a" prefix (- *label-counter* 1)))))

(define (reset-counters!)
  (set! *var-counter* 0)
  (set! *label-counter* 0))

(define (make-block (label #f) (instrs null) (terminator #f))
  (ir-block (or label (fresh-label)) instrs terminator))

(define (set-block-instrs! b instrs)
  (set-ir-block-instrs! b instrs))

(define (set-block-terminator! b term)
  (set-ir-block-terminator! b term))

(define (block->all-instrs b)
  (append (ir-block-instrs b)
          (if (ir-block-terminator b) (list (ir-block-terminator b)) null)))

;; 常量类型推断
(define (type-of-value v)
  (cond
    ((exact-integer? v) '整数)
    ((number? v) '浮点数)
    ((string? v) '字符串)
    ((boolean? v) '布尔)
    ((char? v) '字符串)
    ((null? v) '列表)
    (else '任意)))

;; ============================================================
;; IR 调试打印
;; ============================================================
(define (ir-value->string v)
  (cond
    ((ir-const? v) (format "~a" (ir-const-value v)))
    ((ir-var? v) (format "~a" (ir-var-name v)))
    ((ir-label? v) (format "~a" (ir-label-name v)))
    (else (format "#<ir-value>"))))

(define (ir-instr->string i)
  (define res (if (ir-instr-result i)
                  (format "~a = " (ir-var-name (ir-instr-result i)))
                  ""))
  (define body
    (cond
      ((ir-assign? i) (format "~a" (ir-value->string (ir-assign-source i))))
      ((ir-load? i) (format "load ~a" (ir-load-var-name i)))
      ((ir-store? i) (format "store ~a, ~a" (ir-value->string (ir-store-value i)) (ir-store-var-name i)))
      ((ir-binop? i) (format "~a(~a, ~a)" (ir-binop-op i) (ir-value->string (ir-binop-left i)) (ir-value->string (ir-binop-right i))))
      ((ir-unop? i) (format "~a(~a)" (ir-unop-op i) (ir-value->string (ir-unop-operand i))))
      ((ir-cmp? i) (format "~a(~a, ~a)" (ir-cmp-op i) (ir-value->string (ir-cmp-left i)) (ir-value->string (ir-cmp-right i))))
      ((ir-call? i) (format "call(~a, [~a])" (ir-call-fn i) (string-join (map ir-value->string (ir-call-args i)) ", ")))
      ((ir-phi? i) (format "phi(~a)" (string-join (map (lambda (e) (format "(~a: ~a)" (car e) (ir-value->string (cdr e)))) (ir-phi-edges i)) ", ")))
      ((ir-ret? i) (format "return ~a" (ir-value->string (ir-ret-value i))))
      ((ir-br? i) (format "goto ~a" (ir-label-name (ir-br-target i))))
      ((ir-cond-br? i) (format "if ~a goto ~a else ~a" (ir-value->string (ir-cond-br-cond i)) (ir-label-name (ir-cond-br-then-label i)) (ir-label-name (ir-cond-br-else-label i))))
      (else "#<instr>")))
  (string-append res body))

(define (ir-block->string b (indent "  "))
  (define header (format "~a:" (ir-label-name (ir-block-label b))))
  (define body-strs (map (lambda (i) (format "~a~a" indent (ir-instr->string i))) (ir-block-instrs b)))
  (define term-str (if (ir-block-terminator b) (list (format "~a~a" indent (ir-instr->string (ir-block-terminator b)))) null))
  (string-join (append (list header) body-strs term-str) "\n"))

(define (ir-function->string fn)
  (define header (format "func ~a(~a) -> ~a"
                         (ir-function-name fn)
                         (string-join (map (lambda (p) (format "~a:~a" (ir-var-name p) (ir-value-type p))) (ir-function-params fn)) ", ")
                         (ir-function-return-type fn)))
  (define body (string-join (map (lambda (b) (ir-block->string b "    ")) (ir-function-blocks fn)) "\n"))
  (format "~a\n~a" header body))

(define (ir-module->string m)
  (define funcs-str (string-join (map ir-function->string (ir-module-functions m)) "\n\n"))
  (define globals-str (if (> (hash-count (ir-module-globals m)) 0) (format "\n\n; globals: ~a" (hash-keys (ir-module-globals m))) ""))
  (format "~a~a" funcs-str globals-str))

;; ============================================================
;; Lowering 状态
;; ============================================================
(struct lower-state (current-block completed-blocks mutable-vars) #:transparent #:mutable)

(define (make-lower-state)
  (define entry-block (make-block (fresh-label "entry") null #f))
  (lower-state entry-block (list entry-block) (make-hash)))

(define (state-add-instr! st instr)
  (define b (lower-state-current-block st))
  (set-block-instrs! b (append (ir-block-instrs b) (list instr))))

(define (state-terminate! st instr)
  (define b (lower-state-current-block st))
  (set-block-terminator! b instr))

(define (state-start-new-block! st label)
  (define b (make-block label null #f))
  (set-lower-state-completed-blocks! st (append (lower-state-completed-blocks st) (list b)))
  (set-lower-state-current-block! st b)
  b)

(define (state-register-mutable! st name initial-value)
  (hash-set! (lower-state-mutable-vars st) name (list initial-value)))

(define (state-update-mutable! st name new-value)
  (hash-update! (lower-state-mutable-vars st) name (lambda (history) (cons new-value (cdr history))) (lambda () (ir-const '任意 null))))

(define (state-lookup-mutable st name)
  (define h (lower-state-mutable-vars st))
  (if (hash-has-key? h name) (car (hash-ref h name)) #f))

;; ============================================================
;; Lowering 主逻辑
;; ============================================================
(define binop-op-names '("加" "减" "乘" "除" "模" "幂" "+" "-" "*" "/" "%" "^"))
(define cmp-op-names '("大于" "小于" "等于" "不等" "大于等于" "小于等于" ">" "<" "=" "!=" ">=" "<="))
(define unop-op-names '("非" "长度" "转整数" "转浮点数" "转字符串"
                        "是整数" "是浮点数" "是字符串" "是空"
                        "随机整数" "随机浮点数" "绝对值"
                        "正弦" "余弦" "正切" "自然对数" "指数" "阶乘"
                        "字符串长度" "字符串转列表" "输入" "打印"
                        "not" "print" "abs"))

(define (binop-op? s)
  (member s binop-op-names string=?))

(define (cmp-op? s)
  (member s cmp-op-names string=?))

(define (unop-op? s)
  (member s unop-op-names string=?))

;; 归一化运算符：统一为中文表示
(define (normalize-binop op)
  (case op
    ((+ 加) '加)
    ((- 减) '减)
    ((* 乘) '乘)
    ((/ 除) '除)
    ((% 模) '模)
    ((^ 幂) '幂)
    (else op)))

(define (normalize-cmp op)
  (case op
    ((> 大于) '大于)
    ((< 小于) '小于)
    ((= 等于) '等于)
    ((!= 不等) '不等)
    ((>= 大于等于) '大于等于)
    ((<= 小于等于) '小于等于)
    (else op)))

(define (normalize-unop op)
  (case op
    ((not 非) '非)
    ((print 打印) '打印)
    ((abs 绝对值) '绝对值)
    (else op)))

;; 降低 if 表达式
(define (lower-if-blocks cond-expr then-expr else-expr st)
  (define cond-val (lower-expr cond-expr st))
  (define then-label (fresh-label "then"))
  (define else-label (fresh-label "else"))
  (define merge-label (fresh-label "merge"))
  (state-terminate! st (ir-cond-br #f cond-val then-label else-label))
  (define mutable-names (hash-keys (lower-state-mutable-vars st)))
  ;; then 分支
  (state-start-new-block! st then-label)
  (define then-val (lower-expr then-expr st))
  (define then-snap (map (lambda (n) (cons n (state-lookup-mutable st n))) mutable-names))
  (state-terminate! st (ir-br #f merge-label))
  ;; else 分支
  (state-start-new-block! st else-label)
  (define else-val (lower-expr else-expr st))
  (define else-snap (map (lambda (n) (cons n (state-lookup-mutable st n))) mutable-names))
  (state-terminate! st (ir-br #f merge-label))
  ;; 合并块，插入 phi 节点
  (state-start-new-block! st merge-label)
  (for-each (lambda (name)
              (let ((tm (cdr (assoc name then-snap)))
                    (em (cdr (assoc name else-snap))))
                (when (not (equal? tm em))
                  (let ((pv (fresh-var (or (and tm (ir-value-type tm)) '任意))))
                    (state-add-instr! st (ir-phi pv (list (cons (ir-label-name then-label) (or tm (ir-const '布尔 #f)))
                                                             (cons (ir-label-name else-label) (or em (ir-const '布尔 #f))))))
                    (state-update-mutable! st name pv)))))
            mutable-names)
  ;; 返回值
  (if (and then-val else-val (not (equal? then-val else-val)))
      (let ((pv (fresh-var (or (ir-value-type then-val) '任意))))
        (state-add-instr! st (ir-phi pv (list (cons (ir-label-name then-label) then-val)
                                               (cons (ir-label-name else-label) else-val))))
        pv)
      (or then-val else-val)))

;; 降低函数调用/运算符应用
(define (lower-apply head rest st)
  (cond
    ((symbol? head)
     (define op-str (symbol->string head))
     (define args (map (lambda (e) (lower-expr e st)) rest))
     (cond
       ((and (= (length args) 2) (binop-op? op-str))
        (let ((v (fresh-var (if (or (string=? op-str "除") (string=? op-str "/")
                                    (equal? (ir-value-type (car args)) '浮点数)
                                    (equal? (ir-value-type (cadr args)) '浮点数))
                                '浮点数 '整数))))
          (state-add-instr! st (ir-binop v (normalize-binop head) (car args) (cadr args)))
          v))
       ((and (= (length args) 2) (cmp-op? op-str))
        (let ((v (fresh-var '布尔)))
          (state-add-instr! st (ir-cmp v (normalize-cmp head) (car args) (cadr args)))
          v))
       ((and (= (length args) 1) (unop-op? op-str))
        (let* ((out-type (cond
                           ((member op-str '("非" "是整数" "是浮点数" "是字符串" "是空" "not") string=?) '布尔)
                           ((member op-str '("转整数" "长度" "随机整数" "阶乘" "字符串长度" "abs") string=?) '整数)
                           ((member op-str '("转浮点数" "正弦" "余弦" "正切" "自然对数" "指数" "随机浮点数" "绝对值" "print") string=?) '浮点数)
                           ((member op-str '("转字符串" "列表转字符串" "字符串转列表") string=?) '字符串)
                           (else '任意)))
               (v (fresh-var out-type)))
          (state-add-instr! st (ir-unop v (normalize-unop head) (car args)))
          v))
       (else
        (let ((v (fresh-var '任意)))
          (state-add-instr! st (ir-call v head args))
          v))))
    (else
     (let ((v (fresh-var '任意)))
       (state-add-instr! st (ir-call v 'apply (map (lambda (e) (lower-expr e st)) rest)))
       v))))

;; 降低 define 表达式
(define (lower-define arg1 args-rest st)
  (cond
    ((pair? arg1)
     ;; 这是函数定义 - 在函数内部不应再出现此形式
     (ir-const '空 null))
    (else
     ;; 变量定义
     (let ((var-name arg1)
           (val-expr (car args-rest)))
       (let ((val (lower-expr val-expr st)))
         (state-register-mutable! st (symbol->string var-name) val)
         (state-add-instr! st (ir-store #f (symbol->string var-name) val))
         val)))))

;; 降低赋值表达式 (= x v)
(define (lower-assign var-name val-expr st)
  (let ((val (lower-expr val-expr st)))
    (state-update-mutable! st (symbol->string var-name) val)
    (state-add-instr! st (ir-store #f (symbol->string var-name) val))
    val))

;; 降低 return 表达式
(define (lower-return val-expr st)
  (let ((val (lower-expr val-expr st)))
    (state-terminate! st (ir-ret #f val))
    val))

;; 降低 begin 表达式
(define (lower-begin exprs st)
  (define last-val (ir-const '空 null))
  (for-each (lambda (e) (set! last-val (lower-expr e st))) exprs)
  last-val)

;; 降低列表表达式
(define (lower-list items st)
  (let* ((args (map (lambda (e) (lower-expr e st)) items))
         (v (fresh-var '列表)))
    (state-add-instr! st (ir-call v '列表 args))
    v))

;; 降低单个表达式 - 返回 ir-value
(define (lower-expr expr st)
  (cond
    ;; 字面量
    ((or (number? expr) (string? expr) (boolean? expr) (char? expr))
     (ir-const (type-of-value expr) expr))
    ((null? expr) (ir-const '列表 null))
    ;; 变量引用
    ((symbol? expr)
     (define name (symbol->string expr))
     (define mval (state-lookup-mutable st name))
     (if mval
         (let ((v (fresh-var (ir-value-type mval))))
           (state-add-instr! st (ir-load v name))
           v)
         (ir-var '任意 expr)))
    ;; 复合表达式
    ((pair? expr)
     (let ((head (car expr))
           (rest (cdr expr)))
       (cond
         ((eq? head 'define) (lower-define (car rest) (cdr rest) st))
         ((eq? head 'set!) (lower-assign (car rest) (cadr rest) st))
         ((eq? head '=) (lower-assign (car rest) (cadr rest) st))
         ((eq? head 'return) (lower-return (car rest) st))
         ((eq? head 'if) (lower-if-blocks (car rest) (cadr rest) (caddr rest) st))
         ((eq? head 'begin) (lower-begin rest st))
         ((eq? head '列表) (lower-list rest st))
         (else (lower-apply head rest st)))))
    (else (ir-const '任意 null))))

;; ============================================================
;; lower-function
;; ============================================================
(define (lower-function fn-ast)
  (reset-counters!)
  (define st (make-lower-state))
  (define fn-name "anonymous")
  (define params null)
  (define body-exprs null)

  (when (and (pair? fn-ast) (eq? (car fn-ast) 'define))
    (let ((spec (cadr fn-ast)))
      (when (pair? spec)
        (set! fn-name (symbol->string (car spec)))
        (set! params (map (lambda (p) (ir-var '任意 p)) (cdr spec)))
        (set! body-exprs (cddr fn-ast)))))
  (when (null? body-exprs)
    (set! body-exprs (list fn-ast)))

  (for-each (lambda (p) (state-register-mutable! st (symbol->string (ir-var-name p)) p)) params)

  (define last-val (ir-const '空 null))
  (for-each (lambda (e) (set! last-val (lower-expr e st))) body-exprs)

  (unless (ir-block-terminator (lower-state-current-block st))
    (state-terminate! st (ir-ret #f last-val)))

  (ir-function fn-name params '任意 (lower-state-completed-blocks st)))

;; ============================================================
;; lower-module
;; ============================================================
(define (is-fun-def? expr)
  (and (pair? expr)
       (eq? (car expr) 'define)
       (pair? (cadr expr))))

(define (is-var-def? expr)
  (and (pair? expr)
       (eq? (car expr) 'define)
       (symbol? (cadr expr))))

(define (lower-module ast (builtin-names null))
  (define functions null)
  (define top-level-body null)
  (define globals (make-hash))

  (for-each (lambda (expr)
              (cond
                ((is-fun-def? expr)
                 (set! functions (append functions (list (lower-function expr))))
                 (hash-set! globals (symbol->string (car (cadr expr))) '函数))
                ((is-var-def? expr)
                 (set! top-level-body (append top-level-body (list expr)))
                 (hash-set! globals (symbol->string (cadr expr)) '任意))
                (else
                 (set! top-level-body (append top-level-body (list expr))))))
            ast)

  (when (not (null? top-level-body))
    (let ((init-st (make-lower-state)))
      (define last (ir-const '空 null))
      (for-each (lambda (e) (set! last (lower-expr e init-st))) top-level-body)
      (unless (ir-block-terminator (lower-state-current-block init-st))
        (state-terminate! init-st (ir-ret #f last)))
      (set! functions (append functions (list (ir-function "__init__" null '任意
                                                             (lower-state-completed-blocks init-st)))))))

  (ir-module functions globals))

;; ============================================================
;; 优化 Passes
;; ============================================================
(define (apply-binop-op op v1 v2)
  (and (number? v1) (number? v2)
       (case op
         ((加) (+ v1 v2))
         ((减) (- v1 v2))
         ((乘) (* v1 v2))
         ((除) (if (= v2 0) #f (/ v1 v2)))
         ((模) (modulo v1 v2))
         ((幂) (expt v1 v2))
         (else #f))))

(define (apply-cmp-op op v1 v2)
  (and (number? v1) (number? v2)
       (case op
         ((大于) (> v1 v2))
         ((小于) (< v1 v2))
         ((等于) (= v1 v2))
         ((不等) (not (= v1 v2)))
         ((大于等于) (>= v1 v2))
         ((小于等于) (<= v1 v2))
         (else #f))))

(define (apply-unop-op op v)
  (case op
    ((非) (and (boolean? v) (not v)))
    ((负) (and (number? v) (- v)))
    ((长度) (cond ((string? v) (string-length v)) ((list? v) (length v)) (else #f)))
    ((转整数) (and (number? v) (inexact->exact (round v))))
    ((转浮点数) (and (number? v) (exact->inexact v)))
    ((绝对值) (and (number? v) (abs v)))
    (else #f)))

(define (instr-fold instr)
  (cond
    ((ir-binop? instr)
     (let ((l (ir-binop-left instr))
           (r (ir-binop-right instr)))
       (if (and (ir-const? l) (ir-const? r))
           (let ((result (apply-binop-op (ir-binop-op instr) (ir-const-value l) (ir-const-value r))))
             (if result
                 (ir-assign (ir-instr-result instr) (ir-const (if (integer? result) '整数 '浮点数) result))
                 instr))
           instr)))
    ((ir-cmp? instr)
     (let ((l (ir-cmp-left instr))
           (r (ir-cmp-right instr)))
       (if (and (ir-const? l) (ir-const? r) (number? (ir-const-value l)) (number? (ir-const-value r)))
           (let ((result (apply-cmp-op (ir-cmp-op instr) (ir-const-value l) (ir-const-value r))))
             (if result
                 (ir-assign (ir-instr-result instr) (ir-const '布尔 result))
                 instr))
           instr)))
    ((ir-unop? instr)
     (let ((o (ir-unop-operand instr)))
       (if (ir-const? o)
           (let ((result (apply-unop-op (ir-unop-op instr) (ir-const-value o))))
             (if result
                 (ir-assign (ir-instr-result instr)
                            (ir-const (cond ((boolean? result) '布尔) ((integer? result) '整数) ((number? result) '浮点数) (else '任意)) result))
                 instr))
           instr)))
    (else instr)))

(define (constant-fold-function fn)
  (define new-blocks
    (map (lambda (b) (ir-block (ir-block-label b) (map instr-fold (ir-block-instrs b)) (ir-block-terminator b)))
         (ir-function-blocks fn)))
  (ir-function (ir-function-name fn) (ir-function-params fn) (ir-function-return-type fn) new-blocks))

(define (constant-fold-module m)
  (ir-module (map constant-fold-function (ir-module-functions m)) (ir-module-globals m)))

(define (instr-used-vars instr)
  (cond
    ((ir-assign? instr) (list (ir-assign-source instr)))
    ((ir-load? instr) null)
    ((ir-store? instr) (list (ir-store-value instr)))
    ((ir-binop? instr) (list (ir-binop-left instr) (ir-binop-right instr)))
    ((ir-unop? instr) (list (ir-unop-operand instr)))
    ((ir-cmp? instr) (list (ir-cmp-left instr) (ir-cmp-right instr)))
    ((ir-call? instr) (ir-call-args instr))
    ((ir-phi? instr) (map cdr (ir-phi-edges instr)))
    ((ir-ret? instr) (list (ir-ret-value instr)))
    ((ir-br? instr) null)
    ((ir-cond-br? instr) (list (ir-cond-br-cond instr)))
    (else null)))

(define (dce-function fn)
  (define blocks (ir-function-blocks fn))
  (define live-set (mutable-set))
  (for-each (lambda (b)
              (when (ir-block-terminator b)
                (for-each (lambda (v) (when (ir-var? v) (set-add! live-set (ir-var-name v))))
                          (instr-used-vars (ir-block-terminator b)))))
            blocks)
  (let iter ((changed #t) (count 0))
    (when (and changed (< count 100))
      (define new-changed #f)
      (for-each (lambda (b)
                  (for-each (lambda (instr)
                              (when (or (not (ir-instr-result instr)) (set-member? live-set (ir-var-name (ir-instr-result instr))))
                                (for-each (lambda (v)
                                            (when (and (ir-var? v) (not (set-member? live-set (ir-var-name v))))
                                              (set-add! live-set (ir-var-name v))
                                              (set! new-changed #t)))
                                          (instr-used-vars instr))))
                            (ir-block-instrs b)))
                blocks)
      (iter new-changed (+ count 1))))
  (define new-blocks
    (map (lambda (b)
           (define kept
             (filter (lambda (instr)
                       (cond ((or (ir-store? instr) (ir-call? instr)) #t)
                             ((not (ir-instr-result instr)) #t)
                             (else (set-member? live-set (ir-var-name (ir-instr-result instr))))))
                     (ir-block-instrs b)))
           (ir-block (ir-block-label b) kept (ir-block-terminator b)))
         blocks))
  (ir-function (ir-function-name fn) (ir-function-params fn) (ir-function-return-type fn) new-blocks))

(define (dead-code-elim-module m)
  (ir-module (map dce-function (ir-module-functions m)) (ir-module-globals m)))

(define (value-key v)
  (if (ir-var? v)
      (list 'var (ir-var-name v))
      (if (ir-const? v) (list 'const (ir-const-value v)) (list 'other v))))

(define (cse-hash-key instr)
  (cond
    ((ir-binop? instr) (list 'binop (ir-binop-op instr) (value-key (ir-binop-left instr)) (value-key (ir-binop-right instr))))
    ((ir-cmp? instr) (list 'cmp (ir-cmp-op instr) (value-key (ir-cmp-left instr)) (value-key (ir-cmp-right instr))))
    ((ir-unop? instr) (list 'unop (ir-unop-op instr) (value-key (ir-unop-operand instr))))
    (else #f)))

(define (cse-function fn)
  (define new-blocks
    (map (lambda (b)
           (define seen (make-hash))
           (define new-instrs null)
           (for-each (lambda (instr)
                       (define key (cse-hash-key instr))
                       (if (and key (hash-has-key? seen key))
                           (let ((existing-var (hash-ref seen key)))
                             (set! new-instrs (append new-instrs (list (ir-assign (ir-instr-result instr) existing-var)))))
                           (begin
                             (when key (hash-set! seen key (ir-instr-result instr)))
                             (set! new-instrs (append new-instrs (list instr))))))
                     (ir-block-instrs b))
           (ir-block (ir-block-label b) new-instrs (ir-block-terminator b)))
         (ir-function-blocks fn)))
  (ir-function (ir-function-name fn) (ir-function-params fn) (ir-function-return-type fn) new-blocks))

(define (cse-module m)
  (ir-module (map cse-function (ir-module-functions m)) (ir-module-globals m)))

(define (optimize-module m)
  (define m1 (constant-fold-module m))
  (define m2 (cse-module m1))
  (define m3 (dead-code-elim-module m2))
  m3)

(define (constant-fold m) (constant-fold-module m))
(define (dead-code-elim m) (dead-code-elim-module m))
(define (cse-elim m) (cse-module m))

;; ============================================================
;; Emitting (IR -> Racket)
;; ============================================================
(define (emit-value v)
  (cond
    ((ir-const? v)
     (let ((val (ir-const-value v)))
       (cond ((string? val) val)
             ((number? val) val)
             ((boolean? val) val)
             ((null? val) null)
             ((symbol? val) (list 'quote val))
             (else val))))
    ((ir-var? v) (ir-var-name v))
    ((ir-label? v) (ir-label-name v))
    (else v)))

(define (emit-binop-op-symbol op)
  (case op
    ((加) '+)
    ((减) '-)
    ((乘) '*)
    ((除) '/)
    ((模) 'modulo)
    ((幂) 'expt)
    ((大于) '>)
    ((小于) '<)
    ((等于) '=)
    ((不等) '(lambda (a b) (not (= a b))))
    ((大于等于) '>=)
    ((小于等于) '<=)
    (else op)))

(define (emit-unop-op-symbol op)
  (case op
    ((非) 'not)
    ((负) '-)
    ((长度) 'length)
    ((转整数) '(lambda (x) (inexact->exact (round x))))
    ((转浮点数) 'exact->inexact)
    ((转字符串) '(lambda (x) (format "~a" x)))
    ((字符串长度) 'string-length)
    ((字符串转列表) 'string->list)
    ((列表转字符串) 'list->string)
    ((随机整数) 'random)
    ((绝对值) 'abs)
    ((是整数) 'integer?)
    ((是浮点数) 'flonum?)
    ((是字符串) 'string?)
    ((是空) 'null?)
    ((正弦) 'sin)
    ((余弦) 'cos)
    ((正切) 'tan)
    ((自然对数) 'log)
    ((指数) 'exp)
    ((阶乘) '(letrec ((f (lambda (n) (if (<= n 1) 1 (* n (f (- n 1)))))) f)))
    ((打印) '(lambda (x) (begin (display x) x)))
    ((输入) '(lambda () (read-line)))
    (else op)))

(define (is-temp-var? s)
  (and (symbol? s) (string-prefix? (symbol->string s) "%")))

;; emit-instr-seq: 按顺序 emit 一条指令，返回 (list 'set! var rhs) 或 rhs
(define (emit-instr-seq instr)
  (cond
    ((ir-assign? instr)
     (let ((rhs (emit-value (ir-assign-source instr))))
       (if (ir-instr-result instr)
           (list 'set! (ir-var-name (ir-instr-result instr)) rhs)
           rhs)))
    ((ir-load? instr)
     (let ((rhs (string->symbol (ir-load-var-name instr))))
       (if (ir-instr-result instr)
           (list 'set! (ir-var-name (ir-instr-result instr)) rhs)
           rhs)))
    ((ir-store? instr)
     (list 'set! (string->symbol (ir-store-var-name instr)) (emit-value (ir-store-value instr))))
    ((ir-binop? instr)
     (let ((rhs (list (emit-binop-op-symbol (ir-binop-op instr))
                      (emit-value (ir-binop-left instr))
                      (emit-value (ir-binop-right instr)))))
       (if (ir-instr-result instr)
           (list 'set! (ir-var-name (ir-instr-result instr)) rhs)
           rhs)))
    ((ir-cmp? instr)
     (let ((rhs (list (emit-binop-op-symbol (ir-cmp-op instr))
                      (emit-value (ir-cmp-left instr))
                      (emit-value (ir-cmp-right instr)))))
       (if (ir-instr-result instr)
           (list 'set! (ir-var-name (ir-instr-result instr)) rhs)
           rhs)))
    ((ir-unop? instr)
     (let ((rhs (list (emit-unop-op-symbol (ir-unop-op instr))
                      (emit-value (ir-unop-operand instr)))))
       (if (ir-instr-result instr)
           (list 'set! (ir-var-name (ir-instr-result instr)) rhs)
           rhs)))
    ((ir-call? instr)
     (let* ((fn-name (ir-call-fn instr))
            (args (map emit-value (ir-call-args instr)))
            (rhs (case fn-name
                   ((列表) (cons 'list args))
                   ((打印) (if (pair? args)
                               (list 'begin (cons 'display args) (car args))
                               '(begin (display "") (void))))
                   (else (cons fn-name args)))))
       (if (ir-instr-result instr)
           (list 'set! (ir-var-name (ir-instr-result instr)) rhs)
           rhs)))
    ((ir-phi? instr)
     (let ((rhs (emit-value (cdar (ir-phi-edges instr)))))
       (if (ir-instr-result instr)
           (list 'set! (ir-var-name (ir-instr-result instr)) rhs)
           rhs)))
    ((ir-ret? instr)
     (emit-value (ir-ret-value instr)))
    (else '(void))))

;; 收集一个 block 中所有 %-var
(define (collect-temp-vars b)
  (define vars null)
  (for-each (lambda (instr)
              (when (ir-instr-result instr)
                (set! vars (cons (ir-var-name (ir-instr-result instr)) vars))))
            (ir-block-instrs b))
  (reverse vars))

;; emit 一个简单 block（无控制流），按顺序执行
(define (emit-simple-block b)
  (define instrs (ir-block-instrs b))
  (define temp-vars (collect-temp-vars b))
  (define stmts (map emit-instr-seq instrs))
  (define term (ir-block-terminator b))
  (define return-expr
    (cond
      ((ir-ret? term) (emit-value (ir-ret-value term)))
      (else
       (if (null? stmts)
           '(void)
           (let ((last-s (last stmts)))
             (if (and (list? last-s) (not (null? last-s)) (equal? (car last-s) 'set!))
                 (caddr last-s)
                 last-s))))))
  (define body-stmts
    (filter (lambda (s) (and (list? s) (not (null? s)) (equal? (car s) 'set!))) stmts))
  (if (null? temp-vars)
      (if (null? body-stmts)
          return-expr
          (cons 'begin (append body-stmts (list return-expr))))
      (list 'let (map (lambda (v) (list v #f)) temp-vars)
            (cons 'begin (append body-stmts (list return-expr))))))

;; 为指定前驱标签，在后继块中用对应 phi 值展开
(define (emit-block-from-predecessor b label-map visited from-label)
  (define label (ir-label-name (ir-block-label b)))
  (when (set-member? visited label)
    '(void))
  (set-add! visited label)
  (define instrs (ir-block-instrs b))
  ;; 处理 phi 节点：根据来源标签选择对应的值
  (define (emit-phi-instr instr)
    (let ((edges (ir-phi-edges instr)))
      (define chosen-val
        (let loop ((es edges))
          (cond
            ((null? es) (cdar edges))  ;; 没找到，用第一条
            ((equal? (car (car es)) from-label) (cdr (car es)))
            (else (loop (cdr es))))))
      (if (ir-instr-result instr)
          (list 'set! (ir-var-name (ir-instr-result instr)) (emit-value chosen-val))
          (emit-value chosen-val))))
  (define (emit-instr-for-pred instr)
    (if (ir-phi? instr)
        (emit-phi-instr instr)
        (emit-instr-seq instr)))
  (define stmts (map emit-instr-for-pred instrs))
  (define temp-vars (filter-map (lambda (instr)
                                   (and (ir-instr-result instr)
                                        (ir-var-name (ir-instr-result instr))))
                                 instrs))
  (define body-stmts
    (filter (lambda (s) (and (list? s) (not (null? s)) (equal? (car s) 'set!))) stmts))
  (define term (ir-block-terminator b))
  (define main-body
    (cond
      ((ir-ret? term) (emit-value (ir-ret-value term)))
      ((ir-cond-br? term)
       (let* ((cond-expr (emit-value (ir-cond-br-cond term)))
              (then-label-name (ir-label-name (ir-cond-br-then-label term)))
              (else-label-name (ir-label-name (ir-cond-br-else-label term)))
              (then-block (hash-ref label-map then-label-name #f))
              (else-block (hash-ref label-map else-label-name #f)))
         (list 'if cond-expr
               (if then-block (emit-block-from-predecessor then-block label-map visited label) '(void))
               (if else-block (emit-block-from-predecessor else-block label-map visited label) '(void)))))
      ((ir-br? term)
       (let ((target (hash-ref label-map (ir-label-name (ir-br-target term)) #f)))
         (if target
             (emit-block-from-predecessor target label-map visited label)
             '(void))))
      (else
       (if (null? stmts)
           '(void)
           (let ((last-s (last stmts)))
             (if (and (list? last-s) (not (null? last-s)) (equal? (car last-s) 'set!))
                 (caddr last-s)
                 last-s))))))
  (let ((all-stmts (append body-stmts (list main-body))))
    (if (null? temp-vars)
        (if (= (length all-stmts) 1)
            (car all-stmts)
            (cons 'begin all-stmts))
        (list 'let (map (lambda (v) (list v #f)) temp-vars)
              (if (= (length all-stmts) 1)
                  (car all-stmts)
                  (cons 'begin all-stmts))))))

;; emit 一个 block 及其后继（处理 if + merge）
(define (emit-block-with-control-flow b label-map visited)
  (emit-block-from-predecessor b label-map visited #f))

(define (emit-function fn)
  (define blocks (ir-function-blocks fn))
  (define name (string->symbol (ir-function-name fn)))
  (define params (map ir-var-name (ir-function-params fn)))

  (define label-map (make-hash))
  (for-each (lambda (b) (hash-set! label-map (ir-label-name (ir-block-label b)) b)) blocks)

  (define main-body
    (if (= (length blocks) 1)
        (emit-simple-block (car blocks))
        (emit-block-from-predecessor (car blocks) label-map (mutable-set) #f)))

  (list 'define (cons name params) main-body))

;; emit-module: 区分 __init__ 顶级代码和普通函数
(define (emit-module m)
  (define funcs (ir-module-functions m))
  (define top-level-exprs null)
  (define func-defs null)
  (for-each (lambda (fn)
              (if (string=? (ir-function-name fn) "__init__")
                  ;; __init__: 变成一系列顶级表达式
                  (let* ((blocks (ir-function-blocks fn))
                         (label-map (make-hash)))
                    (for-each (lambda (b) (hash-set! label-map (ir-label-name (ir-block-label b)) b)) blocks)
                    (define body
                      (if (= (length blocks) 1)
                          (emit-simple-block (car blocks))
                          (emit-block-from-predecessor (car blocks) label-map (mutable-set) #f)))
                    ;; 如果是 begin 形式，拆成多个
                    (if (and (list? body) (not (null? body)) (equal? (car body) 'begin))
                        (set! top-level-exprs (append top-level-exprs (cdr body)))
                        (set! top-level-exprs (append top-level-exprs (list body)))))
                  (set! func-defs (append func-defs (list (emit-function fn))))))
            funcs)
  (append func-defs top-level-exprs))

;; ============================================================
;; 顶层接口
;; ============================================================
(define use-ir-optimization? (make-parameter #t))

(define (ast->ir ast (builtin-names null))
  (define m (lower-module ast builtin-names))
  (optimize-module m))

(define (module->racket ast (builtin-names null))
  (if (use-ir-optimization?)
      (let ((ir (ast->ir ast builtin-names)))
        (emit-module ir))
      ast))
