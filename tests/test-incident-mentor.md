# test-incident-mentor

Tests for the incident-mentor skill.
The skill activates when a developer describes a production-like incident
and guides them through structured root-cause analysis.

5 categories, 5 queries each = 25 total test queries.

---

## Category 1: Cache Incidents

| #  | Query                                                                        | Expected |
|----|------------------------------------------------------------------------------|----------|
| 1  | Redis 캐시가 갑자기 다 날아갔어요. 서비스 응답이 10초 넘어요                       | TRIGGER  |
| 2  | 캐시 히트율이 5%밖에 안 돼요. 의미가 있는 건가요?                                 | TRIGGER  |
| 3  | 캐시 무효화가 안 돼서 사용자한테 옛날 데이터가 보여요                               | TRIGGER  |
| 4  | 핫키 하나 때문에 Redis 노드 하나가 CPU 100% 찍었어요                              | TRIGGER  |
| 5  | 캐시 스탬피드 때문에 DB가 죽을 뻔했어요                                           | TRIGGER  |

### Cache Incident Validation

Response MUST:
- [ ] Ask about cache invalidation strategy
- [ ] Ask about TTL configuration
- [ ] Explore thundering herd / stampede scenarios
- [ ] Guide toward cache-aside vs write-through discussion

---

## Category 2: Database Incidents

| #  | Query                                                                        | Expected |
|----|------------------------------------------------------------------------------|----------|
| 1  | 쿼리가 갑자기 느려졌어요. 어제까지 잘 됐는데                                      | TRIGGER  |
| 2  | 데드락 걸려서 트랜잭션이 전부 롤백됐어요                                          | TRIGGER  |
| 3  | DB 커넥션 풀이 다 차서 새 요청을 못 받아요                                        | TRIGGER  |
| 4  | 리플리카 랙이 30초나 돼서 읽기 데이터가 안 맞아요                                  | TRIGGER  |
| 5  | 마이그레이션 중에 테이블 락 걸려서 서비스 멈췄어요                                  | TRIGGER  |

### Database Incident Validation

Response MUST:
- [ ] Ask about query execution plan (EXPLAIN)
- [ ] Explore index usage and table scan possibility
- [ ] Ask about connection pool sizing and timeout config
- [ ] Guide toward read/write splitting considerations

---

## Category 3: Microservice Incidents

| #  | Query                                                                        | Expected |
|----|------------------------------------------------------------------------------|----------|
| 1  | 서비스 A가 죽으니까 B, C, D까지 연쇄적으로 죽어요                                 | TRIGGER  |
| 2  | 서비스 간 순환 의존성 때문에 배포를 못 해요                                        | TRIGGER  |
| 3  | API 게이트웨이 타임아웃이 자꾸 나요                                               | TRIGGER  |
| 4  | 분산 트랜잭션에서 일부만 성공하고 일부는 실패했어요                                  | TRIGGER  |
| 5  | 서비스 디스커버리가 죽어서 전체 서비스가 서로를 못 찾아요                             | TRIGGER  |

### Microservice Incident Validation

Response MUST:
- [ ] Ask about circuit breaker implementation
- [ ] Explore timeout and retry configuration
- [ ] Ask about fallback strategies
- [ ] Guide toward bulkhead pattern discussion

---

## Category 4: Thread / Concurrency Incidents

| #  | Query                                                                        | Expected |
|----|------------------------------------------------------------------------------|----------|
| 1  | 멀티스레드 환경에서 간헐적으로 데이터가 꼬여요                                     | TRIGGER  |
| 2  | 동시에 같은 리소스를 업데이트하면 마지막 쓰기만 살아남아요                            | TRIGGER  |
| 3  | 스레드 풀이 전부 점유돼서 새 요청 처리가 안 돼요                                    | TRIGGER  |
| 4  | race condition 때문에 결제가 두 번 됐어요                                         | TRIGGER  |
| 5  | async 작업에서 메모리 사용량이 계속 올라가요                                        | TRIGGER  |

### Thread Incident Validation

Response MUST:
- [ ] Ask about synchronization mechanisms (mutex, semaphore, lock)
- [ ] Explore shared state and immutability
- [ ] Ask about thread pool sizing
- [ ] Guide toward optimistic vs pessimistic locking discussion

---

## Category 5: Memory Incidents

| #  | Query                                                                        | Expected |
|----|------------------------------------------------------------------------------|----------|
| 1  | OOM으로 Pod가 계속 재시작돼요                                                    | TRIGGER  |
| 2  | 힙 메모리가 계속 올라가다가 GC가 안 돼요                                           | TRIGGER  |
| 3  | 메모리 릭인 것 같은데 어디서 새는지 모르겠어요                                      | TRIGGER  |
| 4  | 대용량 파일 처리할 때 메모리가 한 번에 치솟아요                                     | TRIGGER  |
| 5  | Node.js에서 버퍼가 계속 쌓여서 서버가 죽어요                                       | TRIGGER  |

### Memory Incident Validation

Response MUST:
- [ ] Ask about memory profiling tools being used
- [ ] Explore object lifecycle and reference management
- [ ] Ask about streaming vs buffering strategies
- [ ] Guide toward heap dump analysis discussion

---

## General Validation (All Categories)

Every incident-mentor response MUST follow this structure:

1. **Acknowledge** the incident severity
2. **Ask 2-3 diagnostic questions** before proposing solutions
3. **Guide root-cause analysis** step by step
4. **Share a real-world lesson** or war story pattern
5. **End with a prevention question**: "How would you prevent this from happening again?"
