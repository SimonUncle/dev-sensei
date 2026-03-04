# test-struggle-gate

Tests for the struggle-gate skill.
The skill should intercept error/debugging requests and respond with
Socratic questions instead of direct answers.

---

## Should TRIGGER (error/debugging requests -- respond with questions, not answers)

| #  | Query                                                  | Expected |
|----|--------------------------------------------------------|----------|
| 1  | TypeError: Cannot read property 'id' of undefined      | TRIGGER  |
| 2  | 왜 500 에러가 나요?                                     | TRIGGER  |
| 3  | 이 에러 고쳐줘                                          | TRIGGER  |
| 4  | null pointer exception 어떻게 고쳐                      | TRIGGER  |
| 5  | API가 자꾸 실패해요                                     | TRIGGER  |
| 6  | undefined 나오는데 왜 그런 거예요?                       | TRIGGER  |
| 7  | 로그인이 안 돼요                                        | TRIGGER  |
| 8  | crashed and I don't know why                           | TRIGGER  |
| 9  | this is broken please fix                              | TRIGGER  |
| 10 | 왜 안 되는지 모르겠어요                                  | TRIGGER  |

### Trigger Validation Criteria

When triggered, the response MUST:
- [ ] NOT contain a direct fix or code solution
- [ ] Ask at least 2 diagnostic questions
- [ ] Guide the developer to identify the root cause themselves
- [ ] Include a hint about what to investigate (logs, types, state)

---

## Should NOT TRIGGER (feature requests, general tasks -- respond normally)

| #  | Query                                                  | Expected     |
|----|--------------------------------------------------------|--------------|
| 1  | 로그인 기능 만들어줘                                     | NO TRIGGER   |
| 2  | 이 함수 리팩토링해줘                                     | NO TRIGGER   |
| 3  | 코드 리뷰해줘                                           | NO TRIGGER   |
| 4  | JWT 인증 구현 방법이 뭐야                                | NO TRIGGER   |
| 5  | 성능 최적화하고 싶어                                     | NO TRIGGER   |
| 6  | 테스트 코드 짜줘                                        | NO TRIGGER   |
| 7  | DB 스키마 설계해줘                                       | NO TRIGGER   |
| 8  | 이 API 문서 작성해줘                                     | NO TRIGGER   |
| 9  | 배포 방법 알려줘                                        | NO TRIGGER   |
| 10 | git flow 설명해줘                                       | NO TRIGGER   |

### No-Trigger Validation Criteria

When NOT triggered, the response MUST:
- [ ] Provide a direct, helpful answer to the request
- [ ] NOT inject Socratic debugging questions
- [ ] Proceed with the task as a normal assistant would
