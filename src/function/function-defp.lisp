;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; function-defp.lisp
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

(defpackage "FL.FUNCTION"
  (:use "COMMON-LISP" "FL.MACROS" "FL.UTILITIES" "FL.DICTIONARY" "FL.MATLISP")
  (:export
   ;; from function.lisp
   "<FUNCTION>" "DOMAIN-DIMENSION" "IMAGE-DIMENSION"
   "EVALUATE" "EVALUATE-GRADIENT"
   "MULTIPLE-EVALUATE" "MULTIPLE-EVALUATE-GRADIENT" "DIFFERENTIABLE-P"
   "<CONSTANT-FUNCTION>" "<LINEAR-FUNCTION>"
   "<SPECIAL-FUNCTION>" "SPECIAL-1D-FUNCTION"
   "TRANSFORM-FUNCTION" "HOMOTOPY"
   "ELLIPSE-MATRIX" "PROJECT-TO-ELLIPSOID"
   "PROJECT-TO-SPHERE" "XN-DISTORTION-FUNCTION"
   "CIRCLE-FUNCTION"
   "INTERVAL-METHOD"  "NUMERICAL-GRADIENT" "NUMERICAL-COMPLEX-DERIVATIVE"
   "SPARSE-FUNCTION" "SPARSE-REAL-DERIVATIVE"
   
   ;; polynom.lisp
   "POLYNOMIAL" "COEFFICIENTS" "SHIFT-POLYNOMIAL"
   "DEGREE" "TOTAL-DEGREE" "PARTIAL-DEGREE" "VARIANCE" "MAXIMAL-PARTIAL-DEGREE"
   "MAKE-POLYNOMIAL" "ELIMINATE-SMALL-COEFFICIENTS" "ZERO?" "UNIT?" "ZERO" "UNIT"
   "SPLIT-INTO-MONOMIALS" "INTEGRATE-SIMPLE-POLYNOMIAL"
   "POLY*" "POLY-EXTERIOR-PRODUCT" "POLY-EXPT" "DIFFERENTIATE" "GRADIENT"
   "N-VARIATE-MONOMIALS-OF-DEGREE"
   "LAGRANGE-POLYNOMIALS"

   ;; spline.lisp
   "<POLYGON>" "<PERIODIC-POLYGON>" "CUBIC-SPLINE"
   ))
