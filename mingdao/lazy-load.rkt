#lang racket/base

;; 标准库按需加载模块
;; 实现延迟加载机制，提升启动性能

(require racket/list
         racket/format)

(provide 加载模块 加载所有标准库 列出可用模块 模块已加载?)

;; 已加载模块的缓存
(define *已加载模块* (make-hash))

;; 标准库模块清单
(define *标准库模块*
  '(("math" . "std/math.rkt")
    ("json" . "std/json.rkt")
    ("random" . "std/random.rkt")
    ("time" . "std/time.rkt")
    ("functools" . "std/functools.rkt")
    ("os" . "std/os.rkt")
    ("re" . "std/re.rkt")
    ("itertools" . "std/itertools.rkt")
    ("collections" . "std/collections.rkt")
    ("statistics" . "std/statistics.rkt")
    ("datetime" . "std/datetime.rkt")
    ("hashlib" . "std/hashlib.rkt")
    ("base64" . "std/base64.rkt")
    ("csv" . "std/csv.rkt")
    ("copy" . "std/copy.rkt")
    ("textwrap" . "std/textwrap.rkt")
    ("pprint" . "std/pprint.rkt")
    ("pathlib" . "std/pathlib.rkt")
    ("fractions" . "std/fractions.rkt")
    ("decimal" . "std/decimal.rkt")
    ("string" . "std/string.rkt")
    ("struct" . "std/struct.rkt")
    ("heapq" . "std/heapq.rkt")
    ("bisect" . "std/bisect.rkt")
    ("array" . "std/array.rkt")
    ("io" . "std/io.rkt")
    ("secrets" . "std/secrets.rkt")
    ("uuid" . "std/uuid.rkt")
    ("glob" . "std/glob.rkt")
    ("fnmatch" . "std/fnmatch.rkt")
    ("tempfile" . "std/tempfile.rkt")
    ("shutil" . "std/shutil.rkt")
    ("logging" . "std/logging.rkt")
    ("argparse" . "std/argparse.rkt")
    ("numbers" . "std/numbers.rkt")
    ("difflib" . "std/difflib.rkt")
    ("calendar" . "std/calendar.rkt")
    ("webbrowser" . "std/webbrowser.rkt")
    ("gettext" . "std/gettext.rkt")
    ("codecs" . "std/codecs.rkt")
    ("subprocess" . "std/subprocess.rkt")
    ("inspect" . "std/inspect.rkt")
    ("locale" . "std/locale.rkt")
    ("configparser" . "std/configparser.rkt")
    ("pickle" . "std/pickle.rkt")
    ("zipfile" . "std/zipfile.rkt")
    ("tarfile" . "std/tarfile.rkt")
    ("threading" . "std/threading.rkt")
    ("socket" . "std/socket.rkt")
    ("mimetypes" . "std/mimetypes.rkt")
    ("getpass" . "std/getpass.rkt")
    ("platform" . "std/platform.rkt")
    ("http" . "std/http.rkt")
    ("sql" . "std/sql.rkt")))

(define (获取模块路径 模块名)
  (define entry (assoc 模块名 *标准库模块*))
  (if entry
      (cdr entry)
      #f))

(define (模块已加载? 模块名)
  (hash-has-key? *已加载模块* 模块名))

(define (加载模块 模块名)
  (cond
    [(模块已加载? 模块名)
     (hash-ref *已加载模块* 模块名)]
    [else
     (define 路径 (获取模块路径 模块名))
     (if 路径
         (let ()
           (define 开始时间 (current-inexact-milliseconds))
           (dynamic-require 路径 #f)
           (define 耗时 (- (current-inexact-milliseconds) 开始时间))
           (hash-set! *已加载模块* 模块名 耗时)
           (printf "[按需加载] 模块 '~a' 加载完成，耗时 ~a ms\n" 模块名 (round 耗时))
           耗时)
         (error '加载模块 (format "未找到模块: ~a" 模块名)))]))

(define (加载所有标准库)
  (define 总耗时 0)
  (for ([模块 *标准库模块*])
    (define 模块名 (car 模块))
    (set! 总耗时 (+ 总耗时 (加载模块 模块名))))
  (printf "[按需加载] 所有标准库加载完成，总耗时 ~a ms\n" (round 总耗时))
  总耗时)

(define (列出可用模块)
  (map car *标准库模块*))