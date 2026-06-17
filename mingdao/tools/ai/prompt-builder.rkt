#lang racket/base

(require racket/string racket/list racket/hash)

(provide 构造系统提示词
         构造上下文提示词
         构造用户提示词
         构造完整提示词
         构造消息列表
         提取代码)

;; ============================================================
;; 系统提示词 — 描述明道语言规范
;; ============================================================
(define (构造系统提示词)
  (string-append
   "你是一个明道语言（Mingdao）代码生成助手。明道是一门面向中文使用者的编程语言。\n\n"
   "=== 明道语言语法概述 ===\n\n"
   "【关键字（双字关键字）】\n"
   "定义、如果、那么、否则、对于、跳出、返回、就是、就是函、常量、导入、导出、匹配、尝试\n\n"
   "【类型系统】\n"
   "整数、浮点数、字符串、布尔、空值、任意、列表、字典\n\n"
   "【注释】\n"
   "使用两个分号 ;; 作为单行注释\n\n"
   "【变量定义】\n"
   "语法：定义 变量名 就是 表达式\n"
   "示例：\n"
   "定义 x 就是 5\n"
   "定义 名字 就是 \"张三\"\n"
   "定义 年龄 就是 25\n\n"
   "【常量定义】\n"
   "语法：常量 变量名 就是 表达式\n"
   "示例：常量 PI 就是 3.14159\n\n"
   "【函数定义】\n"
   "语法：定义 函数名 就是函 参数1, 参数2, ... :\n"
   "    函数体\n"
   "    返回 结果\n\n"
   "【函数调用（主谓宾语序）】\n"
   "语法：参数1, 参数2, ..., 函数名\n"
   "重要：函数名放在最后，参数放在前面，用逗号分隔\n"
   "示例：\n"
   "1, 2, 加              ;; 等价于 加(1, 2) = 3\n"
   "3, 打印               ;; 等价于 打印(3)\n"
   "\"hello\", \"world\", 拼接 ;; 等价于 拼接(\"hello\", \"world\")\n"
   "1, 2, 3, 列表         ;; 等价于 列表(1, 2, 3)\n\n"
   "【条件语句】\n"
   "语法：如果 条件 那么：\n"
   "    语句块\n"
   "否则：\n"
   "    语句块\n\n"
   "【循环语句】\n"
   "语法：对于 变量 从 起始 到 结束：\n"
   "    循环体\n"
   "可用 跳出 中断循环\n\n"
   "【赋值语句】\n"
   "语法：赋值 变量 为 新值\n\n"
   "【模块导入/导出】\n"
   "导入 \"文件路径\"\n"
   "导出 符号1 符号2 ...\n\n"
   "【错误处理】\n"
   "尝试：\n"
   "    代码\n"
   "捕获 错误：\n"
   "    错误处理\n\n"
   "【比较运算符】\n"
   "大于、小于、等于、不等于、大于等于、小于等于\n\n"
   "【数学运算符】\n"
   "加、减、乘、除、整除、取余\n\n"
   "【逻辑运算符】\n"
   "与、或\n\n"
   "【内置函数】\n"
   "列表 — 构造列表\n"
   "长度 — 获取列表/字符串长度\n"
   "索引 — 获取列表指定位置元素\n"
   "列表修改 — 修改列表指定位置元素\n"
   "打印 — 输出内容\n"
   "加、减、乘、除 — 四则运算\n"
   "范围 — 生成范围列表\n"
   "拼接 — 字符串拼接\n"
   "转字符串 — 将值转为字符串\n"
   "空值 — 空值常量\n"
   "断言 — 断言检查\n"
   "报错 — 抛出错误\n\n"
   "=== 代码示例 ===\n\n"
   "【示例1：阶乘】\n"
   "定义 阶乘 就是函 n：\n"
   "    如果 n 小于等于 1 那么：\n"
   "        返回 1\n"
   "    否则：\n"
   "        返回 n 乘 阶乘, (n 减 1)\n\n"
   "【示例2：斐波那契数列】\n"
   "定义 斐波那契 就是函 n：\n"
   "    如果 n 小于等于 1 那么：\n"
   "        返回 n\n"
   "    否则：\n"
   "        返回 (斐波那契, (n 减 1)) 加 (斐波那契, (n 减 2))\n\n"
   "【示例3：冒泡排序】\n"
   "定义 冒泡排序 就是函 输入数组：\n"
   "    定义 数组长度 就是 长度, 输入数组\n"
   "    定义 数组 就是 输入数组\n"
   "    对于 i 从 0 到 数组长度 减 1：\n"
   "        对于 j 从 0 到 数组长度 减 i 减 1：\n"
   "            如果 (索引, 数组, j) 大于 (索引, 数组, (j 加 1)) 那么：\n"
   "                定义 临时值 就是 索引, 数组, j\n"
   "                赋值 数组 为 列表修改, 数组, j, (索引, 数组, (j 加 1))\n"
   "                赋值 数组 为 列表修改, 数组, (j 加 1), 临时值\n"
   "    返回 数组\n\n"
   "【示例4：列表遍历与打印】\n"
   "定义 数字 就是 列表 1, 2, 3, 4, 5\n"
   "对于 i 从 0 到 (长度, 数字) 减 1：\n"
   "    定义 值 就是 索引, 数字, i\n"
   "    值, 打印\n\n"
   "【示例5：简单问候函数】\n"
   "定义 问候 就是函 姓名：\n"
   "    定义 消息 就是 \"你好，\" 拼接 姓名 拼接 \"！\"\n"
   "    返回 消息\n\n"
   "\"世界\", 问候, 打印\n\n"
   "=== 输出约束 ===\n\n"
   "1. 只生成纯明道代码，不要任何 markdown 代码块标记\n"
   "2. 不要英文注释，注释必须使用中文（使用 ;; 开头）\n"
   "3. 严格遵守主谓宾语序：参数1, 参数2, ..., 函数名\n"
   "4. 确保代码语法正确，可以被明道解释器执行\n"
   "5. 如果用户请求涉及无法实现的功能，请在注释中说明原因\n"
   ""))

