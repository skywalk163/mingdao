#lang racket/base

(require "lang/error.rkt"
         "lang/error-messages.rkt"
         racket/string
         racket/format)

(displayln "========== M5 验证测试 ==========")

(define src1 "定义 x 就是 \"hello\"\n定义 y：整数 就是 x\n打印, y")

(displayln "\n【测试1】Rust 风格彩色错误输出（类型错误）")
(define err1 (raise-type-error "整数" "hello" 2 12))
(displayln (format-rust-style err1 #:source src1))

(displayln "\n【测试2】JSON 结构化输出")
(displayln (error->json err1 #:source src1))

(displayln "\n【测试3】错误链 API")
(define child1 (raise-type-error "整数" "字符串" 2 15))
(define parent1 (add-child-error (raise-runtime-error "程序执行失败" 2 12) child1))
(displayln (format-rust-style parent1 #:source src1))

(displayln "\n【测试4】--explain E0002")
(displayln (explain-error-code "E0002"))

(displayln "\n【测试5】--explain E0001")
(displayln (explain-error-code "E0001"))

(displayln "\n【测试6】--explain 未知代码")
(displayln (explain-error-code "E9999"))

(displayln "\n【测试7】所有错误代码")
(displayln (all-error-codes))

(displayln "\n【测试8】向后兼容 - 旧格式输出")
(displayln (format-error-message err1 src1))

(displayln "\n========== M5 验证完成 ==========")
