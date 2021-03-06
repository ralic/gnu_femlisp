;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  product-cell.lisp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Copyright (C) 2006 Nicolas Neuss, University of Karlsruhe.
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
;;; NO EVENT SHALL THE AUTHOR, THE UNIVERSITY OF KARLSRUHE OR OTHER
;;; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
;;; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
;;; PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;; PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;; LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :fl.mesh)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; class <product-cell>
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass <product-cell> ()
  ()
  (:documentation "A mixin for simplex-product cells."))

(definline product-cell-p (obj) (typep obj '<product-cell>))

(defgeneric make-product-cell (cell1 cell2 table)
  (:documentation "Generates the product-cell product of cell1 and cell2.  The
boundary is taken from the list of lower-dimensional products supplied in
table.  The tensor product boundary is in the order de1 x e2, e1 x de2."))

(defun cartesian-product-map (func1 func2)
  (let ((n1 (domain-dimension func1))
        (n2 (domain-dimension func2))
        (m1 (image-dimension func1))
        (m2 (image-dimension func2)))
    (make-instance
     '<special-function>
     :domain-dimension (+ n1 n2)
     :image-dimension (+ m1 m2)
     :evaluator (lambda (v)
                  (join :vertical
                        (evaluate func1 (vector-slice v 0 n1))
                        (evaluate func2 (vector-slice v n1 n2))))
     :gradient (and (differentiable-p func1) (differentiable-p func2)
                    (lambda (v)
                      (lret ((result (make-real-matrix (+ m1 m2) (+ n1 n2))))
                        (minject! (evaluate-gradient func1 (vector-slice v 0 n1))
                                  result 0 0)
                        (minject! (evaluate-gradient func2 (vector-slice v n1 n2))
                                  result m1 n1)))))))
   
(defmethod make-product-cell :around ((cell1 <cell>) (cell2 <cell>) table)
  (declare (ignore table))
  (lret ((product (call-next-method)))
    (when (or (mapped-p cell1) (mapped-p cell2))
      (change-class
       product (mapped-cell-class (class-of product))
       :mapping
       (cartesian-product-map (cell-mapping cell1) (cell-mapping cell2))))))

(defun product-table (skel1 skel2)
  (let ((product-table (make-hash-table :test #'equal)))
    (doskel (cell1 skel1 :direction :up)
      (doskel (cell2 skel2 :direction :up)
	(setf (gethash (list cell1 cell2) product-table)
	      (make-product-cell
	       cell1 cell2 product-table))))
    product-table))

(defgeneric cartesian-product (obj1 obj2 &key &allow-other-keys)
  (:documentation "Computes the cartesian product of two skeletons.")
  (:method ((skel1 <skeleton>) (skel2 <skeleton>)
            &key property-combiner &allow-other-keys)
    "Computes the cartesian product of two skeletons."
    (lret ((skel (make-instance '<skeleton> :dimension
                                (+ (dimension skel1) (dimension skel2)))))
      (maphash (lambda (cells product)
                 (setf (skel-ref skel product)
                       (aand property-combiner
                             (funcall it
                                      (skel-ref skel1 (first cells))
                                      (skel-ref skel2 (second cells))))))
               (product-table skel1 skel2))))
  (:method ((cell1 <cell>) (cell2 <cell>) &key &allow-other-keys)
    (gethash (list cell1 cell2)
             (product-table (skeleton cell1) (skeleton cell2)))))

;;; special cases: products with vertices
(defmethod make-product-cell ((vtx1 <vertex>) (vtx2 <vertex>) table)
  (declare (ignore table))
  (make-vertex (concatenate 'double-vec (vertex-position vtx1) (vertex-position vtx2))))

(defmethod make-product-cell ((vtx <vertex>) (cell <cell>) table)
  (make-instance
   (class-of cell)
   :boundary (map-cell-vec #'(lambda (side) (gethash (list vtx side) table))
                           (boundary cell))))

(defmethod make-product-cell ((cell <cell>) (vtx <vertex>) table)
  (make-instance
   (class-of cell)
   :boundary (map-cell-vec #'(lambda (side) (gethash (list side vtx) table))
                           (boundary cell))))

(defmethod make-product-cell ((cell1 <cell>) (cell2 <cell>) table)
  (make-instance
   (product-cell-class
    (mapcar #'dimension
	    (append (factor-simplices cell1) (factor-simplices cell2))))
   :boundary
   (concatenate 'cell-vec
		(map-cell-vec #'(lambda (side) (gethash (list side cell2) table))
                              (boundary cell1))
		(map-cell-vec #'(lambda (side) (gethash (list cell1 side) table))
                              (boundary cell2)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; vertices
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Corners of products are products of corners of their factors.
;;; Therefore, a reasonable ordering of product-cell corners is the
;;; lexicographical ordering wrt the ordering of the corners of their
;;; factors.

(defgeneric pseudo-vertices (cell factor)
  (:documentation "Helper function for extracting all vertices of @arg{cell} in a reasonable order.")
  (:method ((cell <cell>) (factor <vertex>))
      (list (vertices cell)))
  (:method ((cell <product-cell>) (factor <simplex>))
      (let ((bdry (boundary cell))
            (factor-bdry (boundary factor)))
        (cons (car (pseudo-vertices (aref bdry 1) (aref factor-bdry 1)))
              (pseudo-vertices (aref bdry 0) (aref factor-bdry 0))))))

(defmethod vertices ((cell <product-cell>))
  (apply #'append (pseudo-vertices cell (car (factor-simplices cell)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; barycentric coordinates
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun barycentric-coordinates-factors (factors local-pos)
  "Compute a vector of weights which gives the global position by taking
the scalar product with the list of corners."
  (if (single? factors)
      (euclidean->barycentric local-pos)
      (let* ((etype (array-element-type local-pos))
             (dim1 (dimension (first factors)))
	     (weights-of-edges
	      (barycentric-coordinates-factors
	       (rest factors)
	       (make-array (- (length local-pos) dim1) :element-type etype
			   :displaced-to local-pos :displaced-index-offset dim1))))
	(apply #'concatenate 'double-vec
	       (map 'list #'(lambda (factor) (scal factor weights-of-edges))
		    (euclidean->barycentric
		     (make-array dim1 :element-type etype :displaced-to local-pos)))))))

(defmethod barycentric-coordinates ((cell <product-cell>) local-pos)
  (barycentric-coordinates-factors
   (factor-simplices (reference-cell cell)) local-pos))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; l2Dg
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun weight-lists (simplices local-pos)
  "A list of weights for several simplices at once."
  (loop for factor in simplices
	and pos = 0 then (+ pos (dimension factor))
	collect (coerce (euclidean->barycentric 
			 (make-array (dimension factor) :element-type 'double-float
				     :displaced-to local-pos :displaced-index-offset pos))
			'list)))

(defun weight-lists-grad-simplex (simplex)
   "The result of this function are weight-lists with each weight-list
corresponding to the weights for a partial derivative."
  (loop for index from 1 upto (dimension simplex) collect
       (loop for barycentric-index upto (dimension simplex) collect
	    (cond ((zerop barycentric-index) -1.0)
		  ((= barycentric-index index) 1.0)
		  (t 0.0)))))

(defun weight-lists-grad-product-cell (cell local-pos)
  (let* ((factors (factor-simplices cell))
	 (weight-lists (weight-lists factors local-pos)))
    (loop for factor in factors
	  and pos = 0 then (+ pos (dimension factor))
	  and weight-lists-tail on weight-lists
	  nconcing
	  (loop with temp = (car weight-lists-tail)
		for partial-derivative-wl in
		(weight-lists-grad-simplex factor)
		collecting
		(prog2 (shiftf temp (car weight-lists-tail) partial-derivative-wl)
		    (apply #'map-product #'* weight-lists)
		  (setf (car weight-lists-tail) temp))))))

(defmethod barycentric-gradients ((cell <product-cell>) local-pos)
  (transpose
   (make-real-matrix
    (weight-lists-grad-product-cell cell local-pos))))

(defmethod local-coordinates-of-midpoint ((cell <product-cell>))
  (apply #'concatenate 'double-vec
	 (mapcar #'local-coordinates-of-midpoint (factor-simplices cell))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; coordinates-inside?
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod coordinates-inside? ((cell <product-cell>) local-pos)
  (loop for factor in (factor-simplices cell)
	for factor-dim = (dimension factor)
	and offset = 0 then (+ offset factor-dim)
	unless (inside-cell? factor (vector-slice local-pos offset factor-dim))
	do (return nil)
	finally (return t)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Regular refinement of product-cells
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(concept-documentation
 "The generation of refinement information for @class{<product-cell>}s
assumes that the refinement data for reference simplices and
lower-dimensional products has already been generated.  The children of a
@class{<product-cell>} are taken as products of the children of its
factors.  The barycentric corners are a list of the barycentric corners in
each factor.  Finally, the boundary paths are computed.  This computation
assumes that the boundaries of a @class{<product-cell>} appear in the order
of their factors.")

(defun create-boundary-paths-of-product-cell (cell)
  "Create the boundary-paths for the <child-info> entry in the
refine-info vector."
  (loop
   for child across (refine-info cell) do
   (setf (child-boundary-paths child)
	 (loop
	  for cell-factor in (factor-simplices cell)
	  for bc-factors on (child-barycentric-corners child)
	  for bc-factor = (car bc-factors)
	  unless (single? bc-factor)	; no boundary for a nodal factor
	  nconcing
	  (loop
	   for corner in bc-factor collect
	   (labels
	       ((find-path (cell cell-factor factor-side-corners)
		  (dbg :mesh "~&cell=~A~%  cell-factor=~A~%  factor-side-corners=~A~%"
		       cell cell-factor factor-side-corners)
		  (let ((path-to-bdry (and factor-side-corners
					   (get-path-create cell-factor factor-side-corners '()))))
		    (if (<= (length path-to-bdry) 1)
			;; in the interior
			(let ((pos (position
				    (append before-factors
					    (and factor-side-corners (list factor-side-corners))
					    (cdr bc-factors))
				    (refine-info cell) :key #'child-barycentric-corners :test #'equalp)))
			  (list pos))
			;; in the interior of a boundary face (bug: apparently not all covered!)
			(let* ((factor-side-id (car path-to-bdry))
			       (side-id (+ bdry-pos factor-side-id)))
			  (assert (< side-id (length (boundary cell))))
			  (cons
			   side-id
			   (let* ((factor-bcs-in-face
				   (unless (= (dimension cell-factor) 1)
				     (mapcar #'(lambda (vec) (vector-cut vec factor-side-id))
					     factor-side-corners)))
				  (factor-side-rc (reference-cell
						   (aref (boundary cell-factor) factor-side-id))))
			     (find-path (aref (boundary cell) side-id)
					factor-side-rc
					factor-bcs-in-face))))))))
	     (find-path cell cell-factor (remove corner bc-factor :test #'equalp))))
	  summing (nr-of-sides cell-factor) into bdry-pos
	  collecting bc-factor into before-factors))))

(defmethod generate-refine-info ((refcell <product-cell>))
  "Allocates refine-info vector with barycentric-corners, then fills the
boundary paths."
  (with-cell-information (refine-info)
    refcell
    (setq refine-info
	  (coerce
	   (apply #'map-product
		  #'(lambda (&rest child-factors)
		      (make-<child-info>
		       :reference-cell
		       (ensure-simplex-product
			(remove 0 (mapcar (compose #'dimension #'child-reference-cell)
					  child-factors)))
		       :barycentric-corners
		       (apply #'append (mapcar #'child-barycentric-corners child-factors))
		       :boundary-paths ()))
		  (mapcar #'(lambda (factor) (coerce (refine-info factor) 'list))
			  (factor-simplices refcell)))
	   'child-info-vec)))
  (create-boundary-paths-of-product-cell refcell))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; <product-cell> definition/generation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun make-reference-product-cell (factor-dims)
  (reduce #'cartesian-product
	  (mapcar #'ensure-simplex factor-dims)))

(defun product-cell-class (factor-dims &optional mapped distorted)
  (let* ((class-name (intern (format nil "<~{~S-~}PRODUCT-CELL>" factor-dims) "FL.MESH"))
	 (class (find-class class-name nil)))
    (cond (class (if mapped (mapped-cell-class class distorted) class))
	  (t
	   (let ((class (eval `(defclass ,class-name (<product-cell> <standard-cell>)
                                 (,+per-class-allocation-slot+)))))
	      (let ((refcell (make-reference-product-cell factor-dims)))
		(initialize-cell-class
		 refcell (mapcar #'ensure-simplex factor-dims)))
	      class)))))

(defun ensure-simplex-product (factor-dims)
  "Returns the reference product-cell for the given factor dimensions."
  (cond ((null factor-dims) *reference-vertex*)
	((single? factor-dims) (n-simplex (car factor-dims)))
	(t (reference-cell (product-cell-class factor-dims)))))

(defun n-cube (dim)
  "Returns the reference cube of dimension dim."
  (ensure-simplex-product (make-list dim :initial-element 1)))

(defun cube-p (cell)
  "Returns T iff CELL is a cube."
  (loop for factor in (factor-simplices cell)
	always (= (dimension factor) 1)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Mapping of cubes to product-cells
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun cube-index->simplex-index (i)
  "Transforms an index in the vertex field of the cube into the
corresponding vertex index in the simplex."
  (if (zerop i)
      0
      (loop for k from 0 until (logbitp k i)
	    finally (return (1+ k)))))

(defun cube-index->product-cell-index (dims i)
  "Transforms an index in the vertex field of the cube into the
corresponding vertex index in the product-cell with the dimension DIMS of its
factors."
  (loop for dim in (reverse dims)
	and dim-offset = 0 then (+ dim-offset dim)
	and offset = 1 then (* (1+ dim) offset)
	summing (* (cube-index->simplex-index (ldb (byte dim dim-offset) i))
		   offset)))

(defun cell->cube (cell)
  "Transforms a product-cell into a degenerated cube with the same vertices."
  (let* ((dim (dimension cell))
	 (dims (mapcar #'dimension (factor-simplices cell)))
	 (vertices (coerce (vertices cell) 'vector)))
    (make-cell-from-vertices
     (product-cell-class (make-list dim :initial-element 1))
     (loop for cube-index below (expt 2 dim)
	   for cell-index = (cube-index->product-cell-index dims cube-index)
	   collect (aref vertices cell-index)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; generation of commonly used product-cells
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; simultaneously, this is a check for consistency

(defparameter *unit-quadrangle* (n-cube 2))
(defparameter *unit-cube* (n-cube 3))
(defparameter *unit-prism-1-2* (ensure-simplex-product '(1 2)))
(defparameter *unit-prism-2-1* (ensure-simplex-product '(2 1)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Tests
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-suite mesh-suite)

(test product-cell
  (is (= 0.5 (aref (global->embedded-local (aref (boundary *unit-quadrangle*) 0) #d(0.5 0.5)) 0)))
  (is-true (inside-cell? *unit-quadrangle* #d(0.0 0.0)))
  ;; should be exactly zero since no rounding errors should occur
  (is-true (zerop (- (sqrt 3.0) (diameter (n-cube 3)))))
  (finishes
    (n-cube 4)
    (ensure-simplex-product '(3 1))
    (ensure-simplex-product '(2 2))
    (ensure-simplex-product '(1 3))
    (describe *unit-quadrangle*)
    (describe (skeleton *unit-quadrangle*))
    (describe (refcell-refinement-skeleton *unit-quadrangle* 1))
    (refine-info *unit-cube*)
    (refcell-refinement-skeleton *unit-cube* 1)
    (describe (skeleton *unit-cube*))
    ;;
    (let ((child (aref (refine-info *unit-cube*) 8)))
      (format t "{D=~A} ~A :  ~A ~%"
              (dimension (child-reference-cell child))
              (child-barycentric-corners child)
              (child-boundary-paths child)))
    (skeleton *unit-quadrangle*)
    (refine (skeleton *unit-cube*))
    (global->embedded-local (aref (boundary *unit-quadrangle*) 0) #d(0.5 0.5))
    (describe (refine (skeleton *unit-cube*))))
  )
