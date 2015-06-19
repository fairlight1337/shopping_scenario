;;; Copyright (c) 2015, Jan Winkler <winkler@cs.uni-bremen.de>
;;; All rights reserved.
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions are met:
;;;
;;; * Redistributions of source code must retain the above copyright
;;; notice, this list of conditions and the following disclaimer.
;;; * Redistributions in binary form must reproduce the above copyright
;;; notice, this list of conditions and the following disclaimer in the
;;; documentation and/or other materials provided with the distribution.
;;; * Neither the name of the Institute for Artificial Intelligence/
;;; Universitaet Bremen nor the names of its contributors may be used to 
;;; endorse or promote products derived from this software without specific 
;;; prior written permission.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
;;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;;; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
;;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;;; POSSIBILITY OF SUCH DAMAGE.

(in-package :shopping-scenario-executive)

(declare-goal rack-scene-perceived (rack)
  "Triggers a scene perception action. This means that the robot backs off from the rack, goes into a suitable pose for looking at it, and looks at each rack level individually. All objects being perceived are automatically asserted into a) the belief state (bullet world), and b) the collision environment."
  (declare (ignore rack))
  (roslisp:ros-info (shopping plans) "SCENE-PERCEIVED"))

(def-goal (achieve (rack-scene-perceived ?rack))
  ;; Iterate through all rack levels and add their contents to the
  ;; collision environment.
  (go-in-front-of-rack ?rack)
  (loop for level in (get-rack-levels ?rack)
        as pose = (get-rack-level-relative-pose
                   level 0 0 0
                   (cl-transforms:euler->quaternion))
        do (achieve `(cram-plan-library:looking-at ,pose))
           (with-designators ((generic-object (object `())))
             (perceive-all
              generic-object :stationary t :move-head nil))))

(declare-goal object-picked-from-rack (rack object)
  "Picks an object `object' from a given rack instance `rack'."
  (declare (ignore rack object))
  (roslisp:ros-info (shopping plans) "OBJECT-PICKED-FROM-RACK"))

(def-goal (achieve (object-picked-from-rack ?rack ?object))
  "Repositions the robot's torso in order to be able to properly reach the rack level the object is residing on, and start picking up the object, repositioning and reperceiving as necessary."
  (let* ((rack-level (get-object-rack-level
                      ?rack (desig-prop-value ?object 'name)))
         (elevation (get-rack-level-elevation rack-level)))
    ;; NOTE(winkler): Reposition robot torso according to rack level
    ;; height. This is a heuristic transformation which maps the
    ;; absolute height of thelowest and highest rack level to the
    ;; lower and upper boundaries of the torso position.
    (move-torso-up (/ elevation 5.0))
    ;; Actually pick the object. This will trigger re-perception and
    ;; navigation in order to properly grasp the object, lift it, and
    ;; move into a safe carrying pose.
    (pick-object ?object)))

(declare-goal objects-detected-in-rack (rack object-template)
  "Tries to detect objects in the given rack `rack', according to the description of the object template given as `object-template'."
  (declare (ignore rack object-template))
  (roslisp:ros-info (shopping plans) "OBJECTS-DETECTED-IN-RACK"))

(def-goal (achieve (objects-detected-in-rack ?rack ?object-template))
  (declare (ignore ?rack))
  (let* ((type (desig-prop-value ?object-template 'type))
         (name (desig-prop-value ?object-template 'name))
         (at (desig-prop-value ?object-template 'at))
         (pose (when at (desig-prop-value at 'pose))))
    (declare (ignore type name pose))
    ;; TODO(winkler): Extend this such that it makes use of the above
    ;; properties, and reflects the respectiv behavior.
    (perceive-all ?object-template)))
