;;; -*- mode: lisp; fill-column: 64; -*-

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

;;; exact values for u(1/2,...,1/2) for the solution of
;;;    - \delta u = 1
;;; in the unit square with Dirichlet boundary conditions

(defun exact-1d-solution ()
  "The precise value for x=1/2 is easily seen to be 1/8.
On the other hand it is equal to
1/pi^2 (4/pi)^d sum_{k odd} +/- 1/k^3"
  (let ((N 1000))
    (* (/ 4.0 (expt pi 3))
       (loop for i1 from N downto 0
	     for sign = (if (evenp i1) 1 -1) then (- sign)
	     for k1 = (float (1+ (* 2 i1)) 1.0)
	     sum (/ sign (* k1 k1 k1))))))

(defun exact-2d-solution ()
  "With the help of Fourier series we obtain the representation
1/pi^2 (4/pi)^d sum_{k_i odd} +/- 1/{k_1 k_2 (k_1^2+k_2^2)}
for the value u(1/2,1/2).
+/- means sin(k_1*pi/2) * sin (k_2*pi/2)"
  (time
   (let* ((N 1000)
	  (sign0 (expt -1.0 (if (evenp N) 0 1))))
     (* (/ 16.0 (expt pi 4))
	(loop for i1 from N downto 0
	      for sign1 of-type double-float = sign0 then (- sign1)
	      for k1 of-type double-float = (float (1+ (* 2 i1)) 1.0) summing
	      (loop for i2 from N downto 0
		    for sign = (* sign0 sign1) then (- sign)
		    for k2 of-type double-float = (float (1+ (* 2 i2)) 1.0)
		    sum (/ sign
			   (* k1 k2 (+ (* k1 k1) (* k2 k2))))))))))

(defun exact-3d-solution ()
  "With the help of Fourier series we obtain the representation
1/pi^2 (4/pi)^d sum_{k_i odd} +/- 1/{k_1 k_2 k_3 (k_1^2+k_2^2+k_3^2)}
for the value u(1/2,1/2,1/2).
+/- means sin(k_1*pi/2) * sin (k_2*pi/2) * sin (k_3*pi/2)"
  (time
   (let* ((N 102)
	  (sign0 (expt -1.0 (if (evenp N) 0 1))))
     (* (/ 64.0 (expt pi 5))
	(loop for i1 from N downto 0
	      for sign1 = sign0 then (- sign1)
	      for k1 = (float (1+ (* 2 i1)) 1.0) summing
	      (loop for i2 from N downto 0
		    for sign2 = (* sign0 sign1) then (- sign2)
		    for k2 = (float (1+ (* 2 i2)) 1.0) summing
		    (loop for i3 from N downto 0
			  for sign = (* sign0 sign2) then (- sign)
			  for k3 = (float (1+ (* 2 i3)) 1.0)
			  sum (/ sign
				 (* k1 k2 k3 (+ (* k1 k1) (* k2 k2) (* k3 k3)))))))))))


