# 풀이

- 플래시론 요청 시 `target`과 `data`를 공격자가 마음대로 넣을 수 있다.
- `target`을 토큰 컨트랙트로, `data`를 `approve(attacker, balance)`로 전달하면 풀 주소가 공격자에게 token approve가 가능하다.
- 이어서 동일 트랜잭션에서 `transferFrom`을 호출해 풀의 토큰 전부를 빼내 복구 주소로 옮긴다.
