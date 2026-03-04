# test-why-mode

Tests for the /why-mode skill.
When activated, responses MUST use the structured tradeoff format
explaining WHY a particular approach was chosen and what alternatives exist.

---

## Test Queries

| #  | Query                                                          |
|----|----------------------------------------------------------------|
| 1  | /why React 대신 Vue를 쓰면 어때?                                |
| 2  | /why REST 대신 GraphQL 써야 하나?                                |
| 3  | /why 모노리스 대신 마이크로서비스를 선택해야 하나요?               |
| 4  | /why SQL vs NoSQL 어떤 걸 써야 해?                               |
| 5  | /why JWT 대신 세션 기반 인증 쓰면 안 돼?                          |
| 6  | /why TypeScript를 꼭 써야 하나요?                                |
| 7  | /why Redis를 캐시로 쓰는 이유가 뭐야?                            |
| 8  | /why Docker 대신 그냥 VM 쓰면 안 돼?                             |
| 9  | /why 왜 함수형 프로그래밍이 좋다고 하는 거야?                      |
| 10 | /why CSR vs SSR 어떤 게 나아?                                    |

---

## Response Format Validation

Every /why-mode response MUST contain these sections:

### Required Structure

```
## Approach: [선택지 A]
- 장점: ...
- 단점: ...
- 적합한 상황: ...

## Approach: [선택지 B]
- 장점: ...
- 단점: ...
- 적합한 상황: ...

## Tradeoff Summary
- 핵심 트레이드오프: ...
- 추천 기준: ...

## Question for You
- (개발자가 스스로 판단할 수 있게 유도하는 질문)
```

### Checklist

For each test query, verify:
- [ ] At least 2 approaches are compared
- [ ] Each approach lists pros, cons, and suitable scenarios
- [ ] A tradeoff summary is provided
- [ ] Ends with a reflective question back to the developer
- [ ] Does NOT say "just use X" without explaining why
- [ ] Korean and English terms are both acceptable