(defun model-problem-computation (domain &key (output 1) plot (time 5.0))
  "Performs the model problem demo."
  (storing
    (solve (blackboard
	    :problem (cdr-model-problem domain)
	    :plot-mesh t :output output :success-if `(> :time ,time))))
  (when plot
    (plot (getbb *result* :solution))))
  
(defun make-model-problem-demo (domain domain-name)
  (let ((title domain-name)
	(short (format nil "Solve the Laplace equation on a ~A." domain-name))
	(long "Solves the Laplace problem with rhs identical 1
on the given domain.  The solution strategy does uniform
refinement and terminates if more than 5 seconds have passed
after a step."))
    (let ((demo
	   (make-demo :name title :short short :long long
		      :execute (lambda ()
				 (model-problem-computation domain :plot t)))))
      (adjoin-demo demo *laplace-demo*))))

(make-model-problem-demo (n-simplex-domain 1) "unit-interval")
(make-model-problem-demo (n-simplex-domain 2) "unit-triangle")
(make-model-problem-demo (n-cube-domain 2) "unit-quadrangle")
(make-model-problem-demo (n-simplex-domain 3) "unit-tetrahedron")
(make-model-problem-demo (simplex-product-domain '(1 2)) "unit-wedge-1-2")
(make-model-problem-demo (simplex-product-domain '(2 1)) "unit-wedge-2-1")
(make-model-problem-demo (n-cube-domain 3) "unit-cube")

(defun test-laplace-model-problem ()
  (model-problem-computation (n-cube-domain 1) :plot t :time 2.0)
  (model-problem-computation (n-cube-domain 2) :plot t :time 2.0)
  (dbg-on :graphic)
  (plot (getbb *result* :solution))
  (dbg-off)

  (time
   (setq *result*
         (solve
          (make-instance
           '<stationary-fe-strategy>
           :fe-class (lagrange-fe 2)
           :success-if `(>= :nr-levels 4)
           :solver
           (?2 (let* ((smoother (make-instance '<jacobi> :damp 1.0))
                      (cs (geometric-cs
                           :gamma 1 :smoother smoother :pre-steps 1 :post-steps 0
                           :coarse-grid-iteration
                           (make-instance '<multi-iteration> :base smoother :nr-steps 1)
                           :combination :additive))
                      (bpx (make-instance '<cg> :preconditioner cs)))
                 (make-instance '<linear-solver>
                                :iteration bpx
                                :success-if `(and (> :step 2) (> :step-reduction 1.0) (< :defnorm 1.0e-11))
                                :failure-if `(and (> :step 100) (> :step-reduction 1.0) (> :defnorm 1.0e-11))
                                :output :all))
               (make-instance
                '<linear-solver>
                :iteration (let ((smoother (?2 (make-instance '<parallel-sor>) *gauss-seidel*)))
                             (geometric-cs
                              :gamma 2 :fmg nil :coarse-grid-iteration
                              (make-instance '<multi-iteration>
                                             :base smoother
                                             :nr-steps (if (typep smoother '<sor>) 10 3))
                              :smoother smoother :pre-steps 2 :post-steps 2))
                :success-if `(and (> :step 2) (> :step-reduction 0.9) (< :defnorm 1.0e-10))
                :failure-if `(> :step 20)
                :output :all))
           :plot-mesh nil)
          (blackboard
           :problem (cdr-model-problem (n-cube-domain 3)
                                       :dirichlet nil
                                       :source (lambda (x) #I(sin(2*pi*x[0])*sin(2*pi*x[1]))))
           :output :all
           ))))
  (dbg-off :iter)
  (plot (getbb *result* :solution))
  (let* ((mat (getbb *result* :matrix))
         (mesh (mesh mat))
         (cell (mapper-select-first #'for-each-key mat)))
    (parent (parent (parent (parent cell mesh) mesh) mesh) mesh))
  ;;; Elementary testing
  (let* ((dim 2) (order 1) (level 2)
	 (problem (cdr-model-problem dim))
	 (h-mesh (uniformly-refined-hierarchical-mesh (domain problem) level))
	 (fedisc (lagrange-fe order)))
    (multiple-value-bind (matrix rhs)
	(discretize-globally problem h-mesh fedisc)
      (getrs (sparse-ldu matrix) rhs)))
  
  ;;; More testing
  (format t "~%~%*** Mesh convergence tests on laplace-test-problem ***~%")
  (let ((problem (cdr-model-problem 1)))
    (format t "~%1d-case (exact solution u(0.5) = 0.125)~%")
    (check-h-convergence problem 1 3 :order 1 :position #d(0.5))
    (check-h-convergence
     problem 1 3 :order 1 :position #d(0.5)
     :solver (make-instance '<linear-solver> :iteration (geometric-cs :fmg t)
			    :success-if '(> :step 2))))
  (let ((problem (cdr-model-problem 2)))
    (format t "~%2d-case (exact solution u(0.5,0.5) = 0.0736713532...)~%")
    (time
     (check-h-convergence
      problem 1 4 :order 4 :position #d(0.5 0.5)
      :solver (make-instance '<linear-solver> :iteration (geometric-cs :fmg t)
			     :success-if '(> :step 2))))
    (time (check-p-convergence problem 1 5 :level 1 :position #d(0.5 0.5))))
  (let ((problem (cdr-model-problem 3)))
    (format t "~%3d-case (exact solution u(0.5,0.5,0.5) = 0.0562128...)~%")
    (check-h-convergence
     problem 1 3 :order 1 :position #d(0.5 0.5 0.5)
     :solver (make-instance '<linear-solver> :iteration (geometric-cs :fmg t)
			    :success-if '(> :step 2)))
    (check-p-convergence problem 1 4 :level 0 :position #d(0.5 0.5 0.5)))
  )

;;; (fl.application::test-laplace-model-problem)
(fl.tests:adjoin-test 'test-laplace-model-problem)
