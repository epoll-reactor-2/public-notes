------------------------------ MODULE TwoProcessors ------------------------------
EXTENDS Integers, Sequences

VARIABLES msg, buffer1, buffer2

Init == /\ msg = <<>>
        /\ buffer1 = <<>>
        /\ buffer2 = <<>>

Send(p, m) == (* Отправка сообщения p процессом m *)
              /\ IF p = 1 THEN buffer1' = Append(buffer1, m)
                          ELSE buffer2' = Append(buffer2, m)

Receive(p) == (* Получение сообщения процессом p *)
              /\ IF p = 1 /\ Len(buffer2) > 0
                 THEN /\ buffer1' = Tail(buffer1)
                      /\ buffer2' = Tail(buffer2)
                 ELSE IF p = 2 /\ Len(buffer1) > 0
                 THEN /\ buffer2' = Tail(buffer2)
                      /\ buffer1' = Tail(buffer1)
                 ELSE TRUE

Next == (* Переходы состояний *)
        \/ \E m \in 1..100: Send(1, m) /\ Receive(2)
        \/ \E m \in 1..100: Send(2, m) /\ Receive(1)

Spec == Init /\ [][Next]_<<msg, buffer1, buffer2>>

===============================================================================