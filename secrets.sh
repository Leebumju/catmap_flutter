# 키를 iOS 프로젝트의 Secrets.swift(=gitignore 대상)에서 읽어 환경변수로 내보낸다.
# 실행·빌드 스크립트가 source 해서 쓴다.
#   SUPABASE_URL / SUPABASE_ANON_KEY  — 서버
#   KAKAO_REST_API_KEY                — 주소·장소 검색(안드로이드에는 MapKit 검색이 없다)
#
# 키를 이 저장소에 복사하지 않는 것이 요점이다. 소스에도, 셸 히스토리에도 안 남는다.

SECRETS="${SECRETS_PATH:-$HOME/Desktop/CatMap/Projects/App/Sources/Secrets.swift}"

if [ ! -f "$SECRETS" ]; then
  echo "Secrets.swift 를 못 찾음: $SECRETS" >&2
  echo "SECRETS_PATH 로 경로를 지정할 수 있다." >&2
  exit 1
fi

_extract() {
  sed -n "s/.*static let $1 *= *\"\([^\"]*\)\".*/\1/p" "$SECRETS" | head -1
}

SUPABASE_URL="$(_extract supabaseURL)"
SUPABASE_ANON_KEY="$(_extract supabaseAnonKey)"
KAKAO_REST_API_KEY="$(_extract kakaoRESTApiKey)"

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "Secrets.swift 에서 supabaseURL / supabaseAnonKey 를 못 읽음" >&2
  exit 1
fi

if [ -z "$KAKAO_REST_API_KEY" ]; then
  # 검색만 안 되고 나머지는 동작한다. 막지 않고 알리기만 한다.
  echo "경고: kakaoRESTApiKey 를 못 읽음 — 주소 검색이 동작하지 않는다." >&2
fi
