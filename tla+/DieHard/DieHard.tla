----------------------------- MODULE DieHard -----------------------------

EXTENDS Integers

VARIABLES small, big

TypeOK == /\ small \in 0..3
          /\ big   \in 0..5

Init == /\ big   = 0
        /\ small = 0

FillBig == /\ big' = 5
           /\ small' = small

FillSmall == /\ small' = 3
             /\ big' = big

EmptySmall == /\ small' = 0
              /\ big' = big

EmptyBig == /\ big' = 0
            /\ small' = small

SmallToBig == IF big + small  =< 5
               THEN /\ big'   = big + small
                    /\ small' = 0
               ELSE /\ small' = small - (5 - big)
                    /\ big'   = 5

BigToSmall == IF big + small  =< 3
               THEN /\ big'   = 0
                    /\ small' = big + small
               ELSE /\ big'   = small - (3 - big)
                    /\ small' = 3

Next == \/ FillBig
        \/ FillSmall
        \/ EmptySmall
        \/ EmptyBig
        \/ SmallToBig
        \/ BigToSmall

(* This invariant with help of TLC shows sequences of steps to get 4 gallons
   in big jug.

      1: Init          | big = 0     small = 0
      2: FillBig       | big = 5     small = 0
      3: BigToSmall    | big = 2     small = 3
      4: EmptySmall    | big = 2     small = 0
      5: BigToSmall    | big = 0     small = 2
      6: FillBig       | big = 5     small = 2
      7: BigToSmall    | big = 4     small = 3
*)

InvariantNoFour == big /= 4

Spec == Init /\ [][Next]_<<small, big>>

THEOREM Spec => []TypeOK

==========================================================================
