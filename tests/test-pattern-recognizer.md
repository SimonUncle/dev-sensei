# test-pattern-recognizer

Tests for the pattern-recognizer skill.
The skill should detect recurring anti-patterns or bad habits in code
and surface them proactively with educational context.

---

## Should TRIGGER (code contains recognizable anti-patterns)

| #  | Query / Code Snippet                                                     | Pattern            | Expected |
|----|--------------------------------------------------------------------------|--------------------|----------|
| 1  | `try { ... } catch(e) { console.log(e) }` 이거 맞아?                     | Silent catch        | TRIGGER  |
| 2  | `SELECT * FROM users WHERE id = '${userId}'`                             | SQL injection       | TRIGGER  |
| 3  | 매번 API 호출할 때마다 `new HttpClient()` 만드는데 괜찮아?                  | Resource leak       | TRIGGER  |
| 4  | `if (x == null) { ... } else if (x == undefined) { ... }`               | Redundant null check| TRIGGER  |
| 5  | 함수 하나가 300줄인데 리뷰해줘                                             | God function        | TRIGGER  |
| 6  | `let data = JSON.parse(response)` 에러 처리 없이 쓰고 있어                 | Unhandled parse     | TRIGGER  |
| 7  | 모든 API 응답을 `any` 타입으로 받고 있어                                    | Type avoidance      | TRIGGER  |
| 8  | `setTimeout(() => retry(), 1000)` 으로 재시도 로직 만들었어                  | Naive retry         | TRIGGER  |
| 9  | `.env` 파일에 API key 넣고 git에 커밋했는데 괜찮아?                         | Secret exposure     | TRIGGER  |
| 10 | 모든 에러를 `return res.status(500).send('Error')` 로 처리 중               | Generic error       | TRIGGER  |

### Trigger Validation Criteria

When triggered, the response MUST:
- [ ] Name the specific anti-pattern detected
- [ ] Explain WHY it is problematic (real-world consequences)
- [ ] Show the improved version or approach
- [ ] Ask if the developer has seen this pattern cause issues before

---

## Should NOT TRIGGER (clean code or general questions)

| #  | Query                                                                    | Expected     |
|----|--------------------------------------------------------------------------|--------------|
| 1  | 이 코드 잘 짰는데 더 개선할 점 있어?  (clean, well-structured code)         | NO TRIGGER   |
| 2  | 디자인 패턴 종류 알려줘                                                    | NO TRIGGER   |
| 3  | async/await 문법 설명해줘                                                 | NO TRIGGER   |
| 4  | 프로젝트 구조 추천해줘                                                     | NO TRIGGER   |
| 5  | CI/CD 파이프라인 만들어줘                                                  | NO TRIGGER   |

### No-Trigger Validation Criteria

When NOT triggered, the response MUST:
- [ ] Answer the question directly without anti-pattern warnings
- [ ] Not insert unsolicited pattern lectures
- [ ] Remain helpful and focused on the actual request
