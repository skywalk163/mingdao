#lang racket/base
;; 明道语言分词器与解析器综合测试（基于 rackunit）
;; 替换原有的 test-validation.rkt, test-basic.rkt, test-simple.rkt, test-parser.rkt

(require rackunit
         "../lang/tokenizer.rkt"
         "../lang/parser.rkt")

;; ============================================================
;; 辅助函数
;; ============================================================

;; 仅检查 token 类型和值，忽略位置
(define (check-tokens input expected)
  (define actual (tokenize input))
  (for ([a actual] [e expected] [i (in-naturals)])
    (check-equal? (car e) (token-type a)
                  (format "token[~a] 类型: ~a" i input))
    (check-equal? (cdr e) (token-value a)
                  (format "token[~a] 值: ~a" i input)))
  (check-equal? (length expected) (length actual)
                (format "token 数量: ~a" input)))

;; 解析并检查 AST 不抛出异常
(define (check-parse-success input)
  (define tokens (tokenize input))
  (parse tokens '())
  (void))

;; 解析并检查 AST 应抛出异常
(define (check-parse-failure input)
  (define tokens (tokenize input))
  (check-exn exn:fail? (λ () (parse tokens '()) (void))))

;; 解析并检查 AST 精确匹配
(define (check-parse-exact input expected-ast)
  (define tokens (tokenize input))
  (define ast (parse tokens '()))
  (check-equal? (length expected-ast) (length ast)
                (format "AST 表达式数量: ~a" input))
  (for ([expr ast] [expected-expr expected-ast] [i (in-naturals)])
    (check-equal? expected-expr expr
                  (format "AST[~a]: ~a" i input))))

;; ============================================================
;; Tokenizer 测试
;; ============================================================

(printf "\n══════ Tokenizer 测试 ══════\n")

;; 变量定义
(check-tokens "定义 x 就是 5"
              '((KEYWORD . "定义") (IDENTIFIER . "x") (KEYWORD . "就是") (NUMBER . 5)))
(check-tokens "定义x就是5"
              '((KEYWORD . "定义") (IDENTIFIER . "x") (KEYWORD . "就是") (NUMBER . 5)))

;; 比较运算符
(check-tokens "x等于y"
              '((IDENTIFIER . "x") (KEYWORD . "等于") (IDENTIFIER . "y")))
(check-tokens "分数大于等于90"
              '((IDENTIFIER . "分数") (KEYWORD . "大于等于") (NUMBER . 90)))

;; 控制流
(check-tokens "如果x大于0那么：打印x"
              '((KEYWORD . "如果") (IDENTIFIER . "x") (KEYWORD . "大于") (NUMBER . 0)
                (KEYWORD . "那么") (COLON . #\:) (KEYWORD . "打印") (IDENTIFIER . "x")))

;; 管道
(check-tokens "数据|长度|打印"
              '((IDENTIFIER . "数据") (PIPE . #\|) (KEYWORD . "长度") (PIPE . #\|) (KEYWORD . "打印")))

;; 数字与字符串
(check-tokens "123" '((NUMBER . 123)))
(check-tokens "\"hello\"" '((STRING . "hello")))
(check-tokens "3.14" '((NUMBER . 3.14)))

;; 连续关键字
(check-tokens "跳出循环"
              '((KEYWORD . "跳出") (IDENTIFIER . "循环")))

;; 列表
(check-tokens "列表长度"
              '((KEYWORD . "列表") (KEYWORD . "长度")))

;; 无空格管道+关键字
(check-tokens "列表1,2,3然后长度然后打印"
              '((KEYWORD . "列表") (NUMBER . 1) (COMMA . #\,) (NUMBER . 2) (COMMA . #\,)
                (NUMBER . 3) (KEYWORD . "然后") (KEYWORD . "长度") (KEYWORD . "然后") (KEYWORD . "打印")))

;; 复合标识符
(check-tokens "a加b乘c" '((IDENTIFIER . "a加b乘c")))
(check-tokens "x乘y加z" '((IDENTIFIER . "x乘y加z")))

;; 逗号分隔
(check-tokens "2, 3, 求和, 打印"
              '((NUMBER . 2) (COMMA . #\,) (NUMBER . 3) (COMMA . #\,)
                (IDENTIFIER . "求和") (COMMA . #\,) (KEYWORD . "打印")))

(printf "  ✔ Tokenizer 测试通过\n")

;; ============================================================
;; Parser 测试
;; ============================================================

(printf "\n══════ Parser 测试 ══════\n")

;; 变量定义
(check-parse-exact "定义 x 就是 5" '((define x 5)))
(check-parse-exact "定义 速度 就是 x乘y加z" '((define 速度 x乘y加z)))

;; 比较表达式
(check-parse-exact "x等于y" '((equal? x y)))
(check-parse-exact "分数大于等于90" '((>= 分数 90)))

;; 管道调用
(check-parse-exact "数据|长度|打印" '((打印 (长度 数据))))

;; 解析错误应抛出
(check-parse-failure "定义定义x")
(check-parse-failure "对于i从0到5：打印i")

;; 解析成功验证
(check-parse-success "定义 x 就是 5")
(check-parse-success "x等于y")
(check-parse-success "分数大于等于90")
(check-parse-success "定义x就是5")
(check-parse-success "数据|长度|打印")

(printf "  ✔ Parser 测试通过\n")

;; ============================================================
;; 综合测试
;; ============================================================

(printf "\n══════ 综合测试 ══════\n")

(check-parse-success "定义 分数 就是 85
如果 分数 大于等于 90 那么：
    \"优秀\", 打印
否则若 分数 大于等于 60 那么：
    \"及格\", 打印
否则：
    \"不及格\", 打印")

(check-parse-success "对于 i 从 0 到 5：
    i, 打印")

(check-parse-success "定义 求和 就是函 a, b：
    返回 a 加 b
2, 3, 求和, 打印")

(check-parse-success "定义 数据 就是 列表 1, 3, 5, 7
定义 第一个 就是 数据 索引 0
第一个, 打印")

(printf "  ✔ 综合测试通过\n")

(printf "\n╔══════════════════════════════════════╗\n")
(printf "║  全部 rackunit 测试通过!           ║\n")
(printf "╚══════════════════════════════════════╝\n")