;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; utilities-defp.lisp
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


(defpackage "FL.UTILITIES"
  (:use "COMMON-LISP" "FL.MACROS" "FL.DEBUG")
  (:export  ; utilities.lisp
   "REQUIRED-ARGUMENT" "XOR" "FACTORIAL" "SQUARE"
   "EVALUATE" "COMPOSE" "COMPOSE-2" "CURRY" "RCURRY" "SANS"
   "VECTOR-MAP"
   "BOX" "UNBOX"
   "FOR-EACH" "PARTIAL-SUMS" "MAPF"
   "POSITIVE-FIXNUM" "FIXNUM-VEC" "MAKE-FIXNUM-VEC" "*EMPTY-FIXNUM-VEC*"
   "VECTOR-CUT" "VECTOR-LAST" "CONSTANT-VECTOR" "ZERO-VECTOR"
   "FOR-EACH-TUPLE" "DOTUPLE" "ARRAY-FOR-EACH"
   "MAKE_LIST" "SINGLE?" "FLATTEN" "FLATTEN-1"
   "SAME-P" "RANGE<=" "RANGE<" "SPLIT-BY-LENGTH" "MODIFY"
   "THRICE" "TWICE"
   "MAP-PRODUCT" "MAPPEND" "MKLIST"
   "TREE-UNIFORM-NUMBER-OF-BRANCHES" "TREE-UNIFORMP"
   "ON-LEAVES" "FIND-LEAF-IF" "FIND-LEAF" "MAP-TREE"
   "CHECK-PROPERTIES"
   "QUEUE" "ENQUEUE" "DEQUEUE" "EMPTYP" "FINISH"
   "QUEUE->LIST" "LIST->QUEUE" "DEQUEUE-ALL"
   "MAKE-DLL" "DLL" "DLL-ITEM" "DLI-OBJECT" "DLI-SUCC" "DLI-PRED"
   "DLL-FRONT-INSERT" "DLL-REAR-INSERT" "DLL-REMOVE-ITEM" "DLL-FIND"
   "DLL-REMOVE"
   "DLL-POP-FIRST" "DLL-POP-LAST"
   "DLL->LIST" "LIST->DLL" "DLL-EMPTY-P"
   "CD-LIST" "PUSH-FRONT" "POP-FRONT" "POP-REAR" "DELETE-FROM"
   "DOHASH" "MAP-HASH-TABLE" "COPY-HASH-TABLE" "GET-ARBITRARY-KEY-FROM-HASH-TABLE"
   "DISPLAY-HT" "HASH-TABLE-KEYS" "HASH-TABLE-VALUES" "COLLECT-IN-HASH-TABLE"
   "RANGE" "LOOP+" "ITERATOR" "ITERATOR-END-P" "ITERATOR-NEXT" "REFERENCE"
   "MEMOIZE-1" "MEMOIZE-SYMBOL"
   "GETA" "BLACKBOARD" "GETBB" "WITH-ITEMS" "TRANSFER-BB"
   "SET-P" "MAXIMALLY-CONNECTED"
   "ORDERED-SET-DIFFERENCE" "ORDERED-INTERSECTION" "ORDERED-UNION"
   "K-SUBSETS" "K->L-SUBSETS" "SUBSETS" "NONEMPTY-SUBSETS"
   "N-PARTITIONS-OF-K" "POSITIVE-N-PARTITIONS-OF-K" "POSITIVE-PARTITIONS-OF-K"
   "PERMUTATION-P" "IDENTITY-PERMUTATION-P" "PERMUTE" "PERMUTE-INTO"
   "PERMUTATION-INVERSE" "PERMUTATION-SHIFTED-INVERSE" "PERMUTATION-SIGNUM"
   "SAFE-SORT")
  (:export  ; general.lisp
   "MAKE-ANALOG" "FILE-DOCUMENTATION" "CONCEPT-DOCUMENTATION"
   "PROPERTY-MIXIN" "PROPERTIES"
   "GET-PROPERTY"
   "DIC-REF"
   "WITH-MEMOIZATION" "MEMOIZING-LET"
   )
  (:export ; mflop.lisp
   "COMMON-LISP-SPEED")
  (:documentation
   "This package contains generally useful utility functions.  Several of
those functions were taken from @cite{(Graham 1996)}, the SANS function was
contributed to the @cite{comp.lang.lisp} newsgroup by Erik Naggum."))

