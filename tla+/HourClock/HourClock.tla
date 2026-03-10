----------------------------- MODULE HourClock -----------------------------

(**************************************************************************)
(* Note, that in order to have boxed comment, we must to put in a         *)
(* "box" at the top and the bottom of comment. This looks like            *)
(*                                                                        *)
(* ( ***************************************************************** )  *)
(* ( * Contents ...                                                       *)
(* ( ***************************************************************** )  *)
(**************************************************************************)

(**************************************************************************)
(* This is PlusCal pseudocode algorithm, from which we can generate       *)
(* TLA+ specification. But I wrote manually.                              *)
(*                                                                        *)
(* How to run:                                                            *)
(* 1.   Write | generate proper TLA+.                                     *)
(* 2.   |_ TLC Model Checker                                              *)
(*      |___ New Model                                                    *)
(* 2.5. Optionally set invariants in Model Overview menu.                 *)
(* 3.   Run model. If there checker detects no errors, all good. If there *)
(*      are errors, it will show trace of it.                             *)
(**************************************************************************)

(**************************************************************************
--algorithm HourClock {
    variables hr \in 1..12; {
        while (TRUE) {
            hr := hr + 1
        }
    }
}
 **************************************************************************)

(**************************************************************************)
(* By default, arithmetic operations like + - * / are not defined. We may *)
(* wish to define + as matrix sum, not as numbers sum, and so on.         *)
(**************************************************************************)
EXTENDS Naturals
(**************************************************************************)
(* Variable. This is where hour is stored.                                *)
(**************************************************************************)
VARIABLE hr
(**************************************************************************)
(* Predicate, that tells us about                                         *)
(* the fact that variable hr takes values                                 *)
(* from 1 to 12.                                                          *)
(**************************************************************************)
Init == hr \in (1 .. 12)
(**************************************************************************)
(* Formula (step) that express relation between                           *)
(* value of hr and its successor in the old                               *)
(* state of a step. We want to satisfy initial state Init                 *)
(* and each next step Next.                                               *)
(* IF Next step occurs, we say what Next is executed.                     *)
(*                                                                        *)
(* hr represents value in the old state,                                  *)
(* hr' represents value in the new state.                                 *)
(*                                                                        *)
(* If we add condition \/ hr' = hr, this would mean                       *)
(* that during a step hour can be left unchanged (stuttering step).       *)
(**************************************************************************)
Next == hr' = IF hr # 12 THEN hr + 1 ELSE 1
HC == Init /\ [][Next]_hr
(**************************************************************************)
(* This line is purely cosmetic and has no meaning.                       *)
(**************************************************************************)
----------------------------------------------------------------------------
(**************************************************************************)
(* White square (or its ASCII analog) indicates, that                     *)
(* Init is always true. This is our theorem.                              *)
(**************************************************************************)
THEOREM HC => []Init

============================================================================
\* Continue from Chapter 3 An Asynchronous Interface.
\*
\* Modification History
\* Last modified Tue Sep 09 20:46:31 CEST 2025 by fuck
\* Created Thu Jan 18 19:49:05 CET 2024 by fuck
