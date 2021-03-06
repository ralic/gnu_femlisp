;;; -*- mode: lisp; fill-column: 64; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; driven-cavity.lisp - Driven cavity computations
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

(defun watch-velocity-and-pressure-at-point (point &key (velocity-p t) (pressure-p t))
  "Returns a observe list for watching the velocity at @arg{point}."
  (let ((dim (length point)))
    (list (concatenate 'string
                       (and velocity-p
                            (format nil "~{                 u~1D~}" (range<= 1 dim)))
                       (and pressure-p
                            (format nil "                  p")))
	  "~{~19,10,2E~}"
	  #'(lambda (blackboard)
	      (with-items (&key solution) blackboard
		(let ((val (fe-value solution point)))
		  (loop for i below (+ (if velocity-p dim 0) (if pressure-p 1 0))
                     collect (vref (aref val i) 0))))))))

(defun watch-velocity-at-point (point)
  "Returns a observe list for watching the velocity at @arg{point}."
  (let ((dim (length point)))
    (list (format nil "~{                 u~1D~}" (range<= 1 dim))
	  "~{~19,10,2E~}"
	  #'(lambda (blackboard)
	      (with-items (&key solution) blackboard
		(let ((val (fe-value solution point)))
		  (loop for i below dim collect (vref (aref val i) 0))))))))

(defun watch-dc-center-velocity (dim)
  "Returns a observe list for watching the velocity at the center of the
driven cavity."
  (watch-velocity-at-point (make-double-vec dim 0.5)))

(defun ns-driven-cavity-demo (dim order levels &key
                              (delta 1) (base-level 1)
			      (plot-mesh t) plot output (reynolds 0.0) smooth-p
			      (watch-points (list (make-double-vec dim 0.5))))
  "Performs the driven cavity demo."
  (storing
    (solve 
     (blackboard
      :fe-class (navier-stokes-lagrange-fe order dim delta)
      :problem
      (driven-cavity dim :reynolds reynolds :smooth-p smooth-p)
      :base-level base-level ; (if (evenp order) 0 1)  ; the system is severely singular otherwise
      :success-if (if levels
		      `(= :nr-levels ,levels)
		      `(> :time ,*demo-time*))
      :plot-mesh plot-mesh :output output :observe
      (append *stationary-fe-strategy-observe*
	      (mapcar #'watch-velocity-at-point watch-points)))))
  (when plot
    ;; plot components solution tensor
    (plot (getbb *result* :solution) :component 'fl.navier-stokes::u
	  :shape 2 :rank 1)))

;;; (ns-driven-cavity-demo 2 3 3 :output :all :plot t :reynolds 10.0)
;;; (plot (getbb *result* :solution) :component 0 :depth 2)

(defun make-driven-cavity-demo (dim order reynolds)
  (let ((title (format nil "DC-~DD-~A" dim reynolds))
	(short (format nil "Solves the driven cavity problem (Re=~A)." reynolds))
	(long (format nil "Solve the ~DD driven cavity problem
for the Navier-Stokes equation using Taylor-Hood finite elements
[Q^~D]^~D-Q^~D." dim (1+ order) dim order)))
    (let ((demo
	   (make-demo
	    :name title :short short :long long :execute
	    (lambda ()
	      (ns-driven-cavity-demo dim order 4 :output 1 :plot t
				     :reynolds (float reynolds 1.0))))))
      (adjoin-demo demo *navier-stokes-demo*))))

;;(ns-driven-cavity-demo 2 2 3 :output :all :plot t :reynolds 0.0)

(make-driven-cavity-demo 2 2 0)
(make-driven-cavity-demo 2 2 100)

;;;; Testing:

(defun test-driven-cavity ()
  
  (let* ((dim 2) (reynolds 500.0)
         (order 1) (delta 1) (levels 1)
         (FL.NAVIER-STOKES::*ALPHA* 1.0)
         (FL.NAVIER-STOKES::*BETA* 1.0)
         (initial-mesh-refinements 1)
         (problem
           (driven-cavity dim :reynolds reynolds))
         (mesh (let ((mesh (triangulize (make-mesh-from (domain problem)))))
                 (loop repeat initial-mesh-refinements
                       do (setf mesh (refine mesh)))
                 (change-class mesh '<hierarchical-mesh>)))
         )
    (storing
      (solve
       (blackboard
        :problem (driven-cavity dim :reynolds reynolds)
        :mesh mesh
        :initial-mesh-refinements initial-mesh-refinements
        :fe-class (navier-stokes-lagrange-fe order dim delta)
	:estimator nil
	:indicator (make-instance '<uniform-refinement-indicator>)
        :solver
        (make-instance
         '<newton>
         :linear-solver (?1 (lu-solver) ; for testing purposes
                            (make-instance
                             '<linear-solver> :iteration
                             (let ((smoother (make-instance '<vanka> :store-p nil)))
                               (make-instance
                                '<geometric-cs>
                                :coarse-grid-iteration
                                (make-instance '<multi-iteration> :nr-steps 10 :base smoother)
                                :smoother smoother :pre-steps 1 :post-steps 1 :gamma 2))
                             :success-if `(and (> :step 4) (> :step-reduction 0.8) (< :defnorm 1.0e-3))
                             :failure-if `(and (> :step 4) (> :step-reduction 1.0) (> :defnorm 1.0e-3))))
         :success-if `(and (> :step 3) (> :step-reduction 0.5) (< :defnorm 1.0e-8))
         :failure-if '(and (> :step 3) (> :step-reduction 1.0) (> :defnorm 1.0e-8)))
	:success-if `(>= :nr-levels ,levels)
        :plot-mesh t :output 3 :observe
        (append *stationary-fe-strategy-observe*
                (mapcar #'watch-velocity-at-point
                        (list (make-double-vec dim .5)
                              (make-double-vec dim .25))))))))
  ;; (sb-sprof:with-profiling
  ;;     (:max-samples 10000)
  ;;(sb-sprof:report :type :flat :sort-by :cumulative-samples :max 200)

  #|
  Step   CELLS      DOFS     CPU                 u1                 u2                   u1                 u2  
----------------------------------------------------------------------------------------------------------------
   0       8        59     0.4    -4.0037048815e-01  -2.6525593710e-01     8.3635145999e-02   1.5579218079e-01  
   1      32       246     1.5    -3.0476559085e-01   5.1094944061e-02    -5.8428538237e-02   8.2959600910e-02  
   2     128       905     4.6    -2.1348632736e-01   5.8511532064e-02    -7.5324554492e-02   5.7917629666e-02  
   3     512    3.372K    14.5    -2.0909204178e-01   5.7342875478e-02    -7.3601831328e-02   5.6051287272e-02  
   4  2.048K   12.911K    53.2    -2.0912956384e-01   5.7533872539e-02    -7.3609371646e-02   5.6040701070e-02  
   5  8.192K   50.418K   218.7    -2.0914714004e-01   5.7541898889e-02    -7.3611195765e-02   5.6038822786e-02  
   6  32.77K  199.157K   951.7    -2.0914916195e-01   5.7537483418e-02    -7.3610662904e-02   5.6037662013e-02  
   7  131.1K  791.298K [8274.4]   -2.0914918457e-01   5.7536619692e-02    -7.3610611938e-02   5.6037542987e-02                                    
  |#
  
  (plot (getbb *result* :solution) :component 'fl.navier-stokes::u
                                   :shape 2 :rank 1)
  (describe (driven-cavity 2))
  (describe (domain (driven-cavity 2 :smooth-p nil)))
  (ns-driven-cavity-demo 2 1 3 :base-level 1 :delta 1 :output 2 :plot-mesh nil :reynolds 40.0
                               :watch-points (list #d(0.5 0.5) #d(0.25 0.25)))
  #+(or)(dbg-on :iter)
  #+(or)
  (defmethod intermediate :after ((it fl.iteration::<linear-solver>) bb)
    (show (getbb bb :residual))
    #+(or)
    (?2 (plot (getbb bb :residual) :component 'fl.navier-stokes::u
              :rank 1 :shape 2
              :depth 2)
        (plot (getbb bb :residual) :component 'fl.navier-stokes::p :depth 2)))
  (plot (getbb *result* :mesh))
  ;; Step   CELLS      DOFS     CPU                   u1                 u2  
  ;; ------------------------------------------------------------------------
  ;;    0       4        59     5.3    -1.7073170732e-01   1.6130654740e-15  
  ;;    1      16       246     6.8    -2.0480181191e-01   1.2711597399e-16  
  ;;    2      64       905     8.5    -2.0527904303e-01  -5.0822153595e-17  

  (discretization-order (component (fe-class (getbb *result* :ansatz-space)) 1))
  (plot (getbb *result* :solution) :component 'fl.navier-stokes::u
        :rank 1 :shape 2)
  (let ((sol (getbb *result* :solution)))
    (fe-value sol #d(0.5 0.5)))
  (storing
    (let* ((dim 2) (order 3) (delta 1)
	   (problem (driven-cavity dim :smooth-p nil))
	   (mesh
	    (change-class
	     (triangulate (domain problem) :meshsize 0.01 :indicator
			  #'(lambda (patch x h)
			      (declare (ignore patch))
			      (let ((d (min (norm (m- x #d(0.0 1.0)))
					    (norm (m- x #d(1.0 1.0))))))
				(cond
				  ((>= h 0.25) :yes)
				  ((<= h (* 0.5 d)) :no)))))
	     '<hierarchical-mesh>))
	   (as (make-fe-ansatz-space (navier-stokes-lagrange-fe order dim delta)
				     problem mesh)))
      (solve (blackboard :problem problem :mesh mesh :ansatz-space as
			 :output :all :success-if '(> :time 30.0) :observe
			 (append *stationary-fe-strategy-observe*
				 (list (watch-dc-center-velocity dim)))))))
  (plot (getbb *result* :solution) :component 'fl.navier-stokes::u
        :rank 1 :shape 2)
  (plot (getbb *result* :solution) :component 'fl.navier-stokes::p)
  (fe-extreme-values (getbb *result* :solution))
  (time (plot (getbb *result* :solution) :component 1))
  ;; (time (plot (component (getbb *result* :solution) 1)))
)

;;; (test-driven-cavity)
(fl.tests:adjoin-test 'test-driven-cavity)


