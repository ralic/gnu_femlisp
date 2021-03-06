;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; locref.lisp - testing local refinements
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

(in-package :fl.application)

(file-documentation
 "This file contains tests for solving of CDR problems with local
refinement.")

(defun laplace-1d-locally-refined (boundary-p nr-of-local-refinements)
  (let* ((problem (cdr-model-problem 1))
	 (fe-class (lagrange-fe 1))
	 (h-mesh (uniformly-refined-hierarchical-mesh
		  (domain problem) (if boundary-p 1 2))))
    (loop repeat nr-of-local-refinements do
	 (refine h-mesh :indicator (rcurry #'inside-cell? (if boundary-p #d(0.0) #d(0.5)))))
    (discretize-globally problem h-mesh fe-class)))

(defun test-refined-laplace-problem ()
  
  (multiple-value-bind (mat rhs)
      (laplace-1d-locally-refined t 1)
      (show rhs)
      (show mat)
      (let* ((v-cycle (geometric-cs :base-level 0 :post-steps 0 :pre-steps 0))
	     (mg-data (multilevel-decomposition v-cycle mat)))
	(show (aref (getbb mg-data :a-vec) 0))
	#+(or)(show (aref (getbb mg-data :i-vec) 0))
	))

(let* ((problem (cdr-model-problem
		 (n-cube-domain 1)
		 :source #'(lambda (x) #I"exp(-5*(x[0]-0.5)^^2)*sin(x[0]-0.5)")))
       (fe-class (lagrange-fe 1))
       (h-mesh (uniformly-refined-hierarchical-mesh (domain problem) 2)))
  (multiple-value-bind (mat rhs)
	(discretize-globally problem h-mesh fe-class)
    (let ((sol (getrs (sparse-ldu mat) rhs)))
      ;;(plot sol)
      (show sol))))


;; 2D case
(time
 (let* ((dim 2) (order 1)
	(problem (cdr-model-problem (n-cube-domain dim)))
	(fedisc (lagrange-fe order))
	(h-mesh (make-hierarchical-mesh-from-domain (domain problem))))
   #-(or) (loop repeat 2 do (refine h-mesh :indicator (rcurry #'inside-cell? #d(0.25 0.25))))
   #+(or) (plot h-mesh)
   (multiple-value-bind (mat)
       (discretize-globally problem h-mesh fedisc)
     (display mat :order (row-keys mat))
     (row-keys mat))))

;; double refinement jump
(let* ((problem (cdr-model-problem 2))
       (fedisc (lagrange-fe 1))
       (h-mesh (make-hierarchical-mesh-from-domain (domain problem))))
  #+(or) (loop repeat 1 do (refine h-mesh) (refine h-mesh) (refine h-mesh))
  #-(or) (loop repeat 3 do (refine h-mesh :indicator (rcurry #'inside-cell? #d(0.25 0.25))))
  #+(or) (plot h-mesh)
  (multiple-value-bind (mat rhs)
      (discretize-globally problem h-mesh fedisc)
    (let ((sol #+(or) (linsolve mat rhs :output t :iteration (f-cycle :problem problem))
	       #-(or) (getrs (sparse-ldu mat) rhs)))
      ;; (plot sol)
      (show sol))))
  
  ;; end of local refinement tests
)

;;;; (test-refined-laplace-problem)
(fl.tests:adjoin-test 'test-refined-laplace-problem)