;; ============================================================
;; 上下文提示词 — 从上下文 hash 构造附加提示
;; ============================================================
(define (构造上下文提示词 ctx-hash)
  (define parts (list))
  (when (and ctx-hash (hash? ctx-hash))
    (when (hash-has-key? ctx-hash '文件上下文)
      (set! parts (cons (format "当前编辑的文件：~a" (hash-ref ctx-hash '文件上下文))
                        parts)))
    (when (hash-has-key? ctx-hash '项目概述)
      (set! parts (cons (format "项目概述：~a" (hash-ref ctx-hash '项目概述))
                        parts)))
    (when (hash-has-key? ctx-hash '符号上下文)
      (define syms (hash-ref ctx-hash '符号上下文))
      (set! parts (cons (format "已有变量/函数定义：~a"
                                (if (string? syms)
                                    syms
                                    (string-join (map (lambda (s) (format "~a" s)) syms) "、")))
                        parts))))
  (if (empty? parts)
      ""
      (string-join (reverse parts) "\n")))

;; ============================================================
;; 用户提示词 — 将中文需求包装成清晰指令
;; ============================================================
(define (构造用户提示词 用户需求)
  (string-append
   "请根据以下需求生成明道语言代码：\n\n"
   用户需求
   "\n\n"
   "要求：\n"
   "1. 严格遵循明道语言语法规范\n"
   "2. 使用主谓宾语序：参数1, 参数2, ..., 函数名\n"
   "3. 只输出纯明道代码，不含 markdown 标记，不含英文注释\n"
   "4. 代码必须可以直接被明道解释器执行\n"))

;; ============================================================
;; 完整提示词 — 系统 + 上下文 + 用户
;; ============================================================
(define (构造完整提示词 用户需求 . 上下文)
  (define sys (构造系统提示词))
  (define ctx (if (and (not (empty? 上下文))
                       (not (empty? (first 上下文))))
                  (let ([c (first 上下文)])
                    (if (string? c)
                        c
                        (构造上下文提示词 c)))
                  ""))
  (define usr (构造用户提示词 用户需求))
  (if (string=? ctx "")
      (string-append sys "\n\n" usr)
      (string-append sys "\n\n=== 上下文信息 ===\n" ctx "\n\n" usr)))

;; ============================================================
;; 消息列表 — chat-completion 风格
;; ============================================================
(define (构造消息列表 用户需求 . 上下文)
  (define sys (构造系统提示词))
  (define ctx (if (and (not (empty? 上下文))
                       (not (empty? (first 上下文))))
                  (let ([c (first 上下文)])
                    (if (string? c)
                        c
                        (构造上下文提示词 c)))
                  ""))
  (define usr (构造用户提示词 用户需求))
  (define 用户内容 (if (string=? ctx "")
                       usr
                       (string-append "=== 上下文信息 ===\n" ctx "\n\n" usr)))
  (list (hash 'role "system" 'content sys)
        (hash 'role "user" 'content 用户内容)))

;; ============================================================
;; 提取代码 — 从模型响应中提取明道代码
;; ============================================================
(define (string-index-of s sub [start 0])
  (define len-s (string-length s))
  (define len-sub (string-length sub))
  (and (<= len-sub len-s)
       (let loop ([i start])
         (cond
           [(> (+ i len-sub) len-s) #f]
           [(string=? (substring s i (+ i len-sub)) sub) i]
           [else (loop (+ i 1))]))))

;; 从 s 中查找 ```mingdao ... ``` 形式的代码块
(define (extract-mingdao-block s)
  (define start-tag "```mingdao")
  (define start-idx (string-index-of s start-tag))
  (and start-idx
       (let* ([after-tag (+ start-idx (string-length start-tag))]
              [rest (substring s after-tag)]
              ;; 去掉紧跟的换行（可能是 \r\n 或 \n）
              [body-start (cond
                            [(and (< 1 (string-length rest))
                                  (string=? (substring rest 0 2) "\r\n")) 2]
                            [(and (< 0 (string-length rest))
                                  (char=? (string-ref rest 0) #\newline)) 1]
                            [else 0])]
              [body (substring rest body-start)]
              [end-idx (string-index-of body "```")])
         (and end-idx (string-trim (substring body 0 end-idx))))))

;; 从 s 中查找 ```... ``` 形式的代码块（跳过可选语言标签）
(define (extract-generic-block s)
  (define start-tag "```")
  (define start-idx (string-index-of s start-tag))
  (and start-idx
       (let* ([after-tag (+ start-idx (string-length start-tag))]
              [rest (substring s after-tag)]
              [nl-idx (string-index-of rest "\n")])
         (and nl-idx
              (let ([body (substring rest (+ nl-idx 1))])
                (define end-idx (string-index-of body "```"))
                (and end-idx (string-trim (substring body 0 end-idx))))))))

(define (提取代码 ai-response-text)
  (define text ai-response-text)
  (cond
    [(extract-mingdao-block text) => values]
    [(extract-generic-block text) => values]
    [else (string-trim text)]))

;; ============================================================
;; 模块自测（加载时无副作用）
;; ============================================================
(module+ main
  (printf "明道语言提示词构造器已加载。~n")
  (printf "提供函数：~n")
  (printf "  - 构造系统提示词~n")
  (printf "  - 构造上下文提示词~n")
  (printf "  - 构造用户提示词~n")
  (printf "  - 构造完整提示词~n")
  (printf "  - 构造消息列表~n")
  (printf "  - 提取代码~n"))
