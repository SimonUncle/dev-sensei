#!/bin/bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎋 dev-sensei — SHIP GATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "커밋 전 3가지 답해야 합니다."
echo "이해하고 커밋하는 습관이 시니어를 만듭니다."
echo ""

read -r -p "1️⃣  왜 이 접근법을 선택했어요? (다른 방법도 있었나요?) > " answer1
read -r -p "2️⃣  이 코드의 가장 큰 약점이 뭔지 알아요? > " answer2
read -r -p "3️⃣  트래픽/데이터 10배 되면 이 코드 버텨요? > " answer3

if [ -z "$answer1" ] || [ -z "$answer2" ] || [ -z "$answer3" ]; then
  echo ""
  echo "❌ 답변 없이 커밋 불가합니다"
  echo "   코드를 이해한 후 다시 시도해주세요"
  exit 1
fi

echo ""
echo "✅ Good. Ship it."
echo ""
echo "sensei-review:"
echo "  why: $answer1"
echo "  weakness: $answer2"
echo "  scale: $answer3"
exit 0
