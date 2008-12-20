;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; macros.lisp - Useful macro definitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Copyright (C) 2003 Nicolas Neuss, University of Heidelberg.
;;; All rights reserved.
;;; 
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions are
;;; met:
;;; 
;;; 1. Redistributions of source code must retain the above copyright
;;; notice, this list of conditions and the following disclaimer.
;;; 
;;; 2. Redistributions in binary form must reproduce the above copyright
;;; notice, this list of conditions and the following disclaimer in the
;;; documentation and/or other materials provided with the distribution.
;;; 
;;; THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
;;; WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
;;; MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
;;; NO EVENT SHALL THE AUTHOR, THE UNIVERSITY OF HEIDELBERG OR OTHER
;;; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
;;; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
;;; PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;; PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;; LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defpackage "FL.MACROS"
  (:use "COMMON-LISP")
  (:export
   "WITH-GENSYMS" "SYMCONC" "AWHEN" "WHEREAS" "AIF" "BIF" "STRINGCASE"
   "AAND" "ACOND" "_F" "DELETEF" "IT" "ENSURE" "ECHO"
   "REMOVE-THIS-METHOD"
   "NAMED-LET" "FOR" "FOR<" "MULTI-FOR" "INLINING" "DEFINLINE"
   "?1" "?2" "?3"
   "DELAY" "FORCE"
   "FLUID-LET" "LRET" "LRET*" "CHAIN" "_" "SHOW-CALL"
   "QUICKLY" "SLOWLY" "VERY-QUICKLY" "*USUALLY*" "USUALLY-QUICKLY"
   "QUICKLY-IF")
  (:documentation
   "This package contains some basic macro definitions used in Femlisp."))

(in-package :fl.macros)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmacro with-gensyms (syms &body body)
  "Standard macro providing the freshly generated symbols @arg{syms} to the
code in @arg{body}."
  `(let ,(mapcar #'(lambda (s) `(,s (gensym ,(symbol-name s))))
		 syms)
    ,@body)))

(defun symconc (&rest args)
  "This function builds a symbol from its arguments and interns it.  This
is used in some macros."
  (intern
   (apply #'concatenate 'string
	  (mapcar #'(lambda (arg) (if (symbolp arg)
				      (symbol-name arg)
				      arg))
		  args))
   (let ((sym (find-if #'symbolp args)))
     (if sym
	 (symbol-package sym)
	 *package*))))

(defmacro whereas (clauses &rest body)
  "Own implementation of the macro @function{whereas} suggested by Erik
Naggum (c.l.l., 4.12.2002)."
  (if (null clauses)
      `(progn ,@body)
      (destructuring-bind ((var expr &optional type) . rest-clauses)
	  clauses
	`(let ((,var ,expr))
	  ,(when type `(declare (type ,type ,var)))
	  (when ,var
	    (whereas ,rest-clauses ,@body))))))

(defmacro aif (test-form then-form &optional else-form)
  `(let ((it ,test-form))
     (if it ,then-form ,else-form)))

(defmacro bif ((bindvar boundform) yup &optional nope)
  "Posted to cll by Kenny Tilton 22.4.2007."
   `(let ((,bindvar ,boundform))
       (if ,bindvar
          ,yup
          ,nope)))

(defmacro awhen (test-form &body body)
  "Anaphoric macro from @cite{(Graham 1993)}."
  `(let ((it ,test-form))
     (when it ,@body)))

(defmacro awhile (expr &body body)
  "Anaphoric macro from @cite{(Graham 1993)}."
  `(do ((it ,expr ,expr))
    ((not it))
    ,@body))

(defmacro aand (&rest args)
  "Anaphoric macro from @cite{(Graham 1993)}."
  (cond ((null args) t)
	((null (cdr args)) (car args))
	(t `(aif ,(car args) (aand ,@(cdr args))))))

(defmacro acond (&rest clauses)
  "Anaphoric macro from @cite{(Graham 1993)}."
  (if (null clauses)
      nil
      (let ((cl1 (car clauses))
            (sym (gensym)))
        `(let ((,sym ,(car cl1)))
           (if ,sym
               (let ((it ,sym))
		 (declare (ignorable it))
		 ,@(cdr cl1))
               (acond ,@(cdr clauses)))))))

(defmacro stringcase (string &body clauses)
  "An analog to case using string comparison."
  (with-gensyms (item)
    `(let ((,item ,string))
       (cond ,@(loop for (what . commands) in clauses
                  collect
                  (typecase what
                    (cons `((member ,item (quote ,what) :test #'string=) ,@commands))
                    (string `((string= ,item ,what) ,@commands))
                    (t `(t ,@commands))))))))

(defmacro _f (op place &rest args)
  "Macro from @cite{(Graham 1993)}.  Turns the operator @arg{op} into a
modifying form, e.g. @code{(_f + a b) @equiv{} (incf a b)}."
  (multiple-value-bind (vars forms var set access) 
      (get-setf-expansion place)
    `(let* (,@(mapcar #'list vars forms)
            (,(car var) (,op ,access ,@args)))
       ,set)))

(defmacro deletef (item sequence &rest args)
  "Delets @arg{item} from @arg{sequence} destructively."
  (multiple-value-bind (vars forms var set access) 
      (get-setf-expansion sequence)
    `(let* (,@(mapcar #'list vars forms)
            (,(car var) (delete ,item ,access ,@args)))
       ,set)))

(define-modify-macro ensure (&rest args) or
   "Ensures that some place is set.  It expands as follows:
@lisp
  (ensure place value) @expansion{} (or place (setf place value)) @end lisp
It is not clear if the implementation used here works everywhere.  If not,
the workaround below should be used.")

#+(or)
(defmacro ensure (place newval &environment env)
  "Essentially (or place (setf place newval)).  Posted by Erling Alf to
c.l.l. on 11.8.2004, implementing an idea of myself posted on c.l.l. on 30
Jul 2004 in a probably more ANSI conforming way."
  (multiple-value-bind (vars vals putvars putform getform) 
      (get-setf-expansion place env)
    `(let* ,(mapcar #'list vars vals)
       (or ,getform
	   (multiple-value-bind ,putvars
	       ,newval
	     ,putform)))))

(defmacro echo (ekx-id &rest body)
  "Posted to cll at 17.10.2006 by Kenny Tilton."
  (let ((result (gensym)))
    `(let ((,result (,@body)))
       (format t "~&~a -> ~a"
          ,(string-downcase (symbol-name ekx-id)) ,result)
       ,result)))

;;; Others

(defmacro short-remove-method (gf-name qualifiers specializers)
  "Removes the method for the generic function @arg{gf-name} which is
specified by @arg{qualifiers} and @arg{specializers}.  Example:
@lisp
  (short-remove-method m* (:before) (<sparse-matrix> <sparse-vector>))
@end lisp"
  `(remove-method
    (function ,gf-name)
    (find-method (function ,gf-name) (quote ,qualifiers)
     (mapcar #'find-class (quote ,specializers)))))

(defmacro remove-this-method (gf-name &rest rest)
  "Removes the method for the generic function @arg{gf-name} which is
specified by @arg{qualifiers} and @arg{specializers}.  Example:
@lisp
  (remove-this-method m* :before ((mat <matrix>) (x <vector>)))
@end lisp
It should be possible to use this directly on a copied first line of a
DEFMETHOD definition."
  (let ((next (first rest)))
    (multiple-value-bind (qualifiers args)
	(if (member next '(:before :after :around))
	    (values (list next) (second rest))
	    (values () next))
      (let ((specializers (mapcar #'(lambda (arg)
				      (if (consp arg)
					  (second arg)
					  t))
				  args)))
	`(remove-method
	  (function ,gf-name)
	  (find-method (function ,gf-name) (quote ,qualifiers)
	   (mapcar #'find-class (quote ,specializers))))))))

(defmacro named-let (name bindings &body body)
  "Implements the named-let construct from Scheme."
  `(labels ((,name ,(mapcar #'first bindings)
              ,@body))
     (,name ,@(mapcar #'second bindings))))

(defmacro for ((var start end) &body body)
  "Loops for @arg{var} from @arg{start} upto @arg{end}."
  (let ((limit (gensym)))
    `(let ((,limit ,end))
       (do ((,var ,start (+ ,var 1)))
	   ((> ,var ,limit))
	 ,@body))))

(defmacro for< ((var start end) &body body)
  "Loops for @arg{var} from @arg{start} below @arg{end}."
  (let ((limit (gensym)))
    `(let ((,limit ,end))
       (do ((,var ,start (+ ,var 1)))
	   ((>= ,var ,limit))
	 ,@body))))

(defmacro multi-for ((var start stop) &body body)
  "Loops for @arg{var} being an integer vector starting from @arg{start}
upto @arg{end}.  Example:
@lisp
  (multi-for (x #(1 1) #(3 3)) (princ x) (terpri))
@end lisp"
  (let ((fixnum-vec '(simple-array fixnum (*))))
    (with-gensyms
	(inc! begin end inside)
      `(let ((,begin (coerce ,start ',fixnum-vec))
	     (,end (coerce ,stop ',fixnum-vec)))
	;;(declare (type ,fixnum-vec ,begin ,start))
	(flet ((,inc! (x)
		 (declare (type ,fixnum-vec x))
		 (dotimes (i (length ,begin))
		   (cond ((< (aref x i) (aref ,end i))
			  (incf (aref x i))
			  (return t))
			 (t (setf (aref x i) (aref ,begin i)))))))
	  (do ((,var (copy-seq ,begin))
	       (,inside (every #'<= ,begin ,end) (,inc! ,var)))
	      ((not ,inside)) ,@body))))))

;;; delay and force
(defmacro delay (form)
  "Delays the evaluation of @arg{form}."
  (with-gensyms (value computed)
    `(let ((,computed nil)
	   (,value nil))
      (lambda ()
	(if ,computed
	    ,value
	    (prog1
		(setq ,value ,form)
	      (setq ,computed t)))))))

(defmacro force (delayed-form)
  "Forces the value of a @arg{delayed-form}."
  (with-gensyms (form)
    `(let ((,form ,delayed-form))
      (if (functionp ,form) (funcall ,form) ,form))))

(defmacro inlining (&rest definitions)
  "Declaims the following definitions inline together with executing them."
  `(progn ,@(loop for def in definitions when (eq (first def) 'defun) collect
		  `(declaim (inline ,(second def))) collect def)))

(defmacro definline (name &rest rest)
  "Short form for defining an inlined function.  It should probably be
deprecated, because it won't be recognized by default by some IDEs.  Better
use the inlining macro directly."  `(inlining (defun ,name ,@rest)))

;;; some macros for choosing between possibilities
(defmacro ?1 (&rest args)
  "A macro returning the first of its arguments."
  (first args))
(defmacro ?2 (&rest args)
  "A macro returning the second of its arguments."
  (second args))
(defmacro ?3 (&rest args)
  "A macro returning the third of its arguments."
  (third args))

(defmacro fluid-let (bindings &body body)
  "Sets temporary bindings."
  (let ((identifiers (mapcar #'car bindings)))
    (with-gensyms (saved)
      `(let ((,saved (list ,@identifiers)))
	(unwind-protect
	     (progn ,@(loop for (place value) in bindings collect
			    `(setf ,place ,value))
		    ,@body)
	  ,@(loop for (place nil) in bindings and i from 0 collect
		  `(setf ,place (nth ,i ,saved))))))))

(defmacro show-call (func &optional name)
  "Wraps a function object inside a trace form."
  (with-gensyms (result)
    `(lambda (&rest args)
      (let ((,result (multiple-value-list (apply ,func args))))
	(format t "~&~A called with ~A, produced ~A~%" ',name args ,result)
	(apply #'values ,result)))))

(defmacro lret (bindings &body body)
  "A @macro{let}-construct which returns its last binding."
  `(let
    ,bindings ,@body
    ,(let ((x (car (last bindings))))
	  (if (atom x)
	      x
	      (car x)))))

(defmacro lret* (bindings &body body)
  "A @macro{let*}-construct which returns its last binding."
  `(let*
    ,bindings ,@body
    ,(let ((x (car (last bindings))))
	  (if (atom x)
	      x
	      (car x)))))

(defmacro chain (arg &body clauses)
  "Anaphoric macro on the symbol _ which allows to express a chain of
operations."
  `(let ((_ ,arg))
    ,@(loop for clause in clauses collect `(setq _ ,clause))
    _))

;;; Macros posted by Kent Pitman on cll, 28.7.2007

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Optimization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmacro quickly (&body forms)
  `(locally (declare (optimize (speed 3) #+lispworks (float 0)))
     ,@forms))

(defmacro very-quickly (&body forms)
  `(locally (declare (optimize (safety 0) (space 0) (speed 3) #+lispworks (float 0)))
     ,@forms))

(defmacro slowly (&body forms)
  `(locally (declare (optimize (speed 1)))
     ,@forms))

(defvar *usually* t)

(defmacro usually-quickly (&body forms)
  (if *usually* ;compile-time test
      `(quickly ,@forms)
      `(progn ,@forms)))

(defmacro quickly-if (test &body forms)
  `(if ,test ;runtime test
       (quickly ,@forms)
        (progn ,@forms)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Readtables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmacro in-syntax (variable)
  "Posted by Kent M. Pitman to cll, 13.3.2008."
  #-scl
  (check-type variable (and symbol
                            (not (satisfies constantp))
                            (satisfies boundp))
              "a defined variable")
  `(eval-when (:execute :compile-toplevel :load-toplevel)
     (setq *readtable* ,variable)))


;;;; Testing:
(defun test-macros ()
  (let ((x 5))
    (ensure x 1))
  (let ((a 1) (b 2))
    (fluid-let ((a 3) (b 4))
      (list a b)))
  
  )