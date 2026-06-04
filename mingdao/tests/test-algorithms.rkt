#lang racket
;; 明道语言算法综合测试
;; 测试：汉诺塔、冒泡排序、图灵机

(require "../lang/tokenizer.rkt"
         "../lang/parser.rkt"
         racket/list
         racket/string)

(define (execute code name)
  (displayln (format "\n========================================"))
  (displayln (format "【~a】" name))
  (displayln "========================================")
  (displayln (format "代码:\n~a\n" code))
  (define tokens (tokenize code))
  (define ast (parse tokens))
  (displayln (format "AST:\n~a\n" ast))
  (displayln "执行结果:")
  (define ns (make-base-namespace))
  (define core-path
    (path->string (build-path (current-directory) ".." "core.rkt")))
  (eval `(require (file ,core-path)) ns)
  (with-handlers ([exn:fail? (lambda (e) (displayln (format "错误: ~a" (exn-message e))))])
    (for ([stmt ast])
      (eval stmt ns))))

(displayln "========================================")
(displayln "明道语言算法综合测试")
(displayln "测试：汉诺塔、冒泡排序、图灵机")
(displayln "========================================")

;; ========== 测试1：汉诺塔(3层) ==========
(define hanoi3-code
  #<<MINGDAO
定义 汉诺塔 就是函 n, 源, 目标, 辅助：
    如果 n 等于 0 那么：
        返回
    否则：
        汉诺塔, n 减 1, 源, 辅助, 目标
        "从 ", 源, " 移动到 ", 目标, 消息拼接, 打印
        汉诺塔, n 减 1, 辅助, 目标, 源

汉诺塔, 3, "A", "C", "B"
MINGDAO
)
(execute hanoi3-code "汉诺塔(3层)")

;; ========== 测试2：汉诺塔无空格版(3层) ==========
(define hanoi-nospace-code
  #<<MINGDAO
定义汉诺塔就是函n,源,目标,辅助：
 如果n等于0那么：
  返回
 否则：
  汉诺塔,(n,减,1),源,辅助,目标
  定义消息就是消息拼接,"从",源,"移动到",目标
  打印,消息
  汉诺塔,(n,减,1),辅助,目标,源

汉诺塔,3,"A","C","B"
MINGDAO
)
(execute hanoi-nospace-code "汉诺塔无空格版(3层)")

;; ========== 测试3：汉诺塔(4层) ==========
(define hanoi4-code
  #<<MINGDAO
定义 汉诺塔 就是函 n, 源, 目标, 辅助：
    如果 n 等于 0 那么：
        返回
    否则：
        汉诺塔, n 减 1, 源, 辅助, 目标
        "从 ", 源, " 移动到 ", 目标, 消息拼接, 打印
        汉诺塔, n 减 1, 辅助, 目标, 源

汉诺塔, 4, "A", "D", "C"
MINGDAO
)
(execute hanoi4-code "汉诺塔(4层)")

;; ========== 测试4：冒泡排序 ==========
(define bubble-code
  #<<MINGDAO
定义 冒泡排序 就是函 arr：
    定义 n 就是 arr, 长度
    对于 i 从 0 到 n 减 1：
        对于 j 从 0 到 n 减 1 减 i：
            如果 arr, j, 索引 大于 arr, j 加 1, 索引 那么：
                定义 当前 就是 索引, arr, j
                定义 下一个 就是 索引, arr, j 加 1
                赋值 arr 为 列表修改, arr, j, 下一个
                赋值 arr 为 列表修改, arr, j 加 1, 当前
    返回 arr

定义 数据 就是 列表 5, 3, 8, 1, 9, 2
数据, 冒泡排序, 打印
MINGDAO
)
(execute bubble-code "冒泡排序")

;; ========== 测试5：图灵机（模拟二进制加法） ==========
(define turing-code
  #<<MINGDAO
定义 运行 就是函 状态, 纸带, 位置, 规则表：
    定义 当前符号 就是 索引, 纸带, 位置
    如果 当前符号 等于 空值 那么：
        返回 纸带
    定义 索引位置 就是 2 乘 状态 加 当前符号
    定义 规则 就是 索引, 规则表, 索引位置
    如果 规则 等于 空值 那么：
        返回 纸带
    否则：
        定义 写入 就是 索引, 规则, 0
        定义 移动 就是 索引, 规则, 1
        定义 新状态 就是 索引, 规则, 2
        赋值 纸带 为 列表修改, 纸带, 位置, 写入
        如果 移动 等于 1 那么：
            赋值 位置 为 位置 加 1
        否则：
            赋值 位置 为 位置 减 1
        运行, 新状态, 纸带, 位置, 规则表

定义 纸带 就是 列表 1, 0, 1, 0, 0, 1, 1, 0
定义 规则表 就是 列表
    列表 1, 1, 0,
    列表 0, 1, 1,
    列表 1, 1, 1,
    列表 0, 0, 2,
    列表 0, 1, 2,
    列表 1, 1, 2
运行, 0, 纸带, 0, 规则表
MINGDAO
)
(execute turing-code "图灵机(模拟)")

(displayln "\n========================================")
(displayln "所有算法测试完成！")
(displayln "========================================")