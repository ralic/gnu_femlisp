;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; blockit.lisp
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
;;;; block iterations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass <block-iteration> (<linear-iteration>)
  ((inner-iteration
    :reader inner-iteration :initform nil
    :initarg :inner-iteration
    :documentation "Iteration which is used to solve for each block.")
   (ordering :accessor ordering :initform nil :initarg :ordering)
   (store-p
    :reader store-p :initform nil :initarg :store-p
    :documentation "T if diagonal can be stored."))
  (:documentation "Subspace correction scheme generated by collecting
overlapping blocks of unknowns."))

(defgeneric setup-blocks (blockit matrix)
  (:documentation "Setup routine for determining the blocking of unknowns.
Returns a list of blocks where each block is a vector of keys.  May return
a second value which is a list of pair.  Each pair is of the form
start-index/end-index and can be used to filter out different fe
components."))

(defmethod setup-blocks ((blockit <block-iteration>) (smat <sparse-matrix>))
  "If a setup function is provided, it is called.  The default is to use
the standard blocking introduced by the block sparse matrix."
  (values (mapcar #'vector (row-keys smat)) nil))

(defmethod setup-blocks :around ((blockit <block-iteration>) (smat <sparse-matrix>))
  "A default around method for block setup does debugging output."
  (multiple-value-bind (blocks ranges)
      (call-next-method)
    (dbg :iter "blocks=~A~%ranges=~A" blocks ranges)
    (values blocks ranges)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Block-Jacobi and Block-Gauss-Seidel
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass <psc> (<block-iteration>)
  ()
  (:documentation "Parallel subspace correction scheme."))

(defclass <ssc> (<block-iteration>)
  ((omega :initform 1.0 :initarg :omega))
  (:documentation "Successive subspace correction scheme."))

(defclass <setup-blocks-mixin> ()
  ((block-setup
    :initform nil :initarg :block-setup :documentation
    "Contains NIL or a function which is called for block setup."))
  (:documentation "Executes the given function for determining the block
decomposition."))

(defclass <custom-psc> (<setup-blocks-mixin> <psc>)
  ()
  (:documentation "PSC with custom BLOCK-SETUP function slot."))

(defclass <custom-ssc> (<setup-blocks-mixin> <ssc>)
  ()
  (:documentation "SSC with custom BLOCK-SETUP function slot."))

(defmethod setup-blocks ((blockit <setup-blocks-mixin>) (smat <sparse-matrix>))
  "Use the setup function."
  (funcall (slot-value blockit 'block-setup) blockit smat))

(defun compute-block-inverse (smat keys ranges)
  (m/ (sparse-matrix->matlisp
       smat :keys keys :ranges ranges)))

(defun compute-block-inverses (smat blocks ranges)
  (dbg :iter "computing block-inverses")
  (loop for keys in blocks
	and ranges-tail = ranges then (cdr ranges-tail) ; may be NIL
	collecting (compute-block-inverse smat keys (car ranges-tail))))

(defmethod make-iterator ((iter <block-iteration>) (smat <sparse-matrix>))
  (multiple-value-bind (blocks ranges)
      (setup-blocks iter smat)
    (dbg :iter "blocks=~A~%ranges=~A" blocks ranges)
    (let ((diagonal-inverses
	   (if (store-p iter)
	       (compute-block-inverses smat blocks ranges)
	       (make-list (length blocks)))))
      (make-instance
       '<iterator>
       :matrix smat
       :residual-before t
       :initialize nil
       :iterate
       #'(lambda (x b r)
	   (dbg :iter "iterating ~A" iter)
	   (let ((damp (typecase iter
			 (<psc> (slot-value iter 'damp))
			 (<ssc> (assert (= 1.0 (slot-value iter 'damp)))
				(slot-value iter 'omega)))))
	     (loop
	      for block in blocks
	      and ranges-tail = ranges then (cdr ranges-tail) ; may be NIL
	      for block-ranges = (car ranges-tail)
	      and diag-inverse in diagonal-inverses do
	      ;; ssc: update residual on the block (disregarding ranges)
	      (when (typep iter '<ssc>)
		(loop for key across block do
		      (copy! (vref b key) (vref r key))
		      (for-each-key-and-entry-in-row
		       #'(lambda (col-key mblock)
			   #-(or)(gemm! -1.0 mblock (vref x col-key) 1.0 (vref r key))
			   ;; warning: does not work
			   #+(or)(x-=Ay (vref r key) mblock (vref x col-key)))
		       smat key)))
	      ;; solve for local block
	      (let ((local-r (sparse-vector->matlisp r block block-ranges))
		    (local-x (sparse-vector->matlisp x block block-ranges))
		    (local-mat (sparse-matrix->ccs smat :keys block :ranges (car ranges-tail))))
		(cond
		  ((inner-iteration iter)
		   (let ((bb (blackboard :problem (lse :matrix local-mat :rhs local-r))))
		     (solve (inner-iteration iter) bb)
		     (axpy! damp (getbb bb :solution) local-x)))
		  (diag-inverse
		   (gemm! damp diag-inverse local-r 1.0 local-x))
		  (t (gesv! local-mat local-r)
		     (axpy! damp local-r local-x)))
		(set-svec-to-local-block x local-x block block-ranges))))
	   x)
       :residual-after nil))))

