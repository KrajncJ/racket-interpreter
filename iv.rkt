#lang racket

; import for unittesting
(require rackunit)

; data types
(struct const (n) #:transparent)
(struct bool (b) #:transparent)
(struct interval (a b) #:transparent)
(struct pair (e1 e2) #:transparent)
(struct nil () #:transparent)

; data type checks
(struct is-const? (e) #:transparent)
(struct is-bool? (e) #:transparent)
(struct is-interval? (e) #:transparent)
(struct is-nil? (e) #:transparent)
(struct is-pair? (e) #:transparent)

; if statement
(struct if-then-else (b e1 e2) #:transparent)

; operations
(struct negate (e) #:transparent)
(struct add (e1 e2) #:transparent)
(struct multiply (e1 e2) #:transparent)
(struct exponentiate (e) #:transparent)
(struct left (e) #:transparent)
(struct right (e) #:transparent)
(struct greater (e1 e2) #:transparent)
(struct intersect (e1 e2) #:transparent)

; variables implementation structures
(struct with (vars e) #:transparent)
(struct valof (s) #:transparent)

; functions implementation structures
(struct function (name farg body) #:transparent)
(struct closure (env f) #:transparent) ; not included in syntax
(struct script (name body) #:transparent)
(struct call (e arg) #:transparent)



(define (iv expr [defaultEnv (make-immutable-hash)] )
  (letrec ([eval (lambda (e env)
                  (cond [(function? e) (closure env e)];
                        [(script? e) e] ;
                        [(call? e) (let ([result (eval (call-e e) env)])
                                       (cond [(closure? result)
                                                 (if (not (= (length (call-arg e)) (length (function-farg (closure-f result)))))
                                                     (error (string-append (string-append "Error: expected arguments: " (number->string (length (function-farg (closure-f result)))))
                                                                           (string-append " given: " (number->string (length (call-arg e))))))

                                                     (eval (function-body (closure-f result)); execute function body code in enviroment with added function argumnets
                                                           
                                                       (hash-set (for/fold ([ht (closure-env result)]) ; iterate through all new keys and put them into enviroment
                                                                 ([k (in-list (function-farg (closure-f result)))] ; keys - function argument (names)
                                                                  [v (in-list (call-arg e))]) ; values - call arguments
                                                         ; set key and evaluated value into function enviroment, add also function closure
                                                         (hash-set ht k (eval v env))) (function-name (closure-f result)) result)
                                                       ))]
                                             
                                             [(script? result)
                                              (eval (script-body result) env)
                                              ]
                                             [ #t (error "Function call does not contain correct arguments")]))]
                        [(nil? e) e]
                        [(const? e) e]
                        [(bool? e) e]
                        [(interval? e) e]
                        [(pair? e) (letrec ([first (eval (pair-e1 e) env)]
                                            [second (eval(pair-e2 e) env)])
                                         (pair first second))]
                        [(is-const?? e) (bool (const? (eval (is-const?-e e) env )))]
                        [(is-bool?? e) (bool (bool? (eval (is-bool?-e e) env)))]
                        [(is-interval?? e) (bool (interval? (eval (is-interval?-e e) env)))]
                        [(is-nil?? e) (bool (nil? (eval (is-nil?-e e) env)))]
                        [(is-pair?? e) (bool (pair? (eval (is-pair?-e e) env)))]
                        [(if-then-else? e) (letrec ([evBool (eval (if-then-else-b e) env)])
                                             (if (bool-b evBool) (eval (if-then-else-e1 e) env) (eval (if-then-else-e2 e) env)))]
                        [(negate? e) (letrec ([evaluated (eval (negate-e e) env)])
                                       (cond [(bool? evaluated) (bool (not (bool-b evaluated)))]
                                             [(const? evaluated) (const (* (const-n evaluated) -1))]
                                             [(interval? evaluated) (interval (* (interval-b evaluated) -1) (* (interval-a evaluated) -1))]
                                             [ #t (error "Unsupported negation operand")]))]

                        [(add? e) (letrec ([first (eval (add-e1 e) env)]
                                           [second (eval (add-e2 e) env)])
                                       (cond [(and (const? first) (const? second)) (const (+ (const-n first) (const-n second)))]
                                             [(and (interval? first) (interval? second)) (interval (+ (interval-a first) (interval-a second)) (+ (interval-b first) (interval-b second)))]
                                             [(and (interval? first) (const? second)) (interval (+ (interval-a first) (const-n second)) (+ (interval-b first) (const-n second)))]
                                             [(and (const? first) (interval? second)) (interval (+ (interval-a second) (const-n first)) (+ (interval-b second) (const-n first)))]
                                             [ #t (error "Unsupported add operands")]))]
                        
                        [ (multiply? e) (letrec ([first (eval (multiply-e1 e) env)]
                                                 [second (eval (multiply-e2 e) env)])
                                          (cond [(and (const? first) (const? second)) (const (* (const-n first) (const-n second)))]
                                                [(and (interval? first) (interval? second))
                                                   (letrec ([ac (* (interval-a first) (interval-a second))]
                                                           [ad (* (interval-a first) (interval-b second))]
                                                           [bc (* (interval-b first) (interval-a second))]
                                                           [bd (* (interval-b first) (interval-b second))])
                                                     (interval (min ac ad bc bd) (max ac ad bc bd)))]
                                                [ #t (error "Unsupported multiply operands")]))]

                        [ (exponentiate? e) (letrec ([first (eval (exponentiate-e e) env)])
                                          (cond [(const? first) (const (exp (const-n first)))]
                                                [(interval? first) (interval (exp (interval-a first)) (exp (interval-b first)))]
                                                [ #t (error "Unsupported exponentiate operand")]
                                                ))]
                        [ (left? e) (letrec ([first (eval (left-e e) env)])
                                          (cond [(pair? first) (pair-e1 first)]
                                                [(interval? first) (const (interval-a first))]
                                                [ #t (error "Unsupported left operand")]
                                                ))]
                        [ (right? e) (letrec ([first (eval (right-e e) env)])
                                          (cond [(pair? first) (pair-e2 first)]
                                                [(interval? first) (const (interval-b first))]
                                                [ #t (error "Unsupported right operand")]
                                                ))]
                        [ (greater? e) (letrec ([first (eval (greater-e1 e) env)]
                                                [second (eval (greater-e2 e) env)])
                                          (cond [(and (const? first) (const? second)) (bool (> (const-n first) (const-n second)))]
                                                [(and (interval? first) (interval? second))
                                                  (bool (> (abs (- (interval-b first) (interval-a first))) (abs (- (interval-b second) (interval-a second)))))]
                                                [ #t (error "Unsupported greater operands")]
                                                ))]
                        [ (intersect? e) (letrec ([first (eval (intersect-e1 e) env)]
                                                 [second (eval (intersect-e2 e) env)])
                                          (cond [(and (interval? first) (interval? second))
                                                  (cond [(or (> (interval-a second) (interval-b first)) (> (interval-a first) (interval-b second))) (nil)]
                                                        [ #t (letrec ([start (max (interval-a first) (interval-a second))]
                                                                      [end (min (interval-b first) (interval-b second))])
                                                               (interval start end))])]
                                                [ #t (error "Unsupported intersect operands")]
                                                ))]
                        [ (with? e) (eval (with-e e)
                                          (for/fold ([ht env]) ; iterate through all new keys (variables) and put them into enviroment
                                                    ([k (in-list (hash-keys (with-vars e)))]
                                                     [v (in-list (hash-values (with-vars e)))])
                                            (hash-set ht k (eval v env))))]
                        [ (valof? e) (hash-ref env (valof-s e) (nil))]
                        
                        [#t (error "Unknown type")]
                        ))])
                       
                        
                       
    (eval expr defaultEnv)))


; hygenic macro system

(define-syntax subtract
  (syntax-rules ()
    [(subtract e1 e2) (add e1 (multiply e2 (const -1))) ]))

  
(define-syntax lower
  (syntax-rules ()
    [(lower e1 e2) (greater e2 e1)]))

(define-syntax equal
  (syntax-rules ()
    [(equal e1 e2) (let ([x1 e1]
                         [x2 e2])
                   (if-then-else (greater x1 x2) (bool #f) (if-then-else (greater x2 x1) (bool #f) (bool #t))))]))
  
(define-syntax encloses
  (syntax-rules ()
    [(encloses i1 i2) (letrec ([x1 i1]
                               [x2 i2]
                               [a (left x1)]
                               [b (right x1)]
                               [c (left x2)]
                               [d (right x2)]
                               )
                       (and-and (or-or (equal c a) (greater c a)) (or-or (equal d b) (lower d b))))]))
                             



; some custom useful macros

(define-syntax or-or
  (syntax-rules ()
    [(or-or e1 e2) (letrec ([first e1]
                            [second e2])
                    (if-then-else e1 e1 e2))]))
                           
(define-syntax and-and
  (syntax-rules ()
    [(and-and e1 e2) (letrec ([first e1]
                            [second e2])
                    (if-then-else e1 e2 (bool #f)))]))
 




;
; *************************
; ********* tests *********
; *************************
;

; variables for testing
(define h (make-immutable-hash
   (list (cons "a" (const 1))
         (cons "b" (const 2)))))

(define h1 (make-immutable-hash
   (list (cons "c" (const 3))
         (cons "a" (const 4)))))

; if-then-else
(check-equal? (iv (if-then-else (bool #t) (const 1) (const 0))) (const 1))
(check-equal? (iv (if-then-else (bool #f) (const 1) (const 0))) (const 0))
(check-equal? (iv (if-then-else (bool #t) (add (const 1) (add (const 2) (const 3))) (add (const 2) (add (const 1) (const 1))))) (const 6))
(check-equal? (iv (if-then-else (bool #f) (add (const 1) (add (const 2) (const 3))) (add (const 2) (add (const 1) (const 1))))) (const 4))

; type checking
(check-equal? (iv (is-const? (const 3))) (bool #t))
(check-equal? (iv (is-const? (const -1))) (bool #t))
(check-equal? (iv (is-const? (bool #f))) (bool #f))
(check-equal? (iv (is-const? (interval 3 3))) (bool #f))
(check-equal? (iv (is-const? (nil))) (bool #f))

(check-equal? (iv (is-interval? (const 3))) (bool #f))
(check-equal? (iv (is-interval? (interval -1 -3))) (bool #t))
(check-equal? (iv (is-interval? (bool 3))) (bool #f))
(check-equal? (iv (is-interval? (interval 3 3))) (bool #t))
(check-equal? (iv (is-interval? (nil))) (bool #f))

(check-equal? (iv (is-bool? (const 3))) (bool #f))
(check-equal? (iv (is-bool? (bool #f))) (bool #t))
(check-equal? (iv (is-bool? (bool #t))) (bool #t))
(check-equal? (iv (is-bool? (interval 3 3))) (bool #f))
(check-equal? (iv (is-bool? (nil))) (bool #f))

(check-equal? (iv (is-nil? (const 3))) (bool #f))
(check-equal? (iv (is-nil? (const -1))) (bool #f))
(check-equal? (iv (is-nil? (bool 3))) (bool #f))
(check-equal? (iv (is-nil? (interval 3 3))) (bool #f))
(check-equal? (iv (is-nil? (nil))) (bool #t))

(check-equal? (iv (is-pair? (pair (bool #t) (bool #f)))) (bool #t))
(check-equal? (iv (is-pair? (bool #f))) (bool #f))
(check-equal? (iv (is-pair? (const 3))) (bool #f))
(check-equal? (iv (is-pair? (pair (greater (const 3) (const 2)) (add (const 2) (const 3))))) (bool #t))
(check-equal? (iv (is-pair? (interval 1 1))) (bool #f))

; type checking of nested expressions
(check-equal? (iv (is-const? (add (const -1) (const 1)))) (bool #t))
(check-equal? (iv (is-interval? (add (interval 3 3) (interval 1 1)))) (bool #t))
(check-equal? (iv (is-bool? (greater (const 3) (const 2)))) (bool #t))
(check-equal? (iv (is-nil? (intersect (interval 1 3) (interval 4 5)))) (bool #t))

; add
(check-equal? (iv (add (const 1) (add (const 2) (add (const 3) (const 4))))) (const 10))
(check-equal? (iv (add (add (add (const 3) (const 2)) (const 1)) (add (const 1) (const 10)))) (const 17))

; multiply
(check-equal? (iv (multiply (multiply (const 2) (const 2)) (const 2))) (const 8))
(check-equal? (iv (multiply (multiply (const 2) (const 2)) (const -2))) (const -8))
(check-equal? (iv (multiply (const 3) (multiply (const 2) (const 6)))) (const 36))
(check-equal? (iv (multiply (interval -2 4) (interval 1 3))) (interval -6 12))
(check-equal? (iv (multiply (interval 2 4) (interval 3 5))) (interval 6 20))

; exponentiate
(check-equal? (iv (exponentiate (const 2))) (const 7.38905609893065))
(check-equal? (iv (exponentiate (multiply (const 1) (const 2)))) (const 7.38905609893065))
(check-equal? (iv (exponentiate (interval 2 2))) (interval 7.38905609893065 7.38905609893065))

; left/right
(check-equal? (iv (left (pair (add (const 1) (const 2)) (multiply (const 2) (const 2))))) (const 3))
(check-equal? (iv (right (pair (add (const 1) (const 2)) (multiply (const 2) (const 2))))) (const 4))
(check-equal? (iv (left (add (interval 1 1) (interval 3 4)))) (const 4))
(check-equal? (iv (right (add (interval 1 1) (interval 3 4)))) (const 5))

; greater
(check-equal? (iv (greater (multiply (const 10) (const 2)) (add (const 10) (const 9)))) (bool #t))
(check-equal? (iv (greater (multiply (const 10) (const -2)) (add (const 10) (const 9)))) (bool #f))
(check-equal? (iv (greater (interval 1 10) (interval 1 9))) (bool #t))
(check-equal? (iv (greater (interval -10 0) (interval 1 9))) (bool #t))
(check-equal? (iv (greater (interval 1 1) (interval 2 3))) (bool #f))
(check-equal? (iv (greater (interval 2 4) (interval 1 4))) (bool #f))

; intersect
(check-equal? (iv (intersect (interval 5 10) (interval -5 5))) (interval 5 5))
(check-equal? (iv (intersect (interval -5 10) (interval -5 5))) (interval -5 5))
(check-equal? (iv (intersect (interval -3 3) (interval -10 10))) (interval -3 3))
(check-equal? (iv (intersect (interval 0 10) (interval 5 20))) (interval 5 10))
(check-equal? (iv (intersect (interval 0 10) (interval -2 4))) (interval 0 4))
(check-equal? (iv (intersect (interval 1 1) (interval 1 1))) (interval 1 1))

; negate

(check-equal? (iv (negate (bool #f))) (bool #t))
(check-equal? (iv (negate (greater (const 4) (const 3)))) (bool #f))


; local enviroment and variables
(check-equal? (iv (with h (add (valof "a") (const 0)))) (const 1))
(check-equal? (iv (with h1 (add (valof "a") (const 0)))) (const 4))
(check-equal? (iv (with h (with h1 (add (valof "a") (const 5))))) (const 9))
(check-equal? (iv (with h (add (valof "a") (valof "b")))) (const 3))
(check-equal? (iv (with h (with h1 (add (multiply (valof "a") (valof "b")) (valof "c"))))) (const 11))

; functions / scripts
(check-equal? (iv (call (function "add" (list "x" "y") (add (valof "x") (valof "y"))) (list (const 3) (const 4)))) (const 7))
(check-equal? (iv (call (function "add2" (list "x" "y") (multiply (valof "x") (valof "y"))) (list (const 2) (const -5)))) (const -10))
(check-equal? (iv (with h (with h1 (call (script "addScript" (add (valof "a") (valof "b"))) (nil))))) (const 6))
(check-equal? (iv (with h (call (script "addScript2" (add (valof "a") (valof "b"))) (nil)))) (const 3))

; recursive functions
(check-equal?  (iv (call (function "power" (list "x" "y") (if-then-else (greater (valof "y") (const 0)) (multiply (valof "x") (call (valof "power") (list (valof "x") (add (const -1) (valof "y"))))) (const 1))) (list (const 2) (const 3)))) (const 8))
(check-equal?  (iv (call (function "power" (list "x" "y") (if-then-else (greater (valof "y") (const 0)) (multiply (valof "x") (call (valof "power") (list (valof "x") (add (const -1) (valof "y"))))) (const 1))) (list (const 2) (const 10)))) (const 1024))

; macro system - subtract
(check-equal? (iv (subtract (const 3) (const 3))) (const 0))
(check-equal? (iv (subtract (const -3) (const -3))) (const 0))
(check-equal? (iv (subtract (const 2) (const -10))) (const 12))
(check-equal? (iv (subtract (const -13) (const 3))) (const -16))
(check-equal? (iv (subtract (const 0) (const 1))) (const -1))

; macro system - lower
(check-equal? (iv (lower (const 3) (const 4))) (bool #t))
(check-equal? (iv (lower (const 4) (const 3))) (bool #f))
(check-equal? (iv (lower (const 3) (const 3))) (bool #f))
(check-equal? (iv (lower (const -1) (const -1))) (bool #f))
(check-equal? (iv (lower (const -2) (const 0))) (bool #t))
(check-equal? (iv (lower (const -3) (const -3))) (bool #f))
(check-equal? (iv (lower (const -4) (const -5))) (bool #f))

; macro system - equals
(check-equal? (iv (equal (const 3) (const 3))) (bool #t))
(check-equal? (iv (equal (const 4) (const 3))) (bool #f))
(check-equal? (iv (equal (const 3) (const 4))) (bool #f))
(check-equal? (iv (equal (const -3) (const 4))) (bool #f))
(check-equal? (iv (equal (const 0) (const 0))) (bool #t))
(check-equal? (iv (equal (const 1) (const 2))) (bool #f))

; macro system - encloses
(check-equal? (iv (encloses (interval 1 10) (interval 5 8))) (bool #t))
(check-equal? (iv (encloses (interval 1 10) (interval 1 10))) (bool #t))
(check-equal? (iv (encloses (interval 1 10) (interval 1 11))) (bool #f))
(check-equal? (iv (encloses (interval -3 10) (interval -4 10))) (bool #f))
(check-equal? (iv (encloses (interval -1 3) (interval -1 2))) (bool #t))
(check-equal? (iv (encloses (interval -10 -1) (interval -9 -1))) (bool #t))
(check-equal? (iv (encloses (interval -10 -1) (interval -11 -1))) (bool #f))
(check-equal? (iv (encloses (interval 0 0) (interval 0 0))) (bool #t))


; custom macro - or
(check-equal? (iv (or-or (bool #f) (bool #f))) (bool #f))
(check-equal? (iv (or-or (bool #t) (bool #f))) (bool #t))
(check-equal? (iv (or-or (bool #f) (bool #t))) (bool #t))
(check-equal? (iv (or-or (bool #t) (bool #t))) (bool #t))

; custom macro - and
(check-equal? (iv (and-and (bool #f) (bool #f))) (bool #f))
(check-equal? (iv (and-and (bool #t) (bool #f))) (bool #f))
(check-equal? (iv (and-and (bool #f) (bool #t))) (bool #f))
(check-equal? (iv (and-and (bool #t) (bool #t))) (bool #t))
