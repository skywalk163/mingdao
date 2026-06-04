#lang racket/base

;; 明道语言解析器
;; 将 Token 序列转换为 AST（S-表达式）

(require "tokenizer.rkt"
         "error.rkt"
         racket/list
         racket/match)

(provide parse
         是类型名?
         类型名列表
         get-type-annotations
         reset-type-annotations!)

;; 内置类型名（用于类型标注）
(define 类型名列表
  '("整数" "浮点数" "字符串" "布尔" "空值" "任意" "列表" "字典"))

(define (是类型名? str)
  (member str 类型名列表))

;; 解析入口
(define (parse tokens [extra-function-names #f])
  (define pos 0)
  (define (get-pos) pos)
  
  ;; 类型别名表：存储类型别名 -> 实际类型的映射
  (define *类型别名表* (make-hash))
  
  ;; 类型展开函数：递归展开类型别名
  (define (展开类型 type-expr)
    (if (symbol? type-expr)
        (let ([展开的 (hash-ref *类型别名表* type-expr #f)])
          (if 展开的
              (展开类型 展开的)
              type-expr))
        (if (pair? type-expr)
            (cons (展开类型 (car type-expr)) 
                  (map 展开类型 (cdr type-expr)))
            type-expr)))
  
  ;; 注册的函数名集合
  (define function-names (make-hash))
  ;; 注册内置函数
  (for ([name '("打印" "长度" "索引" "列表" "列表修改" "消息拼接" "生成" "捕获" "任意" "新建" "定义类" "异步" "等待"
                 "加" "减" "乘" "除" "模" "幂" "非" "不是" "与" "或" "拼接"
                 "创建窗口" "关闭窗口" "清除背景"
                 "画矩形" "画实心矩形" "画圆形" "画实心圆形"
                 "画三角形" "画实心三角形" "画文本"
                 "游戏循环" "退出游戏"
                 "按键按下" "随机整数" "帧时间" "追加"
                 "绝对值" "最大值" "最小值" "整数开方"
                 "映射" "过滤" "范围"
                 "断言" "跟踪" "检查" "检查列表" "断点"
                 "调试输出" "记录" "调用堆栈"
                 "测试" "测试组" "断言测试" "断言相等"
                 "断言不等" "断言异常" "运行测试"
                 "字符" "字符码" "字符串索引" "子字符串"
                 "字符串长度" "字符串转列表" "列表转字符串"
                 "是中文" "是数字" "是字母" "是空白" "是换行"
                 "字符串前缀" "字符串包含" "反转" "数字转字符串"
                 "报错" "是否相等" "不等于" "任一" "符号判断" "列表判断" "符号转字符串" "数大于" "数小于" "数大于等于" "数小于等于" "前置" "追加多个" "去掉首个" "字符串转数字" "字符串转符号" "列表包含" "取前几个" "去掉前几个"
                 "四舍五入" "开方" "求和" "整除" "向下取整" "向上取整"
                 "十六进" "八进制" "二进制"
                 "布尔值" "转字符串" "获取类型"
                 "是整数" "是浮点数" "是字符串" "是符号" "是字符" "是数" "是空"
                 "排序" "全部" "枚举" "拉链" "去重" "扁平" "输入"
                 "大写" "小写" "替换" "去空格" "拆分" "连接" "查找" "计数" "重复字符串"
                 "转整数" "转浮点数" "表示" "哈希" "标识" "是可调用" "商余" "集合" "切片"
                 "字符串后缀"
                 "ascii表示" "格式化" "元组" "复数" "冻结集合" "读取文件" "写入文件"
                 ;; 标准库函数(math.rkt)
                 "正弦" "余弦" "正切" "反正弦" "反余弦" "反正切"
                 "自然对数" "常用对数" "指数"
                 "角度转弧度" "弧度转角度"
                 "圆周率" "自然常数"
                 "阶乘" "组合数" "排列数"
                 "最大公约数" "最小公倍数"
                 "取符号" "取小数部分" "取整数部分"
                 "度转弧度" "弧度转度"
                 ;; 标准库函数(json.rkt)
                 "json解析" "json生成" "json字符串转列表" "列表转json字符串"
                 ;; 标准库函数(random.rkt)
                 "随机整数范围" "随机浮点数" "随机种子" "随机选择" "随机打乱" "随机样本" "随机布尔"
                 ;; 标准库函数(time.rkt)
                 "当前时间" "当前日期" "当前时间戳" "格式化时间" "休眠" "时间戳转时间" "时间转时间戳"
                 ;; 标准库函数(functools.rkt)
                 "归约" "偏函数" "恒等" "补集" "组合" "列表转函数" "函数管道" "柯里化"
                 ;; 标准库函数(os.rkt)
                 "获取cwd" "设置cwd" "列出目录" "创建目录" "删除目录"
                 "创建文件" "删除文件" "文件存在" "是文件" "是目录"
                 "获取环境变量" "设置环境变量" "删除环境变量"
                 "获取pid" "重命名" "复制文件" "文件大小" "文件修改时间" "移动文件"
                 "路径拼接" "绝对路径" "相对路径" "获取文件扩展名" "替换文件名"
                 "系统名称" "命令行参数" "开始目录" "临时目录" "路径分隔符" "当前目录"
                 ;; 标准库函数(re.rkt)
                 "正则搜索" "正则匹配" "正则替换" "正则全部替换" "正则分割"
                 "正则匹配所有" "正则转义" "正则编译" "正则匹配位置"
                 ;; 标准库函数(itertools.rkt)
                 "计数" "循环" "重复" "累加" "链" "压缩" "丢弃" "保留" "过滤"
                 "分组" "星映射" "切片" "配对" "跨越"
                 "积" "排列" "组合" "组合替换"
                 "无限" "无限计数器" "拉链最长" "拉链填充"
                 ;; 标准库函数(collections.rkt)
                 "计数器/创建" "计数器/最多" "计数器/相加" "计数器/相减"
                 "双端队列/创建" "左追加" "右追加" "左弹出" "右弹出"
                 "扩展" "左扩展" "旋转"
                 "默认字典/创建" "默认字典/获取"
                 "有序字典/创建" "有序字典/获取" "有序字典/设置" "有序字典/转为列表"
                 "命名元组/创建" "命名元组/新建"
                 "链映射/创建" "链映射/获取" "链映射/新增"
                 ;; 标准库函数(statistics.rkt)
                 "平均值" "中位数" "中位数低" "中位数高"
                 "众数" "众数列表" "方差总体" "标准差总体"
                 "方差样本" "标准差样本" "分位数" "协方差" "相关系数" "线性回归"
                 ;; 标准库函数(datetime.rkt)
                 "今天" "日期/创建" "日期/年" "日期/月" "日期/日"
                 "日期/星期" "日期/差" "日期/加"
                 "时间/创建" "时间/时" "时间/分" "时间/秒"
                 "现在" "日期时间/创建" "日期时间/格式化" "解析日期"
                 "时间差/天" "时间差/小时" "时间差/分钟" "时间差/秒"
                 "现在时间戳" "时间戳转日期" "星期几" "天数"
                 ;; 标准库函数(hashlib.rkt)
                 "md5哈希" "sha1哈希" "sha256哈希" "sha512哈希" "文件md5" "文件sha256"
                 ;; 标准库函数(base64.rkt)
                 "base64编码" "base64解码" "base64url编码" "base64url解码"
                 ;; 标准库函数(csv.rkt)
                 "csv读取" "csv解析" "csv写入" "csv生成"
                 ;; 标准库函数(copy.rkt)
                 "浅拷贝" "深拷贝" "复制列表" "复制哈希"
                 ;; 标准库函数(textwrap.rkt)
                 "自动换行" "填充" "缩进" "去缩进" "缩短"
                 ;; 标准库函数(pprint.rkt)
                 "美观打印" "打印格式化" "美观输出"
                 ;; 标准库函数(pathlib.rkt)
                 "路径/创建" "路径/父目录" "路径/名称" "路径/主干" "路径/后缀"
                 "路径/存在" "路径/是文件" "路径/是目录" "路径/绝对" "路径/解析"
                 "路径/家目录" "路径/临时目录"
                 ;; 标准库函数(fractions.rkt)
                 "分数/创建" "分数/分子" "分数/分母" "分数/简化"
                 "分数/加" "分数/减" "分数/乘" "分数/除"
                 "分数/比较" "分数/转浮点数" "分数/转字符串"
                 ;; 标准库函数(decimal.rkt)
                 "十进制/创建" "十进制/加" "十进制/减" "十进制/乘" "十进制/除"
                 "十进制/四舍五入" "十进制/转字符串" "十进制/比较"
                 ;; 标准库函数(string.rkt)
                 "字符串/大写" "字符串/小写" "字符串/首字母大写" "字符串/首字母小写"
                 "字符串/反转" "字符串/居中" "字符串/左对齐" "字符串/右对齐"
                 "字符串/开头判断" "字符串/结尾判断"
                 "字符串/交换大小写" "字符串/下划线转驼峰" "字符串/驼峰转下划线"
                 "字符串/压缩空白" "字符串/按宽度折行" "字符串/切分行"
                 "字符串/删除前缀" "字符串/删除后缀"
                 "字符串/格式" "字符串/模板" "字符串/转义"
                 "字符串/索引所有" "字符串/匹配计数"
                 ;; 标准库函数(struct.rkt)
                 "打包" "解包" "打包大小" "计算打包大小"
                 "打包/整数大端" "打包/整数小端" "打包/整数网络序"
                 "解包/整数大端" "解包/整数小端" "解包/整数网络序"
                 "打包/字符串" "解包/字符串"
                 "打包/浮点" "解包/浮点"
                 "打包/大端" "打包/小端"
                 "解包/大端" "解包/小端"
                 ;; 标准库函数(heapq.rkt)
                 "堆/创建" "堆/推入" "堆/弹出" "堆/查看" "堆/大小" "堆/为空"
                 "堆/推入弹出" "堆/替换" "堆/合并" "堆/排序"
                 "堆/最大/创建" "堆/最大/推入" "堆/最大/弹出"
                 "堆/归并" "堆/最小堆化" "堆/最大堆化"
                 "堆/弹出全部"
                 ;; 标准库函数(bisect.rkt)
                 "二分/左插入点" "二分/右插入点" "二分/插入左" "二分/插入右"
                 "二分/查找左" "二分/查找右" "二分/在范围内"
                 "二分/左" "二分/右"
                 "二分/插入" "二分/查找"
                 ;; 标准库函数(array.rkt)
                 "数组/创建" "数组/长度" "数组/索引" "数组/修改" "数组/转列表" "列表/转数组"
                 "数组/追加" "数组/拼接" "数组/切片" "数组/复制"
                 "数组/填充" "数组/映射" "数组/过滤" "数组/反转"
                 "数组/排序" "数组/迭代" "数组/转字符串"
                 "数组/类型" "数组/字节" "数组/整数" "数组/浮点"
                 "数组/创建/字节" "数组/创建/整数" "数组/创建/浮点"
                 ;; 标准库函数(io.rkt)
                 "io/打开文件" "io/读取全部" "io/读取行" "io/读取字符"
                 "io/写入" "io/写入行" "io/写入字符串"
                 "io/关闭" "io/刷新"
                 "io/字符串输入" "io/字符串输出" "io/获取输出值"
                 "io/字节输入" "io/字节输出" "io/获取字节输出"
                 "io/管道" "io/缓冲输入"
                 "io/文件输入" "io/文件输出" "io/追加输出"
                 "io/临时文件" "io/临时目录"
                 "io/行迭代" "io/读取字节" "io/写入字节"
                 "io/复制" "io/是否输入" "io/是否输出" "io/可读" "io/可写"
                 "io/位置" "io/定位" "io/截断"
                 "io/读取行号" "io/行号"
                 ;; 标准库函数(secrets.rkt)
                 "秘密/令牌字节" "秘密/令牌十六进制" "秘密/令牌URL安全"
                 "秘密/随机整数范围" "秘密/随机选择" "秘密/随机打乱"
                 "秘密/比较哈希" "秘密/令牌二进制"
                 ;; 标准库函数(uuid.rkt)
                 "uuid/生成" "uuid/生成1" "uuid/生成4" "uuid/解析" "uuid/转字符串"
                 "uuid/版本" "uuid/时钟序列" "uuid/节点" "uuid/时间戳"
                 "uuid/命名空间DNS" "uuid/命名空间URL" "uuid/命名空间OID" "uuid/命名空间X500"
                 "uuid/生成3" "uuid/生成5" "uuid/空" "uuid/是否是有效"
                 ;; 标准库函数(glob.rkt)
                 "glob/匹配" "glob/列表" "glob/递归列表" "glob/转义"
                 "glob/匹配单个" "glob/过滤" "glob/根目录"
                 ;; 标准库函数(fnmatch.rkt)
                 "文件名/匹配" "文件名/过滤" "文件名/转义" "文件名/转换正则"
                 ;; 标准库函数(tempfile.rkt)
                 "临时/文件" "临时/目录" "临时/命名文件" "临时/命名目录"
                 "临时/临时名" "临时/mkstemp" "临时/mkdtemp" "临时/生成名"
                 "临时/默认目录" "临时/后缀" "临时/前缀"
                 ;; 标准库函数(shutil.rkt)
                 "文件工具/复制" "文件工具/复制2" "文件工具/复制模式" "文件工具/复制状态"
                 "文件工具/递归复制" "文件工具/递归删除" "文件工具/递归移动"
                 "文件工具/磁盘使用" "文件工具/移动"
                 "文件工具/复制文件" "文件工具/复制目录" "文件工具/删除目录"
                 "文件工具/压缩" "文件工具/解压"
                 "文件工具/获取存档格式" "文件工具/注册存档格式" "文件工具/获取解压目录"
                 ;; 标准库函数(logging.rkt)
                 "日志/调试" "日志/信息" "日志/警告" "日志/错误" "日志/严重"
                 "日志/基本配置" "日志/获取日志器" "日志/设置级别"
                 "日志/添加处理器" "日志/移除处理器"
                 "日志/DEBUG" "日志/INFO" "日志/WARNING" "日志/ERROR" "日志/CRITICAL"
                 "日志/流处理器" "日志/文件处理器" "日志/格式器" "日志/设置格式"
                 ;; 标准库函数(argparse.rkt)
                 "参数/创建解析器" "参数/添加参数" "参数/解析" "参数/解析已知"
                 "参数/添加子解析器" "参数/设置默认" "参数/打印帮助"
                 "参数/打印用法" "参数/格式化帮助" "参数/格式化用法"
                 "参数/输出帮助" "参数/错误" "参数/退出"
                 ;; 标准库函数(numbers.rkt)
                 "数字/是整数" "数字/是浮点" "数字/是有理数" "数字/是实数" "数字/是复数"
                 "数字/是数字" "数字/整数转罗马" "数字/罗马转整数" "数字/进制转换"
                 "数字/数字转中文" "数字/约等于" "数字/限制范围" "数字/标准化角度"
                 "数字/等比缩放" "数字/百分比"
                 ;; 标准库函数(difflib.rkt)
                 "差异/比较" "差异/上下文差异" "统一差异" "html差异"
                 "差异/比例" "差异/匹配块" "差异/最佳匹配"
                 "差异/序列匹配器" "差异/分组" "差异/相近" "差异/相同率"
                 ;; 标准库函数(calendar.rkt)
                 "日历/月" "日历/年" "日历/月天数" "日历/月日历"
                 "日历/星期" "日历/星期几" "日历/闰年"
                 "日历/星期名" "日历/缩写星期名" "日历/月名" "日历/缩写月名"
                 "日历/当月" "日历/当月天数" "日历/月起始星期"
                 "日历/周天数" "日历/月范围" "日历/年范围"
                 ;; 标准库函数(webbrowser.rkt)
                 "浏览器/打开" "浏览器/新标签" "浏览器/新窗口"
                 "浏览器/获取" "浏览器/注册" "浏览器/默认浏览器"
                 "浏览器/打开URL" "浏览器/可用浏览器列表"
                 ;; 标准库函数(gettext.rkt)
                 "国际化/翻译" "国际化/绑定文本域" "国际化/文本域" "国际化/语言" "国际化/语言环境"
                 "国际化/默认域" "国际化/安装" "国际化/翻译字符串" "国际化/复数翻译" "国际化/获取翻译"
                 "国际化/空翻译"
                 ;; 标准库函数(codecs.rkt)
                 "编解码/编码" "编解码/解码" "编解码/查找" "编解码/注册" "编解码/支持编码列表"
                 "编解码/utf8编码" "编解码/utf8解码" "编解码/ascii编码" "编解码/ascii解码"
                 "编解码/latin1编码" "编解码/latin1解码" "编解码/utf16编码" "编解码/utf16解码"
                 "编解码/base64编码" "编解码/base64解码" "编解码/hex编码" "编解码/hex解码"
                 "编解码/rot13编码" "编解码/rot13解码"
                 ;; 标准库函数(subprocess.rkt)
                 "子进程/运行" "子进程/调用" "子进程/检查调用" "子进程/检查输出"
                 "子进程/Popen" "子进程/管道" "子进程/通信" "子进程/等待"
                 "子进程/轮询" "子进程/终止" "子进程/杀死"
                 "子进程/返回码" "子进程/标准输出" "子进程/标准错误"
                 "子进程/已完成进程"
                 ;; 标准库函数(inspect.rkt)
                 "检查/是函数" "检查/是过程" "检查/是列表" "检查/是数字" "检查/是字符串"
                 "检查/是符号" "检查/是哈希" "检查/是向量" "检查/是布尔"
                 "检查/获取源代码" "检查/获取文件" "检查/获取行号" "检查/获取成员"
                 "检查/获取模块" "检查/签名" "检查/参数"
                 "检查/当前帧" "检查/堆栈" "检查/获取注释"
                 ;; 标准库函数(locale.rkt)
                 "本地化/默认" "本地化/设置" "本地化/获取" "本地化/货币" "本地化/语言"
                 "本地化/编码" "本地化/数字格式" "本地化/日期格式" "本地化/时间格式"
                 "本地化/可用列表"
                 ;; 标准库函数(configparser.rkt)
                 "配置/创建" "配置/读取文件" "配置/读取字符串" "配置/获取" "配置/获取整数"
                 "配置/获取浮点" "配置/获取布尔" "配置/设置" "配置/删除"
                 "配置/有节" "配置/有选项" "配置/节列表" "配置/选项列表"
                 "配置/添加节" "配置/移除节" "配置/写入" "配置/节转字典"
                 "配置/默认节"
                 ;; 标准库函数(pickle.rkt)
                 "序列化/转字节" "序列化/转字符串" "序列化/加载字节" "序列化/加载字符串"
                 "序列化/转文件" "序列化/加载文件" "序列化/协议" "序列化/最高协议"
                 "序列化/支持类型列表"
                 ;; 标准库函数(zipfile.rkt)
                 "zip/打开" "zip/读取" "zip/写入" "zip/添加文件" "zip/提取" "zip/提取全部"
                 "zip/列出" "zip/信息" "zip/文件名列表" "zip/测试" "zip/获取信息"
                 "zip/写模式" "zip/读模式" "zip/文件大小" "zip/文件时间" "zip/文件crc"
                 "zip/压缩大小" "zip/注释" "zip/设置密码"
                 ;; 标准库函数(tarfile.rkt)
                 "tar/打开" "tar/读取" "tar/写入" "tar/添加文件" "tar/提取" "tar/提取全部"
                 "tar/列出" "tar/获取成员" "tar/成员列表" "tar/添加目录" "tar/添加字符串"
                 "tar/过滤" "tar/关闭" "tar/读模式" "tar/写模式"
                 "tar/压缩/无压缩" "tar/压缩/gzip" "tar/压缩/bz2"
                 "tar/文件大小" "tar/文件类型" "tar/文件权限"
                 ;; 标准库函数(threading.rkt)
                 "线程/创建" "线程/当前" "线程/等待" "线程/睡眠" "线程/名称" "线程/标识"
                 "线程/活动数" "线程/枚举" "线程/主线程" "线程/设置名称"
                 "线程/锁" "线程/获得锁" "线程/释放锁" "线程/RLock"
                 "线程/事件" "线程/设置事件" "线程/等待事件" "线程/清除事件"
                 "线程/信号量" "线程/定时器" "线程/屏障" "线程/本地数据" "线程/互斥量"
                 ;; 标准库函数(socket.rkt)
                 "套接字/创建" "套接字/连接" "套接字/绑定" "套接字/监听" "套接字/接受"
                 "套接字/发送" "套接字/接收" "套接字/关闭" "套接字/设置超时" "套接字/获取超时"
                 "套接字/获取主机名" "套接字/TCP" "套接字/UDP"
                 "套接字/AF_INET" "套接字/SOCK_STREAM" "套接字/SOCK_DGRAM"
                 "套接字/获取地址信息" "套接字/主机名转IP" "套接字/IP转主机名"
                 "套接字/IP地址" "套接字/端口"
                 ;; 标准库函数(mimetypes.rkt)
                 "mime/猜测类型" "mime/猜测扩展" "mime/初始化" "mime/已知类型"
                 "mime/添加类型" "mime/添加扩展" "mime/后缀" "mime/编码"
                 "mime/猜测文件类型" "mime/读取系统类型" "mime/类型映射"
                 ;; 标准库函数(getpass.rkt)
                 "密码输入/获取" "密码输入/获取用户" "密码输入/获取密码"
                 ;; 标准库函数(platform.rkt)
                 "平台/系统" "平台/版本" "平台/处理器" "平台/节点名" "平台/机器" "平台/架构"
                 "平台/Python实现" "平台/Python版本" "平台/操作系统详情" "平台/平台字符串"
                 "平台/释出版本" "平台/系统别名" "平台/架构位宽"
                 ;; 分词器内部函数
                 "分词循环" "处理换行" "尝试读关键字标识符"
                 "创建Token" "检查边界关键字" "读字符串" "读数字"
                 "读标识符收集" "读标识符自" "计算缩进" "生成退栈"
                 "是强制拆分" "是双字关键字" "是单字关键字"
                 "是单字运算符" "是双字运算符" "分词"
                 ;; 解析器内部函数
                 "取令牌" "令牌类型" "令牌值" "令牌行" "当前类型" "当前值"
                 "匹配类型判断" "匹配类型值判断" "跳过换行"
                 "是函数名判断" "取前" "去掉前" "是函数项判断" "提取函数名"
                 "寻找最右函数" "构建SVO递归" "解包函数引用"
                 "解析表达式" "解析或表达式" "解析与表达式" "解析非表达式"
                 "解析比较表达式" "解析加性表达式" "解析乘性表达式"
                 "解析访问表达式" "解析幂表达式" "解析一元表达式"
                 "解析原子表达式" "解析列表括号形式" "解析列表自由形式"
                 "解析标识符" "解析关键字函数" "解析函数名括号调用"
                 "解析逗号项" "解析逗号表达式" "映射解包函数引用"
                 "解析条件项" "解析条件" "解析语句" "解析表达式语句"
                 "解析函数调用" "解析定义" "解析参数列表"
                 "解析如果" "解析对于" "解析遍历"
                 "解析返回" "解析赋值" "解析满足循环" "解析程序" "解析" "匹配"
                 ;; 异常类型名（用于 尝试/捕获）
                 "任意错误" "类型错误" "参数错误" "变量错误" "文件错误" "读取错误" "语法错误" "用户错误" "网络错误" "除零错误")])
    (hash-set! function-names name #t))
  (when extra-function-names
    (for ([name extra-function-names])
      (hash-set! function-names name #t)))
  
  (define (register-function! name)
    (hash-set! function-names name #t))
  
  (define (function-name? name)
    (hash-ref function-names name #f))
  
  ;; 检查当前token是否为标识符（包括函数名关键字）
  (define (match-identifier?)
    (or (match? 'IDENTIFIER)
        (and (match? 'KEYWORD) (function-name? (token-value (current))))))
  
  ;; 期望标识符（接受IDENTIFIER、函数名KEYWORD、类型名KEYWORD）
  (define (expect-identifier)
    (define tok (current))
    (cond
      [(match? 'IDENTIFIER) (advance)]
      [(and (match? 'KEYWORD) (function-name? (token-value tok)))
       (advance)]
      [(and (match? 'KEYWORD) (是类型名? (token-value tok)))
       (advance)]
      [else
       (error 'parse (期望错误提示 'IDENTIFIER tok))]))
  
  (define (peek [offset 0])
    (if (< (+ pos offset) (length tokens))
        (list-ref tokens (+ pos offset))
        #f))
  
  (define (current)
    (peek 0))
  
  (define (advance)
    (define tok (current))
    (set! pos (add1 pos))
    tok)
  
  ;; 中文错误提示映射
  (define (类型中文 type)
    (case type
      [(KEYWORD) "关键字"]
      [(IDENTIFIER) "名称"]
      [(NUMBER) "数字"]
      [(STRING) "字符串"]
      [(COLON) "冒号"]
      [(COMMA) "逗号"]
      [(INDENT) "缩进"]
      [(DEDENT) "取消缩进"]
      [(PIPE) "管道符"]
      [(NEWLINE) "换行"]
      [(LBRACKET) "左方括号"]
      [(RBRACKET) "右方括号"]
      [(FSTRING) "插值字符串"]
      [else (symbol->string type)]))
  
  (define (期望错误提示 type tok)
    (define 期望描述 (类型中文 type))
    (define 实际描述 
      (if tok
          (format "~a '~a'" (类型中文 (token-type tok)) (token-value tok))
          "文件结束"))
    (format "期望 ~a，但得到 ~a（第 ~a 行）"
            期望描述
            实际描述
            (if tok (token-line tok) 0)))
  
  (define (expect type [value #f])
    (define tok (current))
    (unless tok 
      (error 'parse (format "意外的文件结束，请检查代码是否完整 (正在期望 ~a)" (类型中文 type))))
    (unless (eq? (token-type tok) type)
      (error 'parse (期望错误提示 type tok)))
    (when (and value (not (equal? (token-value tok) value)))
      (error 'parse 
             (format "期望 '~a'，但得到 '~a'（第 ~a 行）~a"
                     value 
                     (token-value tok) 
                     (token-line tok)
                     (if (member value '("就是" "那么" "否则"))
                         "\n提示：请检查语法结构是否完整"
                         ""))))
    (advance))
  
  (define (match? type [value #f])
    (define tok (current))
    (and tok
         (eq? (token-type tok) type)
         (or (not value) (equal? (token-value tok) value))))
  
  ;; 跳到行尾
  (define (skip-to-line-end)
    (define tok (current))
    (when (and tok (not (eq? (token-type tok) 'NEWLINE)) (not (eq? (token-type tok) 'DEDENT)))
      (advance)
      (skip-to-line-end)))
  
  ;; 跳过NEWLINE token
  (define (skip-newlines)
    (when (match? 'NEWLINE)
      (advance)
      (skip-newlines)))
  
  ;; 判断一个token是否为标识符（变量或函数名）
  (define (identifier? tok)
    (and tok
         (or (eq? (token-type tok) 'IDENTIFIER)
             (and (eq? (token-type tok) 'KEYWORD)
                  (function-name? (token-value tok))))))
  
  ;; 将token转换为符号
  (define (token->symbol tok)
    (string->symbol (token-value tok)))
  
  ;; 检查一个项是否为函数引用（符号或列表形式的零参调用）
  (define (function-item? item)
    (cond
      [(and (symbol? item) (function-name? (symbol->string item))) #t]
      [(and (pair? item) (null? (cdr item)) (symbol? (car item))
            (function-name? (symbol->string (car item)))) #t]
      [else #f]))
  
  ;; 从函数引用中提取函数名
  (define (extract-func-name item)
    (cond
      [(symbol? item) item]
      [(and (pair? item) (null? (cdr item)) (symbol? (car item))) (car item)]
      [else item]))
  
  ;; 构建主谓宾语序的函数调用
  ;; items = [e1, e2, ..., en], 从右向左处理
  ;; 只对已注册的函数名做嵌套调用
  ;; 包含函数前后的参数：函数前的为主语/宾语，函数后的为额外参数
  (define (build-svo-call items [wrap-non-func? #t])
    (define n (length items))
    (cond
      [(= n 0) '()]
      [(= n 1)
       (define item (car items))
       (if (function-item? item)
           (list (list (extract-func-name item)))
           (list item))]
      [else
       (define func-pos
         (let loop ([i (sub1 n)])
           (cond
             [(< i 0) #f]
             [(function-item? (list-ref items i)) i]
             [else (loop (sub1 i))])))
       (if func-pos
           (let ([func-name (extract-func-name (list-ref items func-pos))]
                 [arg-items (take items func-pos)]
                 [rest-items (drop items (add1 func-pos))])
             (define args (append (build-svo-call arg-items #f) rest-items))
             (list `(,func-name ,@args)))
           (let ([first (car items)])
             (cond
               [(and (symbol? first) wrap-non-func?)
                (list `(,first ,@(cdr items)))]
               [(and (pair? first) (null? (cdr first)) (symbol? (car first)) wrap-non-func?)
                (list `(,(car first) ,@(cdr items)))]
               [else items])))]))
  
  ;; 解析逗号分隔的表达式列表
  (define (parse-comma-exprs)
    ;; 在逗号分隔语境中，运算符视为普通函数名（用于SVO），而非一元/二元运算符
    (define (parse-comma-item)
      (if (match? 'OPERATOR)
          (string->symbol (token-value (advance)))
          (parse-expression)))
    (define items '())
    (set! items (cons (parse-comma-item) items))
    (let loop ()
      (when (match? 'COMMA)
        (advance)
        (set! items (cons (parse-comma-item) items))
        (loop)))
    (set! items (reverse items))
    
    ;; 解包函数引用：将 (函数名) 形式的列表还原为符号，用于作为参数传递（函数值）
    (define (unwrap-func-ref item)
      (if (and (pair? item) (null? (cdr item)) (symbol? (car item))
               (function-name? (symbol->string (car item))))
          (car item)
          item))
    
    (define first (car items))
    (cond
      ;; 如果第一个项是注册的函数名（符号形式），则作为主调函数
      [(and (symbol? first) (function-name? (symbol->string first)))
       (define processed-args (map unwrap-func-ref (cdr items)))
       (when (eq? first '新建)
         (set! processed-args (map (lambda (arg) (list 'quote arg)) processed-args)))
       `(,first ,@processed-args)]
      ;; 如果第一个项是列表形式的函数引用（如 (游戏循环)），也作为主调函数
      [(and (pair? first) (null? (cdr first)) (symbol? (car first))
            (function-name? (symbol->string (car first))))
       `(,(car first) ,@(map unwrap-func-ref (cdr items)))]
      ;; 否则用SVO模式从右向左查找
      [else
       (let ([result (build-svo-call items)])
         (if (= (length result) 1)
             (car result)
             (error 'parse (format "无法解析逗号分隔的表达式（缺少函数名）: ~a" items))))]))
  
  ;; 解析程序（语句块）
  (define (parse-program)
    (define statements '())
    (let loop ()
      (define tok (current))
      (when tok
        (cond
          [(match? 'DEDENT)
           (void)]
          [(match? 'NEWLINE)
           (advance)
           (loop)]
          [else
           (set! statements (cons (parse-statement) statements))
           (when (match? 'NEWLINE)
             (advance))
           (loop)])))
    (reverse statements))
  
  ;; 解析语句
  (define (parse-statement)
    (skip-newlines)
    (define tok (current))
    (cond
      [(not tok) '()]
      [(and (match? 'KEYWORD "定义")
            (let ([next-tok (peek 1)])
              (and next-tok (eq? (token-type next-tok) 'KEYWORD)
                   (equal? (token-value next-tok) "类型"))))
       (begin
         (advance)
         (advance)
         (define alias-name (string->symbol (token-value (current))))
         (advance)
         (expect 'KEYWORD "就是")
         (define actual-type (parse-type))
         (when (hash-has-key? *类型别名表* alias-name)
           (error 'parse (format "类型别名 '~a' 重复定义（第 ~a 行）" alias-name (token-line (current)))))
         (hash-set! *类型别名表* alias-name actual-type)
         (void))]
      [(match? 'AT)
       (advance)
       (define decorator-name (string->symbol (token-value (expect-identifier))))
       (define target (parse-comma-exprs))
       `(装饰器 ,decorator-name ,target)]
      [(match? 'KEYWORD "外部函数")
       (advance)
       (define func-name (string->symbol (token-value (expect-identifier))))
       (define lib-path
         (cond
           [(match? 'STRING) (token-value (advance))]
           [(match? 'IDENTIFIER) (string->symbol (token-value (advance)))]
           [else (error 'parse "期望库路径（字符串或标识符）")]))
       (define return-type (string->symbol (token-value (expect-identifier))))
       (expect 'LPAREN)
       (define params '())
       (unless (match? 'RPAREN)
         (set! params (cons (string->symbol (token-value (expect-identifier))) params))
         (let loop ()
           (when (match? 'COMMA)
             (advance)
             (set! params (cons (string->symbol (token-value (expect-identifier))) params))
             (loop))))
       (expect 'RPAREN)
       `(外部函数 ,func-name ,lib-path ,return-type (,@(reverse params)))]
      [(match? 'KEYWORD "定义")
       (parse-definition)]
      [(match? 'KEYWORD "常量")
       (parse-constant-definition)]
      [(match? 'KEYWORD "定义宏")
       (parse-macro-definition)]
      [(match? 'KEYWORD "如果")
       (parse-if)]
      [(match? 'KEYWORD "对于")
       (parse-for-loop)]
      [(match? 'KEYWORD "对于每个")
       (parse-for-each)]
      [(match? 'KEYWORD "做当满足")
       (parse-do-while)]
      [(match? 'KEYWORD "返回")
       (parse-return)]
      [(match? 'KEYWORD "产出")
       (advance)
       (define value (parse-comma-exprs))
       `(yield ,value)]
      [(match? 'KEYWORD "跳出")
       (advance)
       '(break)]
      [(match? 'KEYWORD "继续")
       (advance)
       '(continue)]
      [(match? 'KEYWORD "当满足")
       (advance)
       (define condition (parse-expression))
       (when (match? 'KEYWORD "那么") (advance))
       (expect 'COLON)
       (skip-newlines)
       (expect 'INDENT)
       (define body (parse-program))
       (expect 'DEDENT)
       `(let/ec break
          (let loop ()
            (if ,condition
                (begin
                  (let/ec continue
                    ,@body)
                  (loop))
                (void))))]
      [(match? 'KEYWORD "赋值")
       (advance)
       (define var-name (string->symbol (token-value (expect-identifier))))
       ;; 检查是否为常量
       (when (hash-ref constant-vars var-name #f)
         (error 'parse (format "常量 '~a' 不可赋值修改（第 ~a 行）" var-name (token-line (current)))))
       (expect 'KEYWORD "为")
       (define value (parse-comma-exprs))
       `(set! ,var-name ,value)]
      [(match? 'KEYWORD "导入")
       (parse-import)]
      [(match? 'KEYWORD "导出")
       (parse-export)]
      [(match? 'KEYWORD "匹配")
       (parse-match)]
      [(match? 'KEYWORD "尝试")
       (parse-try)]
      [else
       (define expr (parse-comma-exprs))
       (if (or (match? 'PIPE) (match? 'KEYWORD "然后"))
           (let ([pipeline-calls '()])
             (let loop ()
               (when (and (current)
                          (not (match? 'DOT))
                          (not (match? 'DEDENT))
                          (not (match? 'NEWLINE))
                          (not (match? 'COLON)))
                 (when (or (match? 'PIPE) (match? 'KEYWORD "然后"))
                   (advance))
                 (define pipe-call (parse-function-call))
                 (set! pipeline-calls (cons pipe-call pipeline-calls))
                 (loop)))
             (for ([pipe-call (reverse pipeline-calls)])
               (set! expr `(,(car pipe-call) ,expr ,@(cdr pipe-call))))
             expr)
           expr)]))
  
  ;; 解析函数调用（谓宾语序）
  (define (parse-function-call)
    (define func-name 
      (cond
        [(match? 'IDENTIFIER)
         (string->symbol (token-value (advance)))]
        [(and (match? 'KEYWORD)
              (function-name? (token-value (current))))
         (string->symbol (token-value (advance)))]
        [else
         (error 'parse "函数调用必须以函数名开头")]))
    (define args '())
    (let loop ()
      (when (and (current) 
                 (not (match? 'DOT)) 
                 (not (match? 'DEDENT))
                 (not (match? 'NEWLINE))
                 (not (match? 'PIPE))
                 (not (match? 'COLON))
                 (not (match? 'KEYWORD "然后")))
        (define arg (parse-expression))
        (when (eq? func-name '新建)
          (set! arg (list 'quote arg)))
        (set! args (cons arg args))
        (when (match? 'COMMA)
          (advance)
          (loop))))
    (set! args (reverse args))
    `(,func-name ,@args))
  
  ;; 解析类型表达式（泛型、联合）
  (define (parse-type)
    (define base-types '())
    (let parse-base ()
      (define type-name (string->symbol (token-value (expect-identifier))))
      ;; 检查泛型 <...>
      (define type-expr
        (if (match? 'LEFT_ANGLE)
            (let ()
              (advance)  ;; 消费 <
              (define type-params '())
              (let loop ()
                (define param (parse-type))
                (set! type-params (cons param type-params))
                (when (match? 'COMMA)
                  (advance)
                  (loop)))
              (set! type-params (reverse type-params))
              (expect 'RIGHT_ANGLE)  ;; 消费 >
              `(,type-name ,@type-params))
            type-name))
      (set! base-types (cons type-expr base-types))
      ;; 检查联合类型 PIPE | 或（tokenizer 将"或"标记为 OPERATOR）
      (when (or (match? 'PIPE) (match? 'OPERATOR "或"))
        (advance)
        (parse-base)))
    (if (null? (cdr base-types))
        (car base-types)
        `(或 ,@(reverse base-types))))
  
  (define (contains-yield? expr)
    (cond
      [(pair? expr)
       (or (eq? (car expr) 'yield)
           (ormap contains-yield? expr))]
      [else #f]))
  
  ;; 解析定义
  (define (parse-definition)
    (expect 'KEYWORD "定义")
    (define name-token (expect-identifier))
    (define name (string->symbol (token-value name-token)))
    (define name-str (token-value name-token))
    (cond
      [(match? 'KEYWORD "接口")
       (advance)
       (expect 'COLON)
       (skip-newlines)
       (expect 'INDENT)
       (define methods '())
       (let loop ()
         (when (and (current) (match? 'KEYWORD "方法"))
           (advance)
           (define method-name (string->symbol (token-value (expect-identifier))))
           (expect 'LPAREN)
           (expect 'RPAREN)
           (expect 'COLON)
           (skip-newlines)
           (expect 'INDENT)
           (define body (parse-program))
           (expect 'DEDENT)
           (set! methods (cons (list method-name body) methods))
           (loop)))
       (expect 'DEDENT)
       `(define-interface ,name ,(reverse methods))]
      [(match? 'KEYWORD "类")
       (advance)
       (expect 'COLON)
       (skip-newlines)
       (expect 'INDENT)
       (define fields '())
       (define methods '())
       (let loop ()
         (when (and (current)
                    (or (match? 'KEYWORD "属性")
                        (match? 'KEYWORD "方法")))
           (cond
             [(match? 'KEYWORD "属性")
              (advance)
              (define field-name (string->symbol (token-value (expect-identifier))))
              (expect 'COLON)
              (define field-value (parse-comma-exprs))
              (set! fields (cons (list field-name field-value) fields))
              (when (match? 'NEWLINE) (advance))]
             [(match? 'KEYWORD "方法")
              (advance)
              (define method-name (string->symbol (token-value (expect-identifier))))
              (expect 'LPAREN)
              (define params (parse-parameter-list))
              (define param-names (map car params))
              (expect 'RPAREN)
              (expect 'COLON)
              (skip-newlines)
              (expect 'INDENT)
              (define body (parse-program))
              (expect 'DEDENT)
              (set! methods (cons (list method-name param-names body) methods))])
           (loop)))
       (skip-newlines)
       (expect 'DEDENT)
       `(定义类 ',name ',(reverse fields) ',(reverse methods))]
      [else
       ;; 检查类型标注（支持泛型和联合类型）
       (define var-annotated-type
         (if (match? 'COLON)
             (begin
               (advance)              ;; 消费 :
               (parse-type))          ;; 解析复合类型表达式
             #f))
       (cond
         [(match? 'KEYWORD "就是函")
       (advance)
       (register-function! name-str)
       (define params (parse-parameter-list))  ;; 返回 '((a 整数) (b 字符串))
       (define param-names (map car params))   ;; 提取 '(a b) 用于代码生成
       ;; 保存参数类型信息
       (for ([p params])
         (hash-set! type-annotations (car p) (cadr p)))
       (expect 'COLON)
       (skip-newlines)
       ;; 检查是否为返回类型
       (define return-type
         (let ([next-tok (current)])
           (if (and next-tok
                    (or (eq? (token-type next-tok) 'IDENTIFIER)
                        (eq? (token-type next-tok) 'LEFT_ANGLE)
                        (and (eq? (token-type next-tok) 'OPERATOR)
                             (equal? (token-value next-tok) "或")))
                    (or (是类型名? (token-value next-tok))
                        (eq? (token-type next-tok) 'LEFT_ANGLE)
                        (and (eq? (token-type next-tok) 'OPERATOR)
                             (equal? (token-value next-tok) "或"))))
               (begin
                 (let ([return-type-val (parse-type)])
                   (expect 'COLON)
                   return-type-val))
               '任意)))
       ;; 保存函数返回类型信息
       (hash-set! type-annotations name (or return-type '任意))
       (skip-newlines)
       (expect 'INDENT)
       (define body (parse-program))
       (expect 'DEDENT)
       (define gen-body (if (= (length body) 1) body `((begin ,@body))))
       (if (ormap contains-yield? body)
           `(define (,name ,@param-names) (generator () ,@gen-body))
           `(define (,name ,@param-names) (let/ec return ,@gen-body)))]
      [(match? 'KEYWORD "就是宏")
       (advance)
       (register-function! name-str)
       (define params (parse-parameter-list))
       (expect 'COLON)
       (skip-newlines)
       (expect 'INDENT)
       (define body (parse-program))
       (expect 'DEDENT)
       `(define-syntax (,name stx) ,@body)]
      [(match? 'KEYWORD "就是")
       (advance)
       (define value (parse-comma-exprs))
       (define final-value
         (if (or (match? 'PIPE) (match? 'KEYWORD "然后"))
             (let ([pipeline-calls '()])
               (let loop ()
                 (when (and (current)
                            (not (match? 'DOT))
                            (not (match? 'DEDENT))
                            (not (match? 'NEWLINE))
                            (not (match? 'COLON)))
                   (when (or (match? 'PIPE) (match? 'KEYWORD "然后"))
                     (advance))
                   (define pipe-call (parse-function-call))
                   (set! pipeline-calls (cons pipe-call pipeline-calls))
                   (loop)))
               (for ([pipe-call (reverse pipeline-calls)])
                 (set! value `(,(car pipe-call) ,value ,@(cdr pipe-call))))
               value)
             value))
       ;; 保存变量类型信息
       (when var-annotated-type
         (hash-set! type-annotations name var-annotated-type))
       `(define ,name ,final-value)]
      [else
       (error 'parse (format "期望 '就是'，但得到 ~a (位置:~a 行:~a)" (token-value (current)) pos (token-line (current))))])]))
  
  ;; 解析常量定义（不可变绑定）
  (define (parse-constant-definition)
    (expect 'KEYWORD "常量")
    (define name (string->symbol (token-value (expect-identifier))))
    (define name-str (symbol->string name))
    (cond
      [(match? 'KEYWORD "就是")
       (advance)
       (define value (parse-comma-exprs))
       (define final-value
         (if (or (match? 'PIPE) (match? 'KEYWORD "然后"))
             (let ([pipeline-calls '()])
               (let loop ()
                 (when (and (current)
                            (not (match? 'DOT))
                            (not (match? 'DEDENT))
                            (not (match? 'NEWLINE))
                            (not (match? 'COLON)))
                   (when (or (match? 'PIPE) (match? 'KEYWORD "然后"))
                     (advance))
                   (define pipe-call (parse-function-call))
                   (set! pipeline-calls (cons pipe-call pipeline-calls))
                   (loop)))
               (for ([pipe-call (reverse pipeline-calls)])
                 (set! value `(,(car pipe-call) ,value ,@(cdr pipe-call))))
               value)
             value))
       ;; 注册为常量
       (hash-set! constant-vars name #t)
       `(define ,name ,final-value)]
      [else
       (error 'parse (format "常量定义期望 '就是'，但得到 ~a" (token-value (current))))]))
  
  ;; 解析宏定义
  (define (parse-macro-definition)
    (expect 'KEYWORD "定义宏")
    (define name (string->symbol (token-value (expect-identifier))))
    (register-function! (symbol->string name))
    (expect 'KEYWORD "就是宏")
    (expect 'COLON)
    (skip-newlines)
    (expect 'INDENT)
    
    (define clauses '())
    (let loop ()
      (unless (match? 'KEYWORD "生成")
        (error 'parse "宏定义体必须以 生成 开头"))
      (advance)
      (define pattern (parse-macro-list))
      (skip-newlines)
      (unless (match? 'KEYWORD "捕获")
        (error 'parse "生成 后必须跟 捕获"))
      (advance)
      (define template (parse-macro-list))
      (set! clauses (cons (list pattern template) clauses))
      (when (match? 'NEWLINE) (advance))
      (skip-newlines)
      (when (and (current) (match? 'KEYWORD "生成"))
        (loop)))
    
    (expect 'DEDENT)
    (set! clauses (reverse clauses))
    (build-macro-definition name clauses))
  
  ;; 解析宏模式/模板列表（括号包围的原始列表）
  (define (parse-macro-list)
    (expect 'LPAREN)
    (define items '())
    (let loop ()
      (when (and (current) (not (match? 'RPAREN)))
        (set! items (cons (parse-macro-item) items))
        (loop)))
    (expect 'RPAREN)
    (reverse items))
  
  (define (parse-macro-item)
    (cond
      [(match? 'LPAREN) (parse-macro-list)]
      [(match? 'NUMBER) (token-value (advance))]
      [(match? 'STRING) (token-value (advance))]
      [(match? 'IDENTIFIER) (string->symbol (token-value (advance)))]
      [(match? 'KEYWORD) (string->symbol (token-value (advance)))]
    [(match? 'OPERATOR) (string->symbol (token-value (advance)))]
    [else (error 'parse (format "宏模式中无法解析: ~a" (token-type (current))))]))
  
  ;; 转换宏模式/模板中的 任意 为 syntax-case 的 ...
  (define (convert-macro-items items)
    (let loop ([remaining items] [result '()])
      (cond
        [(null? remaining) (reverse result)]
        [(and (pair? remaining) (pair? (cdr remaining))
              (eq? (cadr remaining) '任意))
         (loop (cddr remaining)
               (cons '... (cons (car remaining) result)))]
        [(pair? (car remaining))
         (loop (cdr remaining)
               (cons (convert-macro-items (car remaining)) result))]
        [else
         (loop (cdr remaining)
               (cons (car remaining) result))])))
  
  ;; 将宏模板从 SVO 语序转换为 Racket 前缀语序
  (define (convert-template-svo items)
    (define result (build-svo-call items))
    (cond
      [(null? result) items]
      [(and (list? result) (pair? (car result)) (list? (car result))
            (= (length result) 1))
       (let ([converted (car result)])
         (map (lambda (item)
                (if (list? item)
                    (convert-template-svo item)
                    item))
              converted))]
      [else
       (map (lambda (item)
              (if (list? item)
                  (convert-template-svo item)
                  item))
            result)]))
  
  ;; 构建 define-syntax 宏定义
  (define (build-macro-definition name clauses)
    `(define-syntax ,name
       (syntax-rules ()
         ,@(map (lambda (clause)
                  (define pattern (convert-macro-items (car clause)))
                  (define pattern-with-_
                    (if (null? pattern)
                        pattern
                        (cons '_ (cdr pattern))))
                  (list pattern-with-_ (convert-macro-items (convert-template-svo (cadr clause)))))
                clauses))))
  
  ;; 解析参数列表（支持可选类型标注，包括泛型和联合类型）
  (define (parse-parameter-list)
    (define params '())
    (let loop ()
      (cond
        [(match-identifier?)
         (define pname (string->symbol (token-value (advance))))
         (define ptype
           (if (match? 'COLON)
               (let ([next-tok (peek 1)])
                 ;; 检查冒号后是否为合法的类型起始标记
                 (if (and next-tok
                  (or (and (eq? (token-type next-tok) 'IDENTIFIER)
                           (是类型名? (token-value next-tok)))
                      (eq? (token-type next-tok) 'LEFT_ANGLE)
                      (and (eq? (token-type next-tok) 'KEYWORD)
                           (是类型名? (token-value next-tok)))
                      (and (eq? (token-type next-tok) 'OPERATOR)
                           (equal? (token-value next-tok) "或"))))
                     (begin
                       (advance)  ;; 消费冒号
                       (parse-type))  ;; 解析完整类型表达式
                     '任意))
               '任意))
         (set! params (cons (list pname ptype) params))
         (when (match? 'COMMA)
           (advance)
           (loop))]
        [else (void)]))
    (reverse params))
  
  ;; 解析条件中的单个表达式项（不消耗比较运算符）
  ;; 支持 与/或/非 逻辑运算符和算术运算符，但不含 大于/小于/等于 等比较运算符
  (define (parse-svo-item)
    (cond
      [(match? 'OPERATOR "非")
       (advance)
       `(not ,(parse-additive-expression))]
      [else
       (define left (parse-additive-expression))
       (let loop ()
         (cond
           [(match? 'OPERATOR "与")
            (advance)
            (define right (parse-additive-expression))
            (set! left `(and ,left ,right))
            (loop)]
           [(match? 'OPERATOR "或")
            (advance)
            (define right (parse-additive-expression))
            (set! left `(or ,left ,right))
            (loop)]
           [else left]))]))
  
  ;; 解析条件表达式（支持逗号分隔的 SVO 表达式和比较运算符）
  (define (parse-condition)
    (define items '())
    (set! items (cons (parse-svo-item) items))
    (let loop ()
      (when (match? 'COMMA)
        (define next-tok (peek 1))
        (if (and next-tok
                 (eq? (token-type next-tok) 'KEYWORD)
                 (member (token-value next-tok)
                         '("大于" "小于" "等于" "不等" "大于等于" "小于等于" "那么")))
            (void)
            (begin
              (advance)
              (set! items (cons (parse-svo-item) items))
              (loop)))))
    (set! items (reverse items))
    (define result
      (cond
        [(and (= (length items) 1) (symbol? (car items)))
         (car items)]
        [else
         (let ([svo (build-svo-call items)])
           (if (= (length svo) 1) (car svo) svo))]))
    (cond
      [(match? 'KEYWORD "大于") (advance) `(> ,result ,(parse-condition))]
      [(match? 'KEYWORD "小于") (advance) `(< ,result ,(parse-condition))]
      [(match? 'KEYWORD "等于") (advance) `(equal? ,result ,(parse-condition))]
      [(match? 'KEYWORD "不等") (advance) `(not (equal? ,result ,(parse-condition)))]
      [(match? 'KEYWORD "大于等于") (advance) `(>= ,result ,(parse-condition))]
      [(match? 'KEYWORD "小于等于") (advance) `(<= ,result ,(parse-condition))]
      [(match? 'OPERATOR "?") 
       (advance)
       (define true-expr (parse-ternary-branch))
       (expect 'COLON)
       (define false-expr (parse-ternary-branch))
       `(if ,result ,true-expr ,false-expr)]
      [else result]))
  
  ;; 解析 if 语句
  ;; skip-if-keyword? 用于否则若分支，跳过"如果"关键字的检查
  (define (parse-if [skip-if-keyword? #f])
    (unless skip-if-keyword?
      (expect 'KEYWORD "如果"))
    (define condition (parse-condition))
    (expect 'KEYWORD "那么")
    (expect 'COLON)
    (skip-newlines)
    
    ;; 支持两种模式：缩进块 和 单行语句
    (define then-branch
      (if (match? 'INDENT)
          (begin
            (advance)
            (let ([body (parse-program)])
              (expect 'DEDENT)
              body))
          (let ([stmt (list (parse-statement))])
            (skip-newlines)
            stmt)))
    (skip-newlines)
    (define else-branch
      (cond
        [(match? 'KEYWORD "否则若")
         (advance)
         (list (parse-if #t))]
        [(match? 'KEYWORD "否则")
         (advance)
         (expect 'COLON)
         (skip-newlines)
         (if (match? 'INDENT)
             (begin
               (advance)
               (let ([else-body (parse-program)])
                 (expect 'DEDENT)
                 else-body))
             ;; 单行模式
             (list (parse-statement)))]
        [else '()]))
    `(if ,condition (let () ,@then-branch) ,(if (null? else-branch) '(void) `(let () ,@else-branch))))
  
  ;; 解析 for 循环
  (define (parse-for-loop)
    (expect 'KEYWORD "对于")
    (define var (string->symbol (token-value (expect-identifier))))
    (expect 'KEYWORD "从")
    (define start (parse-expression))
    (expect 'KEYWORD "到")
    (define end (parse-comma-exprs))
    (expect 'COLON)
    (skip-newlines)
    
    ;; 支持单行和缩进块两种模式
    (define body
      (if (match? 'INDENT)
          (begin
            (advance)
            (let ([b (parse-program)])
              (expect 'DEDENT)
              b))
          ;; 单行模式
          (list (parse-statement))))
    
    `(let/ec break
       (for ([,var (in-range ,start ,end)])
         (let/ec continue
           ,@body))))
  
  ;; 解析 for-each 循环
  (define (parse-for-each)
    (expect 'KEYWORD "对于每个")
    (define var (string->symbol (token-value (expect-identifier))))
    (expect 'KEYWORD "从")
    (define list-expr (parse-expression))
    (expect 'COLON)
    (skip-newlines)
    
    ;; 支持单行和缩进块两种模式
    (define body
      (if (match? 'INDENT)
          (begin
            (advance)
            (let ([b (parse-program)])
              (expect 'DEDENT)
              b))
          ;; 单行模式
          (list (parse-statement))))
    
    `(let/ec break
       (for ([,var ,list-expr])
         (let/ec continue
           ,@body))))

  ;; 解析 do-while 循环（做当满足）
  (define (parse-do-while)
    (expect 'KEYWORD "做当满足")
    (define condition (parse-expression))
    (expect 'COLON)
    (skip-newlines)
    
    ;; 支持单行和缩进块两种模式
    (define body
      (if (match? 'INDENT)
          (begin
            (advance)
            (let ([b (parse-program)])
              (expect 'DEDENT)
              b))
          ;; 单行模式
          (list (parse-statement))))
    
    `(let/ec break
       (let loop ()
         ,@body
         (when ,condition
           (loop)))))

  ;; 解析列表推导式 [对于 x 从 [1,2,3]: 表达式]
  (define (parse-list-comprehension-full)
    (expect 'KEYWORD "对于")
    (define var (string->symbol (token-value (expect-identifier))))
    (expect 'KEYWORD "从")
    
    (define list-expr 
      (if (match? 'LBRACKET)
          (let ()
            (advance)
            (define elements '())
            (unless (match? 'RBRACKET)
              (set! elements (cons (parse-expression) elements))
              (let loop ()
                (when (match? 'COMMA)
                  (advance)
                  (when (and (current) (not (match? 'RBRACKET)))
                    (set! elements (cons (parse-expression) elements))
                    (loop)))))
            (expect 'RBRACKET)
            `(list ,@(reverse elements)))
          (parse-expression)))
    
    (expect 'COLON)
    (define expr (parse-comma-exprs))
    
    (expect 'RBRACKET)
    
    `(for/list ([,var ,list-expr]) ,expr))

  ;; 解析三元表达式的分支（简单表达式，不包含冒号或问号）
  (define (parse-ternary-branch)
    (cond
      [(match? 'NUMBER)
       (token-value (advance))]
      [(match? 'STRING)
       (token-value (advance))]
      [(match? 'KEYWORD "真值")
       (advance)
       '#t]
      [(match? 'KEYWORD "假值")
       (advance)
       '#f]
      [(match? 'IDENTIFIER)
       (string->symbol (token-value (advance)))]
      [else
       (error 'parse (format "无法解析三元表达式分支: ~a" (if (current) (token-value (current)) "文件结束")))]))

  ;; 解析匹配语句
  (define (parse-match)
    (expect 'KEYWORD "匹配")
    (define value (parse-expression))
    (expect 'COLON)
    (skip-newlines)
    (expect 'INDENT)
    (define clauses '())
    (define has-else? #f)
    
    ;; 将体包装为 Racket 表达式（单语句不包装，多语句用 begin）
    (define (wrap-body body)
      (cond
        [(null? body) '(void)]
        [(null? (cdr body)) (car body)]
        [else `(begin ,@body)]))
    
    (let loop ()
      (skip-newlines)
      (unless (match? 'DEDENT)
        (when (match? 'INDENT)
          (advance))
        (cond
          [(match? 'KEYWORD "否则")
           (advance)
           (expect 'COLON)
           (skip-newlines)
           (define else-body
             (if (match? 'INDENT)
                 (begin
                   (advance)
                   (let ([body (parse-program)])
                     (expect 'DEDENT)
                     body))
                 (list (parse-statement))))
           (set! clauses (append clauses (list (list 'else (wrap-body else-body)))))
           (set! has-else? #t)]
          [else
           (define parsed-pattern (parse-pattern))
           (define guard (if (match? 'KEYWORD "如果")
                             (begin
                               (advance)
                               (parse-expression))
                             #f))
           (expect 'KEYWORD "那么")
           (expect 'COLON)
           (skip-newlines)
           (define body
             (if (match? 'INDENT)
                 (begin
                   (advance)
                   (let ([b (parse-program)])
                     (expect 'DEDENT)
                     b))
                 (list (parse-statement))))
           (define clause
             (if guard
                 ;; 守卫分支: (pattern #:when guard body)
                 (list parsed-pattern '#:when guard (wrap-body body))
                 ;; 简单分支: (pattern body)
                 (list parsed-pattern (wrap-body body))))
           (set! clauses (append clauses (list clause)))
           (loop)])))
    (skip-newlines)
    (expect 'DEDENT)
    (unless has-else?
      (error 'parse "匹配必须包含 '否则' 分支"))
    `(匹配 ,value ,@clauses))
  
  ;; 解析尝试/捕获/始终（try-catch-finally）
  (define (parse-try)
    (expect 'KEYWORD "尝试")
    (expect 'COLON)
    (skip-newlines)
    (expect 'INDENT)
    (define body (parse-program))
    (expect 'DEDENT)
    (skip-newlines)
    
    ;; 解析捕获分支
    (define catch-clauses '())
    (let loop ()
      (skip-newlines)
      (when (match? 'KEYWORD "捕获")
        (advance)
        (define type-name (string->symbol (token-value (expect-identifier))))
        (expect 'KEYWORD "为")
        (define var-name (string->symbol (token-value (expect-identifier))))
        (expect 'COLON)
        (skip-newlines)
        (define handler
          (if (match? 'INDENT)
              (begin
                (advance)
                (let ([h (parse-program)])
                  (expect 'DEDENT)
                  h))
              (list (parse-statement))))
        (set! catch-clauses (append catch-clauses
                                    (list (list '捕获 type-name var-name handler))))
        (loop)))
    
    (skip-newlines)
    
    ;; 解析始终分支（可选）
    (define finally-clause
      (if (match? 'KEYWORD "始终")
          (begin
            (advance)
            (expect 'COLON)
            (skip-newlines)
            (if (match? 'INDENT)
                (begin
                  (advance)
                  (let ([f (parse-program)])
                    (expect 'DEDENT)
                    f))
                (list (parse-statement))))
          #f))
    
    ;; 构建 AST
    (define wrapped-body `(begin ,@body))
    (define wrapped-clauses
      (map (λ (c)
             (match c
               [(list '捕获 type var handler)
                `(捕获 ,type ,var (begin ,@handler))]))
           catch-clauses))
    
    (if finally-clause
        `(尝试 ,wrapped-body ,@wrapped-clauses (始终 (begin ,@finally-clause)))
        `(尝试 ,wrapped-body ,@wrapped-clauses)))
  
  ;; 解析模式
  (define (parse-pattern)
    (cond
      [(match? 'KEYWORD "任意")
       (advance)
       '_]
      [(and (match? 'IDENTIFIER) (equal? (token-value (current)) "_"))
       (advance)
       '_]
      [(match? 'IDENTIFIER)
       (define val (token-value (current)))
       (advance)
       (string->symbol val)]
      [(match? 'NUMBER)
       (define val (token-value (current)))
       (advance)
       val]
      [(match? 'STRING)
       (define val (token-value (current)))
       (advance)
       val]
      [(and (match? 'KEYWORD) (equal? (token-value (current)) "真值"))
       (advance)
       '#t]
      [(and (match? 'KEYWORD) (equal? (token-value (current)) "假值"))
       (advance)
       '#f]
      [(match? 'LBRACKET)
       (advance)
       (if (match? 'RBRACKET)
           (begin
             (advance)
               '(list))
           (let* ([patterns (parse-pattern-list)]
                  [_ (expect 'RBRACKET)])
             `(list ,@patterns)))]
      [else
       (error 'parse (format "无法识别的模式: ~a (第~a行)" 
                             (if (current) (token-value (current)) "文件结束")
                             (if (current) (token-line (current)) 0)))]))
  
  ;; 解析逗号分隔的模式列表（用于列表解构 [a, b, c]）
  (define (parse-pattern-list)
    (define patterns '())
    (set! patterns (cons (parse-pattern) patterns))
    (let loop ()
      (when (match? 'COMMA)
        (advance)
        (set! patterns (cons (parse-pattern) patterns))
        (loop)))
    (reverse patterns))
  
  ;; 解析返回语句（使用 let/ec 的 return 实现提前返回）
  (define (parse-return)
    (expect 'KEYWORD "返回")
    (if (or (not (current))
            (match? 'DEDENT)
            (match? 'DOT)
            (match? 'RPAREN)
            (match? 'NEWLINE))
        '(return (void))
        `(return ,(parse-comma-exprs))))
  
  ;; 解析导入语句
  (define (parse-import)
    (expect 'KEYWORD "导入")
    (define path-str (token-value (expect 'STRING)))
    `(导入 ,path-str))
  
  ;; 解析导出语句
  (define (parse-export)
    (expect 'KEYWORD "导出")
    (define names '())
    (let loop ()
      (when (and (current) (match? 'IDENTIFIER))
        (set! names (cons (string->symbol (token-value (advance))) names))
        (loop)))
    `(mingdao-export ,@names))
  
  ;; 解析表达式（运算符优先级）
  (define (parse-expression)
    (parse-or-expression))
  
  (define (parse-or-expression)
    (define left (parse-and-expression))
    (let loop ()
      (cond
        [(match? 'OPERATOR "或")
         (advance)
         (define right (parse-and-expression))
         (set! left `(or ,left ,right))
         (loop)]
        [else left])))
  
  (define (parse-and-expression)
    (define left (parse-not-expression))
    (let loop ()
      (cond
        [(match? 'OPERATOR "与")
         (advance)
         (define right (parse-not-expression))
         (set! left `(and ,left ,right))
         (loop)]
        [else left])))
  
  (define (parse-not-expression)
    (cond
      [(match? 'OPERATOR "非")
       (advance)
       `(not ,(parse-comparison-expression))]
      [else (parse-comparison-expression)]))
  
  (define (parse-comparison-expression)
    (define left (parse-additive-expression))
    (let loop ()
      (cond
        [(match? 'KEYWORD "等于")
         (advance)
         (define right (parse-additive-expression))
         (set! left `(equal? ,left ,right))
         (loop)]
        [(match? 'KEYWORD "不等")
         (advance)
         (define right (parse-additive-expression))
         (set! left `(not (equal? ,left ,right)))
         (loop)]
        [(match? 'KEYWORD "大于")
         (advance)
         (define right (parse-additive-expression))
         (set! left `(> ,left ,right))
         (loop)]
        [(match? 'KEYWORD "小于")
         (advance)
         (define right (parse-additive-expression))
         (set! left `(< ,left ,right))
         (loop)]
        [(match? 'KEYWORD "大于等于")
         (advance)
         (define right (parse-additive-expression))
         (set! left `(>= ,left ,right))
         (loop)]
        [(match? 'KEYWORD "小于等于")
         (advance)
         (define right (parse-additive-expression))
         (set! left `(<= ,left ,right))
         (loop)]
        [(match? 'OPERATOR "?")
         (advance)
         (define true-expr (parse-ternary-branch))
         (expect 'COLON)
         (define false-expr (parse-ternary-branch))
         (set! left `(if ,left ,true-expr ,false-expr))
         (loop)]
        [else left])))
  
  (define (parse-additive-expression)
    (define left (parse-multiplicative-expression))
    (let loop ()
      (cond
        [(match? 'OPERATOR "加")
         (advance)
         (define right (parse-multiplicative-expression))
         (set! left `(+ ,left ,right))
         (loop)]
        [(match? 'OPERATOR "减")
         (advance)
         (define right (parse-multiplicative-expression))
         (set! left `(- ,left ,right))
         (loop)]
        [(match? 'OPERATOR "拼接")
         (advance)
         (define right (parse-multiplicative-expression))
         (set! left `(string-append ,left ,right))
         (loop)]
        [else left])))
  
  (define (parse-multiplicative-expression)
    (define left (parse-access-expression))
    (let loop ()
      (cond
        [(match? 'OPERATOR "乘")
         (advance)
         (define right (parse-access-expression))
         (set! left `(* ,left ,right))
         (loop)]
        [(match? 'OPERATOR "除")
         (advance)
         (define right (parse-access-expression))
         (set! left `(/ ,left ,right))
         (loop)]
        [(match? 'OPERATOR "模")
         (advance)
         (define right (parse-access-expression))
         (set! left `(模 ,left ,right))
         (loop)]
        [else left])))
  
  (define (parse-access-expression)
    (define left (parse-power-expression))
    (let loop ()
      (cond
        [(match? 'KEYWORD "索引")
         (advance)
         (define right (parse-access-expression))
         (set! left `(索引 ,left ,right))
         (loop)]
        [else left])))
  
  (define (parse-power-expression)
    (define base (parse-unary-expression))
    (cond
      [(match? 'OPERATOR "幂")
       (advance)
       (define exp (parse-power-expression))
       `(expt ,base ,exp)]
      [else base]))
  
  (define (parse-unary-expression)
    (cond
      [(match? 'OPERATOR "减")
       (advance)
       `(- ,(parse-atomic-expression))]
      [else (parse-atomic-expression)]))
  
  (define (parse-atomic-expression)
    (define tok (current))
    (cond
      [(not tok) (error 'parse (format "意外的文件结束 (parse-atomic-expression)"))]
      [(match? 'NEWLINE)
       (advance)
       (parse-atomic-expression)]
      [(match? 'FSTRING)
       (define segs (token-value (advance)))
       ;; segs 格式始终为：字面、表达式、字面、...、字面
       ;; 偶数索引(0,2,4,...)是字面字符串
       ;; 奇数索引(1,3,5,...)是表达式代码
       (define parts
         (let loop ([i 0] [remaining segs])
           (if (null? remaining)
               '()
               (if (even? i)
                   ;; 字面字符串片段
                   (cons (car remaining) (loop (add1 i) (cdr remaining)))
                   ;; 表达式片段（需要解析为 AST）
                   (let ([expr-str (car remaining)])
                     (define expr-tokens (tokenize expr-str))
                     (define expr-asts (parse expr-tokens))
                     (define expr (if (null? expr-asts) '(void) (car expr-asts)))
                     (cons `(format "~a" ,expr) (loop (add1 i) (cdr remaining))))))))
       (if (null? parts)
           ""  ;; 空 f-string
           (if (null? (cdr parts))
               (car parts)  ;; 只有一个字面片段
               `(string-append ,@parts)))]
      [(match? 'NUMBER)
       (token-value (advance))]
      [(match? 'STRING)
       (token-value (advance))]
      [(match? 'QUOTE)
       (advance)
       (define next-tok (current))
       (cond
         [(match? 'IDENTIFIER)
          `(quote ,(string->symbol (token-value (advance))))]
         [(match? 'STRING)
          `(quote ,(token-value (advance)))]
         [else
          (error 'parse (format "quote 后需要标识符或字符串，但得到: ~a" 
                                (if next-tok (token-value next-tok) "文件结束")))])]
      [(match? 'LBRACKET)
       (advance)
       (if (match? 'KEYWORD "对于")
           (parse-list-comprehension-full)
           (let ()
             (define elements '())
             (unless (match? 'RBRACKET)
               (set! elements (cons (parse-expression) elements))
               (let loop ()
                 (when (match? 'COMMA)
                   (advance)
                   (when (and (current) (not (match? 'RBRACKET)))
                     (set! elements (cons (parse-expression) elements))
                     (loop)))))
             (expect 'RBRACKET)
             `(list ,@(reverse elements))))]
      [(match? 'KEYWORD "真值")
       (advance)
       '#t]
      [(match? 'KEYWORD "假值")
       (advance)
       '#f]
      [(match? 'KEYWORD "空值")
       (advance)
       ''()]
      [(match? 'KEYWORD "异步")
       (advance)
       (expect 'COLON)
       (skip-newlines)
       (expect 'INDENT)
       (define body (parse-program))
       (expect 'DEDENT)
       (if (= (length body) 1)
           `(异步 ,(car body))
           `(异步 (begin ,@body)))]
      [(match? 'KEYWORD "等待")
       (advance)
       `(等待 ,(parse-expression))]
      [(match? 'KEYWORD "列表")
       (advance)
       (define elements '())
       (if (match? 'LPAREN)
           ;; 列表(参数1,参数2) → 函数调用
           (let ([args '()])
             (advance)
             (unless (match? 'RPAREN)
               (set! args (cons (parse-expression) args))
               (let loop ()
                 (when (match? 'COMMA)
                   (advance)
                   (set! args (cons (parse-expression) args))
                   (loop))))
             (expect 'RPAREN)
             `(list ,@(reverse args)))
           (if (and (match? 'NEWLINE) (peek 1) (eq? (token-type (peek 1)) 'INDENT))
           (begin
             (advance)
             (advance)
             (let multi-line-loop ()
               (cond
                 [(match? 'DEDENT)
                  (advance)
                  (void)]
                 [(match? 'NEWLINE)
                  (advance)
                  (multi-line-loop)]
                 [(match? 'COMMA)
                  (advance)
                  (multi-line-loop)]
                 [else
                  (set! elements (cons (parse-expression) elements))
                  (when (match? 'COMMA) (advance))
                  (multi-line-loop)]))
             `(list ,@(reverse elements)))
           (let loop ()
             (cond
                [(or (not (current))
                     (match? 'DOT)
                     (match? 'DEDENT)
                     (match? 'NEWLINE)
                     (match? 'PIPE)
                     (match? 'RPAREN)
                     (match? 'COLON)
                     (match? 'KEYWORD "然后")
                     (match? 'KEYWORD "那么"))
                 (void)]
                [(match? 'COMMA)
                 (advance)
                 (when (and (current)
                            (not (match? 'DOT))
                            (not (match? 'DEDENT))
                            (not (match? 'NEWLINE))
                            (not (match? 'PIPE))
                            (not (match? 'RPAREN))
                            (not (match? 'COLON))
                            (not (match? 'KEYWORD "然后"))
                            (not (match? 'KEYWORD "那么")))
                   (set! elements (cons (parse-expression) elements))
                   (loop))]
                [else
                 (set! elements (cons (parse-expression) elements))
                 (when (match? 'COMMA)
                   (advance)
                   (when (and (current)
                              (not (match? 'DOT))
                              (not (match? 'DEDENT))
                              (not (match? 'NEWLINE))
                              (not (match? 'PIPE))
                              (not (match? 'RPAREN))
                              (not (match? 'COLON))
                              (not (match? 'KEYWORD "然后"))
                              (not (match? 'KEYWORD "那么")))
                     (loop)))])
             `(list ,@(reverse elements)))))]
      [(match? 'KEYWORD "结构")
       (advance)
       (define name (string->symbol (token-value (expect-identifier))))
       (expect 'LPAREN)
       (define fields '())
       (unless (match? 'RPAREN)
         (set! fields (cons (string->symbol (token-value (expect-identifier))) fields))
         (let loop ()
           (when (match? 'COMMA)
             (advance)
             (set! fields (cons (string->symbol (token-value (expect-identifier))) fields))
             (loop))))
       (expect 'RPAREN)
       `(结构 ,name (,@(reverse fields)))]
      [(match? 'KEYWORD "字典")
       (advance)
       (define pairs '())
       (let loop ()
         (cond
           [(or (not (current))
                (match? 'DOT)
                (match? 'DEDENT)
                (match? 'NEWLINE)
                (match? 'COLON))
            (void)]
           [else
            (define key (parse-expression))
            (expect 'COLON)
            (define value (parse-expression))
            (set! pairs (cons (list key value) pairs))
            (when (match? 'COMMA)
              (advance))
            (loop)]))
       `(make-hash (list ,@(map (lambda (p) `(cons ,(car p) ,(cadr p))) (reverse pairs))))]
      ;; 匿名函数短语法：匿名函数 参数列表: 体
      [(match? 'KEYWORD "匿名函数")
       (advance)
       (define params (parse-parameter-list))
       (expect 'COLON)
       (if (match? 'KEYWORD "开始")
           ;; 多语句块：开始 ... 结束
           (let ([block (begin
                          (advance)
                          (skip-newlines)
                          (expect 'INDENT)
                          (let ([body (parse-program)])
                            (expect 'DEDENT)
                            (expect 'KEYWORD "结束")
                            body))])
             (if (= (length block) 1)
                 `(λ ,(map car params) (let/ec return ,(car block)))
                 `(λ ,(map car params) (let/ec return (begin ,@block)))))
           ;; 单表达式模式：自动返回
           (let ([expr (parse-expression)])
             `(λ ,(map car params) ,expr)))]
      [(match? 'IDENTIFIER)
       (define name-str (token-value (advance)))
       (if (function-name? name-str)
           (if (match? 'LPAREN)
               ;; 函数名后跟括号：函数名(参数1,参数2)
               (let ([func-name (string->symbol name-str)]
                     [args '()])
                 (advance)
                 (unless (match? 'RPAREN)
                   (set! args (cons (parse-expression) args))
                   (let loop ()
                     (when (match? 'COMMA)
                       (advance)
                       (set! args (cons (parse-expression) args))
                       (loop))))
                 (expect 'RPAREN)
                 `(,func-name ,@(reverse args)))
               ;; 无参数函数引用
               (list (string->symbol name-str)))
           (string->symbol name-str))]
      [(match? 'OPERATOR)
       (string->symbol (token-value (advance)))]
      ;; 支持作为表达式的关键字（函数名）
      [(and (match? 'KEYWORD)
            (function-name? (token-value tok)))
       (define func-name (string->symbol (token-value (advance))))
       ;; 检查是否有参数（不是运算符或结束符）
       (if (and (current)
                (not (match? 'DOT))
                (not (match? 'DEDENT))
                (not (match? 'NEWLINE))
                (not (match? 'PIPE))
                (not (match? 'COLON))
                (not (match? 'COMMA))
                (not (match? 'KEYWORD "然后"))
                (not (match? 'KEYWORD "那么"))
                (not (match? 'OPERATOR))
                (not (match? 'KEYWORD "等于"))
                (not (match? 'KEYWORD "不等"))
                (not (match? 'KEYWORD "大于"))
                (not (match? 'KEYWORD "小于"))
                (not (match? 'KEYWORD "大于等于"))
                (not (match? 'KEYWORD "小于等于")))
           ;; 有参数，解析参数列表
           (if (match? 'LPAREN)
               ;; 函数名(参数1,参数2,...) 语法
               (let ([args '()])
                 (advance)
                 (unless (match? 'RPAREN)
                   (set! args (cons (parse-expression) args))
                   (let loop ()
                     (when (match? 'COMMA)
                       (advance)
                       (set! args (cons (parse-expression) args))
                       (loop))))
                 (expect 'RPAREN)
                 `(,func-name ,@(reverse args)))
               ;; 函数名 参数1 参数2 ... 空格分隔语法
               (let ([args (list (parse-expression))])
                 (let loop ()
                   (when (match? 'COMMA)
                     (advance)
                     (set! args (cons (parse-expression) args))
                     (loop)))
                 `(,func-name ,@(reverse args))))
           ;; 无参数，返回函数名
           func-name)]
      [(match? 'LPAREN)
       (advance)
       (define expr (parse-comma-exprs))
       (expect 'RPAREN)
       expr]
      [else
       (error 'parse (format "无法解析表达式: ~a (行:~a 列:~a)" 
                              (token-type tok)
                              (token-line tok)
                              (token-col tok)))]))
  
  ;; 开始解析
  (parse-program))

;; ============================================================
;; 类型注解存储（供类型检查器使用）
;; ============================================================
(define type-annotations (make-hasheq))
(define constant-vars (make-hasheq))  ;; 常量变量表（不可变绑定）

(define (get-type-annotations) type-annotations)
(define (reset-type-annotations!)
  (set! type-annotations (make-hasheq)))