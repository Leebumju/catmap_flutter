#!/usr/bin/env bash
# 목격 피드를 실제 서버에 붙여 실행한다. 기기는 iOS / 안드로이드 모두 된다.
set -euo pipefail

source "$(dirname "$0")/secrets.sh"

exec flutter run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=KAKAO_REST_API_KEY="$KAKAO_REST_API_KEY" \
  "$@"
