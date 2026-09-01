#!/usr/bin/env bash
# 안드로이드 릴리즈 빌드.
#
#   ./build_android.sh            # Play Console 업로드용 AAB (기본)
#   ./build_android.sh apk        # 기기에 직접 넣어볼 APK
#
# Supabase 키는 저장소에 없다. run.sh 와 똑같이 iOS 의 Secrets.swift 에서 꺼내
# --dart-define 으로 넘긴다. 넘기지 않으면 앱은 켜지지만 서버 주소가 빈 문자열이라
# 피드가 뜨지 않는다.
set -euo pipefail

cd "$(dirname "$0")"
source "./secrets.sh"

# 첫 인자가 대상(aab/apk)이면 소비하고, 그 밖의 인자(-v 같은 flutter 옵션)는 그대로 넘긴다.
case "${1:-}" in
  aab|apk) TARGET="$1"; shift ;;
  *) TARGET="aab" ;;
esac

if [ "$TARGET" = "aab" ]; then
  # Play Console 은 디버그 키로 서명된 파일을 거부한다. 여기서 먼저 막아
  # 빌드를 다 돌린 뒤 업로드 단계에서 알게 되는 일을 없앤다.
  if [ ! -f "android/key.properties" ]; then
    echo "android/key.properties 가 없다. 업로드 키 없이 만든 AAB 는 Play Console 이 거부한다." >&2
    echo "android/key.properties.template 를 복사해서 채운 뒤 다시 실행한다." >&2
    exit 1
  fi
  BUILD_ARGS=(appbundle)
else
  BUILD_ARGS=(apk)
fi

flutter build "${BUILD_ARGS[@]}" \
  --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=KAKAO_REST_API_KEY="$KAKAO_REST_API_KEY" \
  "$@"

if [ "${BUILD_ARGS[0]}" = "appbundle" ]; then
  echo
  echo "완료: build/app/outputs/bundle/release/app-release.aab"
else
  echo
  echo "완료: build/app/outputs/flutter-apk/app-release.apk"
fi
