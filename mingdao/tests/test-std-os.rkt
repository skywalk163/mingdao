#lang racket
;; 明道标准库测试 - OS 模块
(require "../std/os.rkt"
         "../lang/test.rkt"
         racket/file
         racket/path)

(测试组 "OS 模块 - 路径和目录"
  (λ ()
    (测试 "获取cwd 返回当前工作目录"
      (λ ()
        (define result (获取cwd))
        (断言测试 (path? result) "返回路径类型"))))

  (λ ()
    (测试 "路径拼接"
      (λ ()
        (define result (路径拼接 "a" "b" "c.txt"))
        (断言相等 (string->path "a\\b\\c.txt") result))))

  (λ ()
    (测试 "绝对路径"
      (λ ()
        (define cwd (获取cwd))
        (define result (绝对路径 "."))
        (断言相等 (resolve-path ".") result))))

  (λ ()
    (测试 "系统分隔符 是字符串"
      (λ ()
        (断言测试 (string? 路径分隔符) "分隔符是字符串")
        (断言测试 (> (string-length 路径分隔符) 0) "分隔符非空"))))

  (λ ()
    (测试 "获取文件扩展名"
      (λ ()
        (define result (获取文件扩展名 "test.rkt"))
        (断言相等 #"rkt" result))))
)

(测试组 "OS 模块 - 文件操作"
  (λ ()
    (测试 "创建文件 和 文件存在"
      (λ ()
        (define tmp-path (build-path (获取cwd) "_test_temp_file_.tmp"))
        (创建文件 tmp-path)
        (断言测试 (文件存在 tmp-path) "文件应存在")
        (删除文件 tmp-path)
        (断言测试 (not (文件存在 tmp-path)) "删除后文件应不存在"))))

  (λ ()
    (测试 "是文件 / 是目录"
      (λ ()
        (define tmp-path (build-path (获取cwd) "_test_temp_file2_.tmp"))
        (创建文件 tmp-path)
        (断言测试 (是文件 tmp-path) "应是文件")
        (断言测试 (not (是目录 tmp-path)) "不是目录")
        (删除文件 tmp-path))))

  (λ ()
    (测试 "重命名 文件"
      (λ ()
        (define src (build-path (获取cwd) "_test_rename_src_.tmp"))
        (define dst (build-path (获取cwd) "_test_rename_dst_.tmp"))
        (创建文件 src)
        (重命名 src dst)
        (断言测试 (文件存在 dst) "目标文件应存在")
        (断言测试 (not (文件存在 src)) "源文件应不存在")
        (删除文件 dst))))

  (λ ()
    (测试 "复制文件"
      (λ ()
        (define src (build-path (获取cwd) "_test_copy_src_.tmp"))
        (define dst (build-path (获取cwd) "_test_copy_dst_.tmp"))
        (创建文件 src)
        (复制文件 src dst)
        (断言测试 (文件存在 src) "源文件应存在")
        (断言测试 (文件存在 dst) "目标文件应存在")
        (删除文件 src)
        (删除文件 dst))))
)

(测试组 "OS 模块 - 环境变量"
  (λ ()
    (测试 "获取环境变量 PATH 存在"
      (λ ()
        (define result (获取环境变量 "PATH"))
        (断言测试 (and (string? result) (> (string-length result) 0))))))

  (λ ()
    (测试 "获取环境变量 不存在的返回 #f"
      (λ ()
        (define result (获取环境变量 "_MINGDAO_NONEXIST_VAR_12345_"))
        (断言相等 #f result))))

  (λ ()
    (测试 "设置和删除环境变量"
      (λ ()
        (设置环境变量 "_MINGDAO_TEST_VAR_" "test_value")
        (define val (获取环境变量 "_MINGDAO_TEST_VAR_"))
        (断言相等 "test_value" val)
        (删除环境变量 "_MINGDAO_TEST_VAR_")
        (define after (获取环境变量 "_MINGDAO_TEST_VAR_"))
        (断言相等 "" after))))
)

(测试组 "OS 模块 - 系统信息"
  (λ ()
    (测试 "获取pid 返回正整数"
      (λ ()
        (define result (获取pid))
        (断言测试 (and (integer? result) (> result 0)) "PID是正整数"))))

  (λ ()
    (测试 "系统名称 非空"
      (λ ()
        (define result (系统名称))
        (断言测试 (symbol? result) "系统名是符号"))))

  (λ ()
    (测试 "开始目录 是路径"
      (λ ()
        (define result (开始目录))
        (断言测试 (path? result) "家目录是路径"))))

  (λ ()
    (测试 "临时目录 是路径"
      (λ ()
        (define result (临时目录))
        (断言测试 (path? result) "临时目录是路径"))))
)

(运行测试)