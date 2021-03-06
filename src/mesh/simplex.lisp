;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; simplex.lisp
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

(in-package :fl.mesh)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; abstract class <simplex>
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass <simplex> ()
  ()
  (:documentation "A mixin for simplicial cells."))

(definline simplex-p (obj) (typep obj '<simplex>))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; vertices
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; The following method requires a global consistent ordering of the simplex
;;; and its skeleton.  This makes the accesses to the vertices faster and seems
;;; to be necessary for the Freudenthal/Bey simplex refinement in more than
;;; three-dimensional problems).
(defmethod vertices ((simplex <simplex>))
  (let ((bdry (boundary simplex)))
    (cons (car (vertices (aref bdry 1)))
	  (vertices (aref bdry 0)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; local->global
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun euclidean->barycentric (pos)
  (lret ((sum 1.0)
         (vec (make-double-vec (1+ (length pos)))))
    (declare (type double-float sum))
    (dotimes (i (length pos))
      (decf sum (setf (aref vec (1+ i)) (aref pos i))))
    (setf (aref vec 0) sum)))

(defmethod barycentric-coordinates ((refcell <simplex>) local-pos)
  (euclidean->barycentric local-pos))

(defmethod barycentric-gradients ((cell <simplex>) local-pos)
  (declare (ignore local-pos))
  (make-real-matrix
   (loop for barycentric-index upto (dimension cell) collect
	 (loop for index from 1 upto (dimension cell) collect
	       (cond ((zerop barycentric-index) -1.0)
		     ((= barycentric-index index) 1.0)
		     (t 0.0))))))

(defmethod l2Dg ((simplex <simplex>) local-pos)
  "Returns the linear transformation defined by the coordinates of the
simplex corners."
  (declare (ignore local-pos))
  (let* ((dim (dimension simplex))
	 (corners (corners simplex))
	 (origin (car corners))
	 (mdim (length origin))
	 (mat (make-real-matrix mdim dim)))
    (assert (= (length corners) (1+ dim)))
    (loop for corner in (cdr corners)
	  for col from 0 do
	  (dotimes (row mdim)
	    (setf (mref mat row col)
		  (- (aref corner row) (aref origin row))))
	  finally (return mat))))

(defmethod coordinates-inside? ((cell <simplex>) local-pos
                                &aux (threshold (or *inside-threshold* 0.0)))
  (and (notany (rcurry #'< (- threshold)) local-pos)
       (<= (reduce #'+ local-pos) (+ 1.0 threshold))))

(defmethod local-coordinates-of-midpoint ((cell <simplex>))
  (let ((dim (dimension cell)))
    (make-double-vec dim (/ 1.0 (1+ dim)))))

(defmethod cell-mapping ((cell <simplex>))
  "For non-mapped simplices, the cell mapping is linear."
  (let* ((n (dimension cell)) (m (embedded-dimension cell))
	 (origin (make-double-vec n)))
    (make-instance
     '<linear-function> :domain-dimension n :image-dimension m
     :A (l2Dg cell origin) :b (l2g cell origin))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Regular simplex refinement by Freudenthal/Bey
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun two-sorted-parts (n)
  "Returns all partitions of {1,...,n} which consist of two sorted
parts.  This is used in Freudenthal/Bey's simplex refinement.
Example: (two-sorted-parts 2) -> ((() (1 2)) ((1) (2)) ((2) (1)) ((1 2) ()))"
  (loop with indices = (range<= 1 n)
	for k from 0 upto n
	nconc (loop for set in (k-subsets indices k)
		    collect (list set (ordered-set-difference indices set)))))

(defun freudenthal-refinement (n)
  "Returns all sub-simplices resulting from regular refinement of an
n-dimensional simplex by Freudenthal's algorithm.  The simplices are
given by their corners in barycentric coordinates (multiplied by 2 to
work with integer coordinates).
Example: (freudenthal-refinement 1) -> ((#(2 0) #(1 1)) (#(1 1) #(0 2)))"
  (let* ((n+1 (1+ n))
	 (positions (make-array (list n+1 n+1))))
    ;; Remark: we will use only one half (i<=j) of the positions-array to
    ;; allow maximal identification of objects.
    (loop for i upto n do
         (loop for j from i upto n do
              (setf (aref positions i j)
                    (scal 0.5 (m+ (unit-vector n+1 i) (unit-vector n+1 j))))))
    (loop for indices in (two-sorted-parts n)
	  collect
	  (let ((index-vector (permutation-shifted-inverse
			       (coerce (apply #'append indices) 'fixnum-vec)))
		(vi 0)
		(vj (length (car indices))))
	    (cons (aref positions vi vj)
		  (loop for l from 0 below n do
			(cond ((= vi (1- (aref index-vector l)))
			       (setq vi (aref index-vector l)))
			      ((= vj (1- (aref index-vector l)))
			       (setq vj (aref index-vector l)))
			      (t (error "something wrong in algorithm")))
			(if (> vi vj) (rotatef vi vj))
			collect (aref positions vi vj)))))))

(defun sub-cells-of-child (child-corners)
  (loop for i from 1 upto (length child-corners)
	collect (k-subsets child-corners i)))

(defun sub-cells-of-children (n)
  (loop with refinement = (make-list (1+ n))
	for child in (freudenthal-refinement n) do
	(setq refinement
	      (mapcar #'(lambda (set1 set2)
			  (ordered-union set1 set2 :test #'equalp))
		      refinement (sub-cells-of-child child)))
	finally (return refinement)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Generation of corresponding refinement rules
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      
(defun get-path-create (simplex corners-of-sub-simplex path &optional create)
  "Returns the path (see the description in the definition of <child-info>) to
the sub-simplex given by its corners in barycentric coordinates.  Additionally,
if the sub-simplex cannot be found, it generates a new entry in the refine-info
vector and fills the barycentric-corners field."
  ;; if possible descend to a boundary
  (loop for side across (boundary simplex)
	and comp from 0
	when (every #'(lambda (vec) (zerop (aref vec comp)))
		    corners-of-sub-simplex)
	return (get-path-create
		side
		(mapcar #'(lambda (vec) (vector-cut vec comp))
			corners-of-sub-simplex)
		(cons comp path) create)
	finally  ; otherwise, search in the refine-info field
	(return
	  (loop for corners across (refine-info simplex)
		and i from 0
		when (equalp (car (child-barycentric-corners corners))
			     corners-of-sub-simplex)
		return (nreverse (cons i path))
		finally  ; the child was not found: create an appropriate entry
		(assert create)
		(return
		  (let ((refine-info (refine-info simplex)))
		    (setq refine-info
			  (adjust-array refine-info (1+ (length refine-info))
					:initial-element
					(make-<child-info>
					 :reference-cell
					 (ensure-simplex (1- (length corners-of-sub-simplex)))
					 :barycentric-corners (list corners-of-sub-simplex)
					 :boundary-paths nil)))
		    ;; return reversed path
		    (nreverse (cons i path))))))))

(defun create-boundary-paths (simplex)
  "Create the boundary-paths for the <child-info> entry in the refine-info
vector.  We assume that the ordering of the simplex boundaries is opposite to
the ordering of the corners."
  (loop for child across (refine-info simplex) do
	(setf (child-boundary-paths child)
	      (let ((child-corners (car (child-barycentric-corners child))))
		(if (single? child-corners)
		    '()
		    (mapcar #'(lambda (corner)
				(get-path-create
				 simplex (remove corner child-corners :test #'equalp) '() t))
			    child-corners))))))

(defmethod generate-refine-info ((refcell <simplex>))
  "Allocates an empty vector of children which is then filled calling
GET-PATH-CREATE and CREATE-BOUNDARY-PATHS."
  (with-cell-information (refine-info)
    refcell
    (setq refine-info (make-array 0 :adjustable t))
    ;; fill refine-info with barycentric corners
    (loop for subcells-of-dim in (sub-cells-of-children (dimension refcell)) do
	  (loop for corners-of-sub-simplex in subcells-of-dim do
		(get-path-create refcell corners-of-sub-simplex '() t)))
    ;; ...and from there the boundary paths
  (create-boundary-paths refcell)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; simplex class definition/generation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun simplex-corner (dim i)
  "Creates the i-th corner of a simplex of dimension dim.  The 0-th corner is
the zero-vector.  The others are equal to (unit-vector dim 1-i)."
  (if (zerop i)
      (make-double-vec dim)
      (unit-vector dim (1- i))))

(defun make-reference-simplex (dim)
  "Constructs a reference simplex of the given dimension."
  (let ((corners (loop for i from 0 upto dim
		       collect (make-vertex (simplex-corner dim i))))
	(simplex-ht (make-hash-table :test #'equalp)))
    ;; intern the corners
    (loop for corner in corners do
	  (setf (gethash (list corner) simplex-ht) corner))
    ;; then intern the other cells
    (loop for subset in (k->l-subsets corners 2 (1+ dim)) do
	  (setf (gethash subset simplex-ht)
		(make-instance
		 (simplex-class (1- (length subset)))
		 :boundary (coerce (loop for corner in subset collecting
					 (gethash (remove corner subset :test #'equalp)
						  simplex-ht))
				   'cell-vec))))
    ;; the entry for corners is the desired simplex
    (gethash corners simplex-ht)))

(defun simplex-class (dim &optional mapped distorted)
  "Returns the n-simplex class."
  (let* ((class-name (intern (format nil "<~D-SIMPLEX>" dim) "FL.MESH"))
	 (class (find-class class-name nil)))
    (cond (class (if mapped (mapped-cell-class class distorted) class))
	  (t
	   (prog1
	       (eval `(defclass ,class-name (<simplex> <standard-cell>)
                        (,+per-class-allocation-slot+)))
	     (let ((refcell (make-reference-simplex dim)))
	       (initialize-cell-class refcell (list refcell))))))))

(defun ensure-simplex (dim)
  "Returns the reference simplex of the given dimension."
  (if (zerop dim)
      *reference-vertex*
      (reference-cell (simplex-class dim))))

(defun n-simplex (dim)
  "Returns the reference simplex of the given dimension."
  (ensure-simplex dim))

;;; access to commonly used simplices - this is also a check for consistency
(defparameter *unit-interval* (ensure-simplex 1))
(defparameter *unit-triangle* (ensure-simplex 2))
(defparameter *unit-tetrahedron* (ensure-simplex 3))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Mesh construction
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun make-simplex (boundary &key (check t) mapping)
  "Short form of creating a simplex given its boundary.  An alternative is
creating it from its vertices, see the functions MAKE-CELL-FROM-VERTICES
and INSERT-CELL-FROM-CORNERS."
  (let ((dim (1- (length boundary))))
    (when check
      (unless (apply #'= (1- dim) (map 'list #'dimension boundary))
	(error "Dimension of boundary cells does not fit."))
      (unless (or (= dim 1) (closed? (skeleton boundary)))
	(error "Boundary is not closed.")))
    (lret ((simplex
             (if mapping
                 (make-instance (simplex-class dim mapping)
                                :boundary (coerce boundary 'cell-vec)
                                :mapping mapping)
                 (make-instance (simplex-class dim)
                                :boundary (coerce boundary 'cell-vec)))))
      (when check (check simplex)))))

(defun make-line (from-vtx to-vtx &key (check t) mapping)
  "Creates a line given its endpoints."
  (make-simplex (vector to-vtx from-vtx) :check check :mapping mapping))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Tests
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-suite mesh-suite)

(test simplex
  (is (= 3 (length (refine-info *unit-interval*))))
  (is (= 7 (length (refine-info *unit-triangle*))))
  (is (= 7 (length (subcells *unit-triangle*))))
  (is-true (eq (reference-cell *unit-interval*)
               (reference-cell (n-simplex 1))))
  (is (equalp #(0.5 0.5) (l2g *unit-triangle* #(0.5 0.5))))
  (is (equalp #(0.5 0.5) (local->global *unit-triangle* #(0.5 0.5))))
  (is (= 3 (dimension *unit-tetrahedron*)))
  (is (= 5 (dimension (n-simplex 5))))

  (finishes
    (describe *unit-triangle*)
    (loop for x across (boundary *unit-triangle*) do
      (describe x))
    (cell-class-information *unit-triangle*)
    (describe (skeleton *unit-triangle*))
    (describe (refcell-refinement-skeleton *unit-triangle* 1))
    (refcell-refinement-skeleton *unit-triangle* 2)
    (mapcar #'corners
            (cells-of-highest-dim
             (refcell-refinement-skeleton *unit-triangle* 1)))
    (let ((bc (euclidean->barycentric #(0.5 0.5)))
          (corners (corners *unit-triangle*)))
      (mapc #'scal (coerce bc 'list) corners))
    (describe (refine (skeleton *unit-tetrahedron*)))
    )
  )
