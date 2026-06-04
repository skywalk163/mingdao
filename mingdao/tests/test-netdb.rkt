#lang racket
(require "../std/sql.rkt")

(printf "===== 测试SQL模块 =====\n")

(define db (sql/connect))

(sql/execute db "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)")
(sql/execute db "INSERT INTO users (name) VALUES ('张三')")
(define result (sql/query-one db "SELECT name FROM users WHERE id = 1"))
(sql/disconnect db)

(printf "结果: ~s\n" result)

(if (equal? result (vector "张三"))
    (printf "✓ 通过\n")
    (begin
      (printf "✗ 失败\n")
      (exit 1)))

(printf "\n所有 SQL 测试通过！\n")