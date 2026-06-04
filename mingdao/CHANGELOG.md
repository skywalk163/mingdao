# 更新日志

## [1.2] - 2026-06-04

### 新增
- Socket 模块增强：新增 UDP 支持、字节/行读写、地址查询、保持连接等功能
- Threading 模块增强：新增线程池、并行映射、原子操作、线程本地存储等功能
- JSON 模块函数别名：新增更自然的中文函数名（解析json/生成json等）
- runtime.rkt 独立模块：将导入系统相关代码从 main.rkt 分离

### 改进
- main.rkt 结构优化：分离运行时代码，提升模块可维护性
- 导出 lang/reader.rkt 和 lang/error.rkt，方便外部调用
- error.rkt 函数名优化：避免与 core.rkt 异常谓词冲突
- 完善 std 模块 API 文档，新增 Socket 和 Threading 增强功能文档

### 示例
- 新增 socket-demo.mingdao：网络编程示例
- 更新 threading-demo.mingdao：新增线程池、并行操作、线程本地存储示例
- 新增 json-enhanced-demo.mingdao：展示新的 JSON 函数别名

### 文档
- 更新 std-api.md：新增 Socket 和 Threading 模块增强功能文档
- 所有文档保持中文化和用户友好性

## [1.1] - 2026-06-03

### 新增
- 语言级异常处理：新增 `尝试`/`捕获` 语法，支持结构化错误处理
- 统一函数名管理：将 ~400 个内置函数名提取到独立模块 `function-names.rkt`
- 新增多个 std 模块：`threading`（线程同步）、`socket`（TCP 网络通信）、`configparser`（INI 配置解析）

### 改进
- 错误消息全面增强：所有解析错误现在包含行号、当前上下文和修复建议
- `error.rkt` 增加上下文显示和类型建议
- parser.rkt 精简：移除 300+ 行硬编码函数名列表

### 测试
- 新增 9 个 std 模块测试文件，覆盖全部核心 std 模块
- 测试总数达 191 个，全部通过
- 新增 test-validation.rkt 集成测试

### 文档
- 生成 std 模块中文 API 文档
- 新增 std-demo.rkt 综合示例
- 更新 CI 配置文件

## [1.0] - 初始版本

### 功能
- 明道语言核心（分词器、解析器、读取器）
- 基础语言特性（定义、函数、条件、循环、宏）
- 50+ 个 std 模块（数学、文件、JSON、CSV、正则等）
- DrRacket 语法高亮支持
- 飞机射击游戏示例