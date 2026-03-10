-------------------------------- MODULE Add1 --------------------------------

(* Important note: We should set to OFF in                                 *)
(*                                                                         *)
(* > Model Overview > What to check?                                       *)
(*   > Deadlock                                                            *)
(*                                                                         *)
(* It means, that we don't expect model to be in "terminating" state.      *)
EXTENDS Integers

(* i - Number.                                                             *)
(* pc - Program counter (state).                                           *)
VARIABLES i, pc

Init == pc = "start"
     /\ i = 0

Pick == pc = "start"
     /\ i' \in 0..1000
     /\ pc' = "middle"
 
Add1 == pc = "middle"
     /\ i' = i + 1
     /\ pc' = "done"

Next == Pick
     \/ Add1

THEOREM Spec => []Init
=============================================================================
\* Modification History
\* Last modified Tue Jan 30 23:51:09 CET 2024 by fuck
\* Created Tue Jan 30 22:42:38 CET 2024 by fuck
