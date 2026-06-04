#lang racket/base
(require "../std/json.rkt"
         "../std/csv.rkt"
         "../std/datetime.rkt"
         "../std/math.rkt"
         "../std/string.rkt"
         "../std/re.rkt"
         "../std/collections.rkt"
         "../std/configparser.rkt"
         "../std/os.rkt")

;; ============================================================
;; 明道标准库综合使用示例
;; 运行: racket examples/std-demo.rkt
;; ============================================================

(printf "╔══════════════════════════════════════════╗\n")
(printf "║      明道标准库 - 综合演示               ║\n")
(printf "╚══════════════════════════════════════════╝\n\n")

;; ─── 1. JSON ───────────────────────────────────────────────

(printf "=== 1. JSON 模块 ===\n")
(define data (json解析 "{\"name\":\"明道\",\"version\":1,\"tags\":[\"lang\",\"racket\"]}"))
(printf "  json解析: ~s\n" data)
(printf "  json生成: ~s\n" (json生成 #hash(("name" . "小明") ("age" . 10))))
(newline)

;; ─── 2. CSV ────────────────────────────────────────────────

(printf "=== 2. CSV 模块 ===\n")
(define csv-text "姓名,年龄,城市\n张三,28,北京\n李四,35,上海\n王五,30,深圳")
(define rows (csv解析 csv-text))
(printf "  CSV 解析: ~s\n" rows)
(printf "  CSV 生成: ~s\n" (csv生成 '(("name" "score") ("Alice" "95") ("Bob" "87"))))
(newline)

;; ─── 3. Math ───────────────────────────────────────────────

(printf "=== 3. Math 模块 ===\n")
(printf "  π = ~a\n" 圆周率)
(printf "  正弦(π/2) = ~a\n" (正弦 (/ 圆周率 2)))
(printf "  5! = ~a\n" (阶乘 5))
(printf "  C(10,3) = ~a\n" (组合数 10 3))
(printf "  P(10,3) = ~a\n" (排列数 10 3))
(printf "  最大公约数(24, 36) = ~a\n" (最大公约数 24 36))
(newline)

;; ─── 4. String ─────────────────────────────────────────────

(printf "=== 4. String 模块 ===\n")
(printf "  大写: ~a\n" (字符串/大写 "hello世界"))
(printf "  驼峰转下划线: ~a\n" (字符串/驼峰转下划线 "userName"))
(printf "  模板: ~a\n" (字符串/模板 "你好，{0}！今天是{1}。" "张三" "周一"))
(printf "  反转: ~a\n" (字符串/反转 "明道"))
(newline)

;; ─── 5. 正则 ──────────────────────────────────────────────

(printf "=== 5. 正则模块 ===\n")
(printf "  搜索: ~s\n" (正则搜索 "\\d{3}-\\d{4}" "电话: 010-8888"))
(printf "  分割: ~s\n" (正则分割 "\\s+" "a  b\tc"))
(printf "  全部替换: ~s\n" (正则全部替换 "\\d" "a1b2c3" "X"))
(newline)

;; ─── 6. Datetime ──────────────────────────────────────────

(printf "=== 6. Datetime 模块 ===\n")
(printf "  今天: ~a\n" (今天))
(printf "  现在: ~a\n" (现在))
(printf "  星期: ~a\n" (日期/星期 (今天)))
(printf "  差5天: 从 2025-01-10 到 2025-01-15 = ~a天\n" (日期/差 "2025-01-10" "2025-01-15"))
(printf "  2024-02 天数: ~a (闰年)\n" (天数 2024 2))
(printf "  时间戳: ~a\n" (现在时间戳))
(newline)

;; ─── 7. OS ────────────────────────────────────────────────

(printf "=== 7. OS 模块 ===\n")
(printf "  系统名称: ~a\n" (系统名称))
(printf "  PID: ~a\n" (获取pid))
(printf "  当前目录: ~a\n" (获取cwd))
(printf "  开始目录: ~a\n" (开始目录))
(printf "  路径分隔符: ~a\n" 路径分隔符)
(newline)

;; ─── 8. Collections ────────────────────────────────────────

(printf "=== 8. Collections 模块 ===\n")
(define word-list '("苹果" "香蕉" "苹果" "橘子" "香蕉" "苹果"))
(define counter (计数器/创建 word-list))
(printf "  单词统计: ~s\n" counter)
(printf "  频次最高: ~s\n" (计数器/最多 counter 2))

;; defaultdict
(define dd (默认字典/创建 (λ () 0)))
(默认字典/获取 dd "a")
(默认字典/获取 dd "b")
(默认字典/获取 dd "a")
(printf "  defaultdict: ~s\n" dd)

;; namedtuple
(define Point (命名元组/创建 "Point" "x" "y" "z"))
(define p (命名元组/新建 Point 1 2 3))
(printf "  namedtuple: ~s\n" p)

;; OrderedDict
(define od (有序字典/创建))
(有序字典/设置 od "a" 1)
(有序字典/设置 od "b" 2)
(有序字典/设置 od "c" 3)
(printf "  有序字典: ~s\n" (有序字典/转为列表 od))
(newline)

;; ─── 9. ConfigParser ──────────────────────────────────────

(printf "=== 9. ConfigParser 模块 ===\n")
(define cfg (配置/创建))
(配置/读取字符串 cfg "[database]\nhost = localhost\nport = 5432\n[app]\nname = MyApp\ndebug = true")
(printf "  DB host: ~a\n" (配置/获取 cfg "database" "host"))
(printf "  DB port: ~a (整数)\n" (配置/获取整数 cfg "database" "port"))
(printf "  debug: ~a (布尔)\n" (配置/获取布尔 cfg "app" "debug"))
(printf "  节列表: ~s\n" (配置/节列表 cfg))
(newline)

;; ─── 总结 ──────────────────────────────────────────────────

(printf "\n╔══════════════════════════════════════════╗\n")
(printf "║      演示完成！                           ║\n")
(printf "╚══════════════════════════════════════════╝\n")