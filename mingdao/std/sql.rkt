#lang racket/base
(require db)

(provide sql/connect sql/disconnect sql/query sql/query-one sql/execute
         sql/transaction sql/get-last-insert-id sql/with-connection)

(struct sql/connection (conn) #:transparent)

(define (sql/connect [db-path #f])
  (with-handlers ([exn:fail? (λ (e) (error "数据库连接失败: ~a" (exn-message e)))])
    (define conn 
      (if db-path
          (sqlite3-connect #:database db-path)
          (sqlite3-connect #:database 'memory)))
    (sql/connection conn)))

(define (sql/disconnect db)
  (with-handlers ([exn:fail? (λ (e) (error "数据库断开失败: ~a" (exn-message e)))])
    (disconnect (sql/connection-conn db))))

(define (sql/query db sql . args)
  (with-handlers ([exn:fail? (λ (e) (error "SQL查询失败: ~a" (exn-message e)))])
    (apply query-rows (sql/connection-conn db) sql args)))

(define (sql/query-one db sql . args)
  (with-handlers ([exn:fail? (λ (e) (error "SQL查询失败: ~a" (exn-message e)))])
    (apply query-row (sql/connection-conn db) sql args)))

(define (sql/execute db sql . args)
  (with-handlers ([exn:fail? (λ (e) (error "SQL执行失败: ~a" (exn-message e)))])
    (apply query-exec (sql/connection-conn db) sql args)))

(define (sql/transaction db thunk)
  (with-handlers ([exn:fail? (λ (e) (rollback-transaction (sql/connection-conn db)) (raise e))])
    (start-transaction (sql/connection-conn db))
    (define result (thunk))
    (commit-transaction (sql/connection-conn db))
    result))

(define (sql/get-last-insert-id db)
  (with-handlers ([exn:fail? (λ (e) (error "获取最后插入ID失败: ~a" (exn-message e)))])
    (query-value (sql/connection-conn db) "SELECT last_insert_rowid()")))

(define (sql/with-connection db-path thunk)
  (define db (sql/connect db-path))
  (with-handlers ([exn:fail? (λ (e) (sql/disconnect db) (raise e))])
    (define result (thunk db))
    (sql/disconnect db)
    result))