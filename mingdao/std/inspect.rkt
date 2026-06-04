#lang racket/base
(require racket/list
         racket/function
         racket/string
         racket/hash)

(provide 检查/是函数 检查/是过程 检查/是列表 检查/是数字 检查/是字符串
         检查/是符号 检查/是哈希 检查/是向量 检查/是布尔
         检查/获取源代码 检查/获取文件 检查/获取行号 检查/获取成员
         检查/获取模块 检查/签名 检查/参数
         检查/当前帧 检查/堆栈 检查/获取注释)

(define (检查/是函数 x)
  (procedure? x))

(define (检查/是过程 x)
  (procedure? x))

(define (检查/是列表 x)
  (list? x))

(define (检查/是数字 x)
  (number? x))

(define (检查/是字符串 x)
  (string? x))

(define (检查/是符号 x)
  (symbol? x))

(define (检查/是哈希 x)
  (hash? x))

(define (检查/是向量 x)
  (vector? x))

(define (检查/是布尔 x)
  (boolean? x))

(define (检查/获取源代码 obj)
  (error "inspect: 获取源代码需要racket/source支持"))

(define (检查/获取文件 obj)
  (error "inspect: 获取文件需要代码对象的位置信息"))

(define (检查/获取行号 obj)
  (error "inspect: 获取行号需要代码对象的位置信息"))

(define (检查/获取成员 obj [predicate #f])
  (define names (if (hash? obj) (hash-keys obj) '()))
  (if predicate
      (filter predicate names)
      names))

(define (检查/获取模块 obj)
  (if (procedure? obj)
      (object-name obj)
      #f))

(define (检查/签名 obj)
  (if (procedure? obj)
      (procedure-arity obj)
      #f))

(define (检查/参数 obj)
  (if (procedure? obj)
      (call-with-values (lambda () (procedure-arity obj)) list)
      '()))

(define (检查/当前帧)
  (error "inspect: 当前帧需要racket/trace支持"))

(define (检查/堆栈)
  (error "inspect: 堆栈需要racket/trace支持"))

(define (检查/获取注释 obj)
  (error "inspect: 获取注释需要racket/trace支持"))