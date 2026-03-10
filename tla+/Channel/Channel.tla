--------------------------- MODULE Channel ---------------------------

EXTENDS Naturals

CONSTANT Data

VARIABLE channel

(********************************************************************)
(* [] notation denotes a record. Basically it is a collection       *)
(* of different values.                                             *)
(*                                                                  *)
(* Notice that order of fields doesn't matter. Identical ones:      *)
(*                                                                  *)
(* [val : Data, rdy : {0, 1}, ack : {0, 1}]                         *)
(* [rdy : {0, 1}, val : Data, ack : {0, 1}]                         *)
(*                                                                  *)
(* Access: for record r we access val with r.val                    *)
(********************************************************************)
TypeInvariant == channel \in [val : Data, rdy : {0, 1}, ack : {0, 1}]

----------------------------------------------------------------------

Init ==
  /\ TypeInvariant
  /\ channel.ack = channel.rdy

(********************************************************************)
(* Alternatively, we can denote value of channel' as                *)
(*                                                                  *)
(* channel' = [val |-> d, rdy |-> 1 - channel.rdy, ack |->          *)
(*                                                    channel.ack ] *)
(*                                                                  *)
(* @ means previous value of the field. !.rdy = 1 - @ means         *)
(* 1 minus previous rdy.                                            *)
(********************************************************************)
Send(d) ==
  /\ channel.rdy = channel.ack
  /\ channel' = [ channel EXCEPT !.val = d, !.rdy = 1 - @ ]

Rcv ==
  /\ channel.rdy /= channel.ack
  /\ channel' = [ channel EXCEPT !.ack = 1 - @ ]

Next == (\E d \in Data : Send(d)) \/ Rcv

(********************************************************************)
(* Notice that definitions (denoted with x == ...) can be freely    *)
(* be replaced with its body. Example below works fine.             *)
(*                                                                  *)
(* Spec == Init /\ [][(\E d \in Data : Send(d)) \/ Rcv]_<<channel>> *)
(********************************************************************)
Spec == Init /\ [][Next]_<<channel>>

----------------------------------------------------------------------

THEOREM Spec => []TypeInvariant

======================================================================
