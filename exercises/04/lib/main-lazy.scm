(load "env.scm")
(load "keyword.scm")
(load "builtin.scm")
(load "trunk.scm")

(define (actual-value exp env)
  (force-it (eval exp env)))

(define (eval-if exp env)
  (if (true? (actual-value (if-predicate exp) env))
    (eval (if-consequent exp) env)
    (eval (if-alternative exp) env)))

(define (eval exp env)
  (cond ((self-evaluating? exp) exp)
        ((variable? exp) (lookup-variable-value exp env))
        ((quoted? exp) (text-of-quotation exp))
        ((assignment? exp) (eval-assignment exp env))
        ((definition? exp) (eval-definition exp env))
        ((if? exp) (eval-if exp env))
        ((lambda? exp)
          (make-procedure (lambda-parameters exp)
                          (lambda-body exp)
                          env))
        ((begin? exp)
          (eval-sequence (begin-actions exp) env))
        ((cond? exp)
          (eval (cond->if exp) env))
        ((application? exp)
          (apply-inner (actual-value (operator exp) env)
                       (operands exp)
                       env))
        (else
          (error "Unknown expression type -- EVAL " env))))

; 这里将 eval 实现为一个采用 cond 的分情况分析。这样做的缺点是我们的过程只处理了若干种不同类型的表达式。
; 在大部分的 Lisp 实现里,针对表达式类型的分派都采用了数据导向的方式。这样用户可以更容易增加 eval 能分辨的表达式类型,而又不必修改 eval 的定义本身。


(define (apply-inner procedure arguments env)
  (cond ((primitive-procedure? procedure)
          (apply-primitive-procedure procedure
                                     (list-of-arg-values arguments env)))
        ((compound-procedure? procedure)
          (eval-sequence
            (procedure-body procedure)
            (extend-environment (procedure-parameters procedure)
                                (list-of-delayed-values arguments env)
                                (procedure-environment procedure))))
        (else
          (error "Unknown procedure type --  APPLY " procedure))))

(define (list-of-arg-values exps env)
  (if (no-operands? exps)
    '()
    (cons (actual-value (first-operand exps) env)
          (list-of-arg-values (rest-operands exps)
                              env))))
(define (list-of-delayed-values exps env)
  (if (no-operands? exps)
    '()
    (cons (delay-it (first-operand exps) env)
          (list-of-delayed-values (rest-operands exps) env))))


(define input-prompt ";;; M-Eval input: ")
(define output-prompt ";;; M-Eval values: ")
(define (driver-loop)
  (prompt-for-input input-prompt)
  (let ((input (read)))
    (let ((output (actual-value input the-global-environment)))
      (announce-output output-prompt)
      (user-print output)))
  (driver-loop))
(define (prompt-for-input string)
  (newline) (newline) (display string) (newline))
(define (announce-output string)
  (newline) (display string) (newline))
(define (user-print object)
  (if (compound-procedure? object)
    (display (list 'compound-procedure
                    (procedure-parameters object)
                    (procedure-body object)
                    '<procedure-env>))
    (display object)))

(define the-global-environment (setup-environment))
(driver-loop)
