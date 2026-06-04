#lang racket
;; 明道标准库测试 - ConfigParser 模块
(require "../std/configparser.rkt"
         "../lang/test.rkt")

(测试组 "ConfigParser 模块 - 创建"
  (λ ()
    (测试 "配置/创建 - 默认节"
      (λ ()
        (define cfg (配置/创建))
        (断言相等 "DEFAULT" (配置/默认节 cfg))))

    (测试 "配置/创建 - 自定义默认节"
      (λ ()
        (define cfg (配置/创建 "GLOBAL"))
        (断言相等 "GLOBAL" (配置/默认节 cfg)))))
)

(测试组 "ConfigParser 模块 - 读取字符串"
  (λ ()
    (测试 "配置/读取字符串 - 基本解析"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "[server]\nhost = localhost\nport = 8080")
        (断言相等 "localhost" (配置/获取 cfg "server" "host"))
        (断言相等 "8080" (配置/获取 cfg "server" "port")))))

  (λ ()
    (测试 "配置/读取字符串 - 注释行忽略"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "; 注释\n[sec]\nkey = val\n# 另一注释\na = b")
        (断言相等 "val" (配置/获取 cfg "sec" "key"))
        (断言相等 "b" (配置/获取 cfg "sec" "a")))))

  (λ ()
    (测试 "配置/读取字符串 - 默认节"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "key1 = val1\n[section]\nkey2 = val2")
        (断言相等 "val1" (配置/获取 cfg "DEFAULT" "key1"))
        (断言相等 "val2" (配置/获取 cfg "section" "key2")))))

  (λ ()
    (测试 "配置/读取字符串 - 默认值回退"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "timeout = 30\n[web]\nport = 80")
        (断言相等 "30" (配置/获取 cfg "web" "timeout")))))

  (λ ()
    (测试 "配置/读取字符串 - 空行处理"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "\n\n[sec]\n\nkey = val\n\n")
        (断言相等 "val" (配置/获取 cfg "sec" "key")))))

  (λ ()
    (测试 "配置/读取字符串 - 多节"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "[db]\nhost=localhost\n[app]\ndebug=true")
        (断言相等 "localhost" (配置/获取 cfg "db" "host"))
        (断言相等 "true" (配置/获取 cfg "app" "debug")))))
)

(测试组 "ConfigParser 模块 - 类型获取"
  (λ ()
    (测试 "配置/获取整数"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "[sec]\ncount = 42")
        (断言相等 42 (配置/获取整数 cfg "sec" "count")))))

  (λ ()
    (测试 "配置/获取浮点"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "[sec]\npi = 3.14")
        (断言相等 3.14 (配置/获取浮点 cfg "sec" "pi")))))

  (λ ()
    (测试 "配置/获取布尔 - true"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "[sec]\nflag = true")
        (断言测试 (配置/获取布尔 cfg "sec" "flag")))))

  (λ ()
    (测试 "配置/获取布尔 - 1/yes/on"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "[sec]\na=1\nb=yes\nc=on")
        (断言测试 (配置/获取布尔 cfg "sec" "a"))
        (断言测试 (配置/获取布尔 cfg "sec" "b"))
        (断言测试 (配置/获取布尔 cfg "sec" "c")))))

  (λ ()
    (测试 "配置/获取布尔 - false值"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "[sec]\nflag = 0")
        (断言相等 #f (配置/获取布尔 cfg "sec" "flag")))))
)

(测试组 "ConfigParser 模块 - 设置/删除"
  (λ ()
    (测试 "配置/设置 和 获取"
      (λ ()
        (define cfg (配置/创建))
        (配置/设置 cfg "sec" "key" "val")
        (断言相等 "val" (配置/获取 cfg "sec" "key")))))

  (λ ()
    (测试 "配置/删除"
      (λ ()
        (define cfg (配置/创建))
        (配置/设置 cfg "sec" "key" "val")
        (配置/删除 cfg "sec" "key")
        (断言相等 #f (配置/获取 cfg "sec" "key")))))
)

(测试组 "ConfigParser 模块 - 查询"
  (λ ()
    (测试 "配置/有节 - 存在"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "[sec]\nk=v")
        (断言测试 (配置/有节 cfg "sec"))))

    (测试 "配置/有节 - 不存在"
      (λ ()
        (define cfg (配置/创建))
        (断言相等 #f (配置/有节 cfg "nonexistent")))))

  (λ ()
    (测试 "配置/有选项 - 存在/不存在"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "[sec]\nk=v")
        (断言测试 (配置/有选项 cfg "sec" "k"))
        (断言相等 #f (配置/有选项 cfg "sec" "nonexistent"))
        (断言相等 #f (配置/有选项 cfg "nosection" "k")))))

  (λ ()
    (测试 "配置/节列表"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "[a]\nx=1\n[b]\ny=2")
        (define sections (配置/节列表 cfg))
        (断言测试 (member "a" sections))
        (断言测试 (member "b" sections)))))

  (λ ()
    (测试 "配置/选项列表"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "[sec]\na=1\nb=2")
        (define opts (配置/选项列表 cfg "sec"))
        (断言相等 2 (length opts))
        (断言测试 (member "a" opts))
        (断言测试 (member "b" opts)))))
)

(测试组 "ConfigParser 模块 - 节操作"
  (λ ()
    (测试 "配置/添加节"
      (λ ()
        (define cfg (配置/创建))
        (配置/添加节 cfg "newsec")
        (断言测试 (配置/有节 cfg "newsec"))))

    (测试 "配置/移除节"
      (λ ()
        (define cfg (配置/创建))
        (配置/添加节 cfg "temp")
        (配置/移除节 cfg "temp")
        (断言相等 #f (配置/有节 cfg "temp")))))
)

(测试组 "ConfigParser 模块 - 写入和往返"
  (λ ()
    (测试 "配置/写入 ⇒ 配置/读取字符串 往返"
      (λ ()
        (define cfg (配置/创建))
        (配置/读取字符串 cfg "[sec]\nkey = val\n[sec2]\na = b")
        (define out-port (open-output-string))
        (配置/写入 cfg out-port)
        (define output (get-output-string out-port))
        (close-output-port out-port)
        (断言测试 (string-contains? output "[sec]"))
        (断言测试 (string-contains? output "key = val"))
        (define cfg2 (配置/创建))
        (配置/读取字符串 cfg2 output)
        (断言相等 "val" (配置/获取 cfg2 "sec" "key"))
        (断言相等 "b" (配置/获取 cfg2 "sec2" "a")))))
)

(运行测试)