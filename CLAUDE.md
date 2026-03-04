# dev-sensei 프로젝트

## 컨텍스트
- Claude Code 플러그인 개발
- 멀티플랫폼: Claude Code + Codex 지원
- MIT 오픈소스, GitHub 공개 예정
- LinkedIn 제작자 포스팅 목표

## 코드 컨벤션
- 쉘스크립트: bash, POSIX 호환
- SKILL.md: 500줄 이하
- description 필드: 영어, 공격적으로 작성 (undertrigger 방지)
- references/: 실제 내용만, 플레이스홀더 없음

## 파일 구조
dev-sensei/
├── .claude-plugin/plugin.json
├── skills/
│   ├── struggle-gate/SKILL.md
│   ├── why-mode/SKILL.md
│   ├── pattern-recognizer/SKILL.md
│   └── incident-mentor/SKILL.md + references/
├── hooks/hooks.json + ship-gate.sh
├── tests/
└── README.md

## 우선순위
1. 동작하는 것 > 완벽한 것
2. 실제 내용 > 플레이스홀더
3. 영어 README 필수 (글로벌 오픈소스)
