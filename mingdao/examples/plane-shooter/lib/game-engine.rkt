#lang racket/base

(require racket/gui
         racket/draw
         racket/random
         racket/class
         (except-in racket/control set)
         "../../../core.rkt")

(provide 创建窗口 关闭窗口
         清除背景
         画矩形 画实心矩形
         画圆形 画实心圆形
         画三角形 画实心三角形
         画文本
         游戏循环 退出游戏
         按键按下
         帧时间
         追加)

;; ============================================================
;; 内部状态
;; ============================================================

(define current-canvas #f)
(define current-frame #f)
(define key-state (make-hash))

(define running? #f)
(define dt-value 0.016)

(define (创建窗口 w h title)
  (when current-frame
    (send current-frame show #f))
  (set! key-state (make-hash))
  (define frame
    (new frame%
      [label title]
      [width w]
      [height h]
      [style '(no-resize-border)]))
  (define canvas
    (new game-canvas%
      [parent frame]
      [min-width w]
      [min-height h]
      [stretchable-width #f]
      [stretchable-height #f]
      [style '(border)]))
  (set! current-canvas canvas)
  (set! current-frame frame)
  (send frame show #t)
  canvas)

(define (关闭窗口)
  (when current-frame
    (send current-frame show #f))
  (set! current-canvas #f)
  (set! current-frame #f)
  (set! key-state (make-hash)))

;; ============================================================
;; 绘图 API — 通过 current-dc 参数获得绘图上下文
;; ============================================================

(define current-dc (make-parameter #f))

(define (get-pen r g b width)
  (new pen% [color (make-object color% r g b)] [width width]))

(define (get-brush r g b)
  (new brush% [color (make-object color% r g b)] [style 'solid]))

(define (清除背景 r g b)
  (define dc (current-dc))
  (when dc
    (define brush (new brush% [color (make-object color% r g b)] [style 'solid]))
    (send dc set-brush brush)
    (send dc set-pen (new pen% [color (make-object color% r g b)] [style 'transparent]))
    (define w (send current-canvas get-width))
    (define h (send current-canvas get-height))
    (send dc draw-rectangle 0 0 w h)))

(define (画矩形 x y w h r g b)
  (define dc (current-dc))
  (when dc
    (send dc set-pen (new pen% [color (make-object color% r g b)] [width 2]))
    (send dc set-brush (new brush% [style 'transparent]))
    (send dc draw-rectangle x y w h)))

(define (画实心矩形 x y w h r g b)
  (define dc (current-dc))
  (when dc
    (send dc set-brush (get-brush r g b))
    (send dc set-pen (new pen% [color (make-object color% r g b)] [style 'transparent]))
    (send dc draw-rectangle x y w h)))

(define (画圆形 cx cy radius r g b)
  (define dc (current-dc))
  (when dc
    (send dc set-pen (new pen% [color (make-object color% r g b)] [width 2]))
    (send dc set-brush (new brush% [style 'transparent]))
    (send dc draw-ellipse (- cx radius) (- cy radius) (* radius 2) (* radius 2))))

(define (画实心圆形 cx cy radius r g b)
  (define dc (current-dc))
  (when dc
    (send dc set-brush (get-brush r g b))
    (send dc set-pen (new pen% [color (make-object color% r g b)] [style 'transparent]))
    (send dc draw-ellipse (- cx radius) (- cy radius) (* radius 2) (* radius 2))))

(define (画三角形 x1 y1 x2 y2 x3 y3 r g b)
  (define dc (current-dc))
  (when dc
    (send dc set-pen (new pen% [color (make-object color% r g b)] [width 2]))
    (send dc set-brush (new brush% [style 'transparent]))
    (send dc draw-path
      (let ([p (new dc-path%)])
        (send p move-to x1 y1)
        (send p line-to x2 y2)
        (send p line-to x3 y3)
        (send p close)
        p))))

(define (画实心三角形 x1 y1 x2 y2 x3 y3 r g b)
  (define dc (current-dc))
  (when dc
    (send dc set-brush (get-brush r g b))
    (send dc set-pen (new pen% [color (make-object color% r g b)] [style 'transparent]))
    (send dc draw-path
      (let ([p (new dc-path%)])
        (send p move-to x1 y1)
        (send p line-to x2 y2)
        (send p line-to x3 y3)
        (send p close)
        p))))

(define (画文本 x y text r g b size)
  (define dc (current-dc))
  (when dc
    (send dc set-font (make-object font% size 'default))
    (send dc set-text-foreground (make-object color% r g b))
    (send dc draw-text text x y)))

;; ============================================================
;; 游戏循环
;; ============================================================

(define paint-callback-fn #f)

(define game-canvas%
  (class canvas%
    (define/override (on-char event)
       (define key-code (send event get-key-code))
       (define release-code (send event get-key-release-code))
       (when key-code
         (hash-set! key-state key-code #t))
       (when release-code
         (hash-set! key-state release-code #f)))
    (define/override (on-paint)
      (when paint-callback-fn
        (define dc (send this get-dc))
        (when dc
          (paint-callback-fn this dc))))
    (super-new)))


(define (游戏循环 update-fn draw-fn fps)
  (set! running? #t)
  (set! dt-value (/ 1.0 fps))
  (when (not current-canvas)
    (error "游戏循环: 请先创建窗口"))
  (set! paint-callback-fn
    (lambda (self dc)
      (when running?
        (parameterize ([current-dc dc])
          (draw-fn '())))))
  (send current-frame show #t)
  ;; 主循环——使用 yield 让出控制权给 GUI 事件系统
  (let loop ()
    (when running?
      (yield)
      (sleep (/ 1.0 fps))
      (update-fn '())
      (send current-canvas refresh)
      (loop)))
  (关闭窗口)
  '游戏结束)

(define (退出游戏)
  (set! running? #f))

;; ============================================================
;; 输入
;; ============================================================

(define (按键按下 key)
  (hash-ref key-state key #f))

;; ============================================================
;; 随机数
;; ============================================================

(define (随机整数 min max)
  (+ min (random (- max min -1))))

(define (帧时间)
  dt-value)

(define (追加 lst elem)
  (列表修改 lst (length lst) elem))