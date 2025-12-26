# 풀이

flashLoan 수수료가 1이더로 고정되어 있고 전송자의 nonce 값이 2 이하여야 한다. 이를 우회하기 위해 주어진 Multicall을 이용해 메타 트랜잭션을 보낸다. flashLoan volume을 0으로 두고 receiver를 FlashLoanReceiver로 지정한 뒤, Receiver가 가진 10이더와 Pool이 가진 1000이더를 모두 탈취하려면 loan을 10번 반복해 수수료 10이더를 pool로 보내면 된다.

이후 pool 보유 총액이 1010이더가 된다. _msgSender는 msg.data 하위 20바이트를 주소로 읽어 입출금에 사용한다. forwarder의 하위 20바이트를 빼돌릴 주소로 바꿔치면 자금 탈취가 가능하고, withdraw로 recovery로 송금하면 완료된다.
