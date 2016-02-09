;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; linit.lisp
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

(in-package :fl.iteration)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Iteration interface
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass <linear-iteration> ()
  ((damp :initform 1.0 :initarg :damp)
   (store-p :initarg :store-p :initform nil
	    :documentation "Store decomposition for multiple applications."))
  (:documentation "The <linear-iteration> class.  Linear iterations are
e.g. <gauss-seidel> or <multigrid>."))

(defclass <iterator> ()
  ((matrix :initarg :matrix :documentation
	   "The matrix on which the iterator is working.")
   (initialize :initarg :initialize :initform nil :documentation
	       "NIL or an initialization function which is called with the
solution, rhs, and residual as arguments.")
   (initializedp :initform nil :documentation "Flag, if initialization has been done.")
   (iterate :initarg :iterate :type function :documentation "A function of
the arguments solution, rhs, and residual which performs an update step.")
   (residual-before :initarg :residual-before :documentation "T if the
residual has to be up-to-date before the iteration step.")
   (residual-after :initarg :residual-after :documentation "T if the
residual is updated through the iteration step."))
  (:documentation "An <iterator> object contains functions doing iteration
work or flags indicating which work has or has not to be done for calling
that iterator.  It is generated by the generic function make-iterator."))

(defgeneric make-iterator (linit mat)
  (:documentation "Constructs an iterator object given a linear iteration
and a matrix."))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; residual computation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod compute-residual (A x b r)
  "Default method for residual computation.  Should work for everything for
which the blas operations copy! and gemm! are defined."
  (copy! b r)
  (gemm! -1.0 A x 1.0 r)
  r)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; <multi-iteration>
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass <multi-iteration> (<linear-iteration>)
  ((base :initarg :base :documentation "Base iteration.")
   (nr-steps :initarg :nr-steps
	     :documentation "Number of steps with which the base iteration
is performed."))
  (:documentation "One step of this iteration performs nr-steps of the base
iteration."))

(defun product-iterator (iterator nr-steps)
  "Returns an iterator which does several steps of the given iterator."
  (with-slots (matrix initialize iterate residual-before residual-after)
    iterator
    (cond ((= 0 nr-steps)
	   (make-instance
	    '<iterator>
	    :matrix matrix
	    :residual-before nil
	    :initialize nil
	    :iterate #'(lambda (x b r) (declare (ignore b r)) x)
	    :residual-after nil))

	  ((= 1 nr-steps) iterator)
	  (t				; we build the product iterator
	   (make-instance
	    '<iterator>
	    :matrix matrix
	    :residual-before residual-before
	    :initialize initialize
	    :iterate
	    #'(lambda (x b r)
		(loop repeat nr-steps do
		      (funcall iterate x b r)
		      (when (and residual-before (not residual-after))
			(compute-residual matrix x b r))))
	    :residual-after residual-after)))))

(defmethod make-iterator ((multi-iter <multi-iteration>) mat)
  "Construct an iterator for a multi-iteration."
  (dbg :iter "making <multi-iteration>-iterator.")
  (with-slots (base nr-steps) multi-iter
    (product-iterator (make-iterator base mat) nr-steps)))
	  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; LU decomposition
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass <lu> (<linear-iteration>)
  ((store-p :initarg :store-p :initform t
	    :documentation "Store decomposition for multiple applications."))
  (:documentation "A linear iteration interface for the LU exact solver."))

(defmethod make-iterator ((linit <lu>) mat)
  "Default method for lu iteration."
  (with-slots (damp store-p) linit
    (let (lu ipiv)
      (when store-p
        (acond ((and (typep mat 'property-mixin)
                     (get-property mat 'fl.iteration::lu-decomposition))
                (setq lu (car it) ipiv (cdr it)))
               (t
                (multiple-value-setq (lu ipiv) (getrf! (copy mat)))
                (when (typep mat 'property-mixin)
                  (setf (get-property mat 'fl.iteration::lu-decomposition)
                        (cons lu ipiv))))))
      (make-instance
       '<iterator>
       :matrix mat
       :residual-before t
       :initialize nil
       :iterate
       #'(lambda (x b r)
	   (declare (ignore b))
	   (if store-p
	       (getrs! lu r ipiv)
	       (gesv! mat r))
	   (axpy! damp r x))
       :residual-after nil))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ILU decomposition
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass <ilu> (<linear-iteration>)
  ((omega :initform 0.0 :initarg :omega)
   (eta :initform 0.0 :initarg :eta)
   (ordering :initform () :initarg :ordering :type list))
  (:documentation "Incomplete LU iteration.  omega is the modification
parameter, eta is the diagonal enhancement."))

(defmethod make-iterator ((linit <ilu>) mat)
  "Default method for ILU iteration.  Works only for our sparse matrices."
  (with-slots (damp omega eta ordering)
    linit
    (let ((ldu (sparse-ldu mat :ordering ordering :incomplete t
			   :omega omega :diagonal-inverter
			   (shift-diagonal-inverter eta))))
      (make-instance
       '<iterator>
       :matrix mat
       :residual-before t
       :initialize nil
       :iterate #'(lambda (x b r)
		    (declare (type <sparse-vector> x b r))
		    (declare (optimize (speed 3) (safety 1)))
		    (declare (ignore b))
		    (let ((result (copy r)))
		      (getrs! ldu result)
		      (axpy! damp result x)))
       :residual-after nil))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Jacobi iteration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass <jacobi> (<linear-iteration>)
  ())

(defmethod make-iterator ((jac <jacobi>) (mat <matrix>))
  (with-slots (damp) jac
    (make-instance
     '<iterator>
     :matrix mat
     :residual-before t
     :initialize nil
     :iterate
     #'(lambda (x b r)
	 (declare (ignore b))
	 (dotimes (i (nrows mat))
	   (let ((factor (/ damp (mref mat i i))))
	     (dotimes (j (ncols r))
	       (incf (mref x i j)
		     (* factor (mref r i j)))))))
     :residual-after nil)))

(defmethod make-iterator ((jac <jacobi>) (mat <sparse-matrix>))
  (with-slots (damp) jac
    (make-instance
     '<iterator>
     :matrix mat
     :residual-before t
     :initialize nil			; one could maybe store D^{-1} here
     :iterate
     #'(lambda (x b r)
	 (declare (ignore b))
         (fl.dictionary:dic-for-each-key
          (lambda (row-key)
            (let ((rblock (fl.parallel:with-mutual-exclusion (r)
                            (vref r row-key))))
              (gesv! (mref mat row-key row-key) rblock)
              (let ((x-block (fl.parallel:with-mutual-exclusion (x)
                               (vref x row-key))))
		(axpy! damp rblock x-block)
		#+(or)(x<-0 rblock)
		)))
          (row-table mat) :parallel t)
         #+(or)
	 (for-each-row-key
	  #'(lambda (row-key)
	      (let ((rblock (vref r row-key)))
		(gesv! (mref mat row-key row-key) rblock)
		(axpy! damp rblock (vref x row-key))
		#+(or)(x<-0 rblock)
		))
	  mat))
     :residual-after nil)))

(defparameter *undamped-jacobi* (make-instance '<jacobi>))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Gauss-Seidel and SOR iteration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass <sor> (<linear-iteration>)
  ((omega :initform 1.0 :initarg :omega)
   (compare :initform nil :initarg :compare
	    :documentation "Comparison function (COMPARE MAT I J) for
sorting matrix indices I and J.  The result is used as unknown ordering for
the iteration.")))

(defmethod make-iterator ((sor <sor>) (mat standard-matrix))
  (with-slots (omega compare) sor
    (let ((ordering (range< 0 (nrows mat))))
      (when compare
	(setq ordering (safe-sort ordering (rcurry compare mat))))
      (make-instance
       '<iterator>
       :matrix mat
       :residual-before nil
       :initialize nil
       :iterate
       (lambda (x b r)
         (declare (ignore r))
         (dolist (i ordering)
           (let ((factor (/ omega (mref mat i i))))
             (dotimes (j (ncols b))
               (incf (mref x i j)
                     (* factor
                        (- (mref b i j)
                           (loop for k from 0 below (ncols mat)
                                 summing (* (mref mat i k) (mref x k j))))))))))
       :residual-after nil))))

(defmethod make-iterator ((sor <sor>) (mat <sparse-matrix>))
  (declare (optimize debug))
  (with-slots (omega compare store-p) sor
    (let ((ordering (row-keys mat))
	  (diagonal-inverse (and store-p (make-hash-table))))
      (when compare
	(setq ordering
	      (safe-sort ordering (rcurry compare mat))))
      (dbg :iter "Ordering: ~A" ordering)
      (when diagonal-inverse
        (dolist (row-key ordering)
          (setf (gethash row-key diagonal-inverse)
                (m/ (mref mat row-key row-key)))))
      (make-instance
       '<iterator>
       :matrix mat
       :residual-before nil
       :initialize nil
       :iterate
       (lambda (x b r)
         ;;(declare (ignore r))
         (dolist (row-key ordering)
           (dbg :iter "Handling rk=~A" row-key)
           (let ((corr (vref r row-key)))
             (copy! (vref b row-key) corr)
             (for-each-key-and-entry-in-row
              #'(lambda (col-key mblock)
                  (gemm! -1.0 mblock (vref x col-key) 1.0 corr))
              mat row-key)
             (cond (diagonal-inverse
                    (gemm! omega (gethash row-key diagonal-inverse) corr
                           1.0 (vref x row-key)))
                   (t (let ((entry (mref mat row-key row-key)))
                        (gesv! entry corr))
                      (axpy! omega corr (vref x row-key)))))))
       :residual-after nil))))

(defclass <parallel-sor> (<sor>)
  ()
  (:documentation "A parallel version of SOR."))

(defmethod make-iterator ((sor <parallel-sor>) (mat <sparse-matrix>))
  (declare (optimize debug))
  (with-slots (omega compare store-p) sor
    (let ((ordering (row-keys mat))
          (diagonal-inverse (and store-p (make-hash-table))))
      (when compare
        (setq ordering
              (safe-sort ordering (rcurry compare mat))))
      (dbg :iter "Ordering: ~A" ordering)
      (when diagonal-inverse
        (dolist (row-key ordering)
          (setf (gethash row-key diagonal-inverse)
                (m/ (mref mat row-key row-key)))))
      (let ((initialized-for-args nil))
        (flet ((initialize (x b r)
                 (dolist (rk ordering)
                   (vref r rk)
                   (vref b rk)
                   (for-each-key-in-row (lambda (ck) (vref x ck))
                                        mat rk))
                 (setf initialized-for-args (list x b r))))
          (make-instance
           '<iterator>
           :matrix mat
           :residual-before nil
           :initialize nil
           :iterate
           (lambda (x b r)
             (unless (equalp initialized-for-args (list x b r))
               (initialize x b r))
             ;;(declare (ignore r))
             (fl.dictionary::process-in-parallel
                 (fl.dictionary::make-parallel-heap
                  ordering (curry #'matrix-row mat))
                 (row-key)
               (let ((corr (vref r row-key)))
                 (copy! (vref b row-key) corr)
                 (for-each-key-and-entry-in-row
                  (lambda (col-key mblock)
                    (gemm! -1.0 mblock (vref x col-key) 1.0 corr))
                  mat row-key)
                 (cond (diagonal-inverse
                        (gemm! omega (gethash row-key diagonal-inverse) corr
                               1.0 (vref x row-key)))
                       (t (let ((entry (mref mat row-key row-key)))
                            (gesv! entry corr))
                          (axpy! omega corr (vref x row-key)))))))
           :residual-after nil))))))

(defclass <gauss-seidel> (<sor>)
  ()
  (:documentation "The Gauss-Seidel iteration is SOR with omega=1."))

(defmethod initialize-instance :before ((instance <gauss-seidel>) &rest initargs)
  (assert (not (getf initargs :omega))))

(defparameter *gauss-seidel* (make-instance '<gauss-seidel>))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Testing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun test-linit ()
  "Most tests can be found in linsolve.lisp."
  (make-instance '<multi-iteration> :base *undamped-jacobi* :nr-steps 2)
  ;; test LU-iteration for full and sparse matrices
  (let* ((A (laplace-sparse-matrix 3))
	 (b (make-image-vector-for A)))
    (fill-random! b 1.0)
    ;; should be stable
    (solve (make-instance '<linear-solver> :iteration (make-instance '<lu>)
			  :output t :success-if '(>= :step 3))
	   (blackboard :problem (lse :matrix A :rhs b))))
  )

;;; (test-linit)
(fl.tests:adjoin-test 'test-linit)
