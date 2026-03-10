--------------------------- MODULE AsyncInterface ---------------------------

(***************************************************************************)
(* This is default handshake protocol specification.                       *)
(*                                                                         *)
(* Sender sends protocol message (val), message that is ready (rdy)        *)
(* and must wait for an acknowledgement (ack) from a receiver.             *)
(*                                                                         *)
(* val and rdy changing during one step.                                   *)
(***************************************************************************)

(***************************************************************************)
(* We use substraction operator - for numbers, so include it.              *)
(***************************************************************************)
EXTENDS Naturals

(***************************************************************************)
(* We define some constant variable (without value?)                       *)
(*                                                                         *)
(* Note, that                                                              *)
(*   CONSTANT, CONSTANTS are synonymous,                                   *)
(*   VARIABLE, VARIABLES are synonymous.                                   *)
(***************************************************************************)
CONSTANT Data
(***************************************************************************)
(* This is our protocol messages.                                          *)
(***************************************************************************)
VARIABLES
    val,
    rdy,
    ack

TypeInvariant == /\ val \in Data
                 /\ rdy \in { 0, 1 }
                 /\ ack \in { 0, 1 }

Init == /\ val \in Data
        /\ rdy \in { 0, 1 }
        /\ ack = rdy

(***************************************************************************)
(* As a step our system receives or sends message.                         *)
(*                                                                         *)
(* Send state enabled iff rdy == ack.                                      *)
(*                                                                         *)
(* Receive state enabled iff rdy is different from ack.                    *)
(***************************************************************************)
Send == /\ rdy = ack
        /\ val' \in Data
        /\ rdy' = 1 - rdy
        /\ UNCHANGED << ack, val >>

Rcv == /\ rdy /= ack
       /\ ack' = 1 - ack
       /\ UNCHANGED << val, rdy >>

Next == Send \/ Rcv

(***************************************************************************)
(* All things placed between << and >> is a tuple.                         *)
(*                                                                         *)
(* <<val, rdy, ack>> means that specification allows to left all           *)
(* variables unchanged (stuttering state).                                 *)
(***************************************************************************)
Spec == Init /\ [][Next]_<<val, rdy, ack>>

-----------------------------------------------------------------------------

(***************************************************************************)
(* We state that TypeInvariant will be evaluated to true.                  *)
(***************************************************************************)
THEOREM Spec => [] TypeInvariant

=============================================================================
\* Continue from 3.2 Another specification
\* Modification History
\* Last modified Sun Jan 28 15:13:20 CET 2024 by fuck
\* Created Fri Jan 19 18:57:32 CET 2024 by fuck
