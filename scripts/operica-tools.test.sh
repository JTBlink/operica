#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

fail() {
  echo "operica-tools.test.sh: $*" >&2
  exit 1
}

help_output="$(bash scripts/operica-tools.sh help)"

grep -Fq 'start [--server] [--web] [--all]' <<<"$help_output" ||
  fail "start help must list the optional service flags"
grep -Fq '默认仅启动桌面端' <<<"$help_output" ||
  fail "start help must state that desktop is the default"
grep -Fq 'start 参数:' <<<"$help_output" ||
  fail "help must describe start options"
grep -Fq '环境变量:' <<<"$help_output" ||
  fail "help must describe environment variables"
grep -Fq '示例:' <<<"$help_output" || fail "help must include examples"
grep -Fq './scripts/operica-tools.sh start --all' <<<"$help_output" ||
  fail "help must include a complete local development example"
grep -Fq '本地登录提示:' <<<"$help_output" ||
  fail "help must include local sign-in guidance"
grep -Fq '默认账号: 未设置' <<<"$help_output" ||
  fail "help must not imply that a default account always exists"
grep -Fq '默认密码: 无' <<<"$help_output" ||
  fail "help must explain that Opercia has no password login"
grep -Fq 'OPERCIA_DEV_VERIFICATION_CODE' <<<"$help_output" ||
  fail "help must explain how to find the local verification code"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fixture="$tmp_dir/repo"
stub_bin="$tmp_dir/bin"
log_file="$tmp_dir/commands.log"
mkdir -p "$fixture/scripts" "$fixture/server/bin" "$stub_bin"
cp scripts/operica-tools.sh "$fixture/scripts/operica-tools.sh"

cat >"$fixture/.env" <<'EOF'
DATABASE_URL=postgres://test:test@localhost:5432/test
PORT=18080
FRONTEND_PORT=13000
EOF

cat >"$fixture/scripts/local-env.sh" <<'EOF'
export PORT="${PORT:-8080}"
export FRONTEND_PORT="${FRONTEND_PORT:-3000}"
EOF

cat >"$fixture/scripts/ensure-postgres.sh" <<'EOF'
#!/usr/bin/env bash
printf 'ensure-postgres:%s\n' "$*" >>"$TOOLS_TEST_LOG"
EOF

cat >"$stub_bin/pnpm" <<'EOF'
#!/usr/bin/env bash
printf 'pnpm:%s\n' "$*" >>"$TOOLS_TEST_LOG"
EOF

cat >"$stub_bin/go" <<'EOF'
#!/usr/bin/env bash
printf 'go:%s\n' "$*" >>"$TOOLS_TEST_LOG"
output=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    shift
    output="$1"
  fi
  shift
done
if [ -n "$output" ]; then
  mkdir -p "$(dirname "$output")"
  cat >"$output" <<'SCRIPT'
#!/usr/bin/env bash
printf 'binary:%s:%s\n' "$(basename "$0")" "$*" >>"$TOOLS_TEST_LOG"
SCRIPT
  chmod +x "$output"
fi
EOF

chmod +x "$stub_bin/pnpm" "$stub_bin/go"

run_start() {
  : >"$log_file"
  (
    cd "$fixture"
    PATH="$stub_bin:$PATH" TOOLS_TEST_LOG="$log_file" \
      bash scripts/operica-tools.sh start "$@" >/dev/null
  )
}

run_start
grep -Fxq 'pnpm:dev:desktop' "$log_file" ||
  fail "default start must launch Desktop"
[ "$(wc -l <"$log_file" | tr -d ' ')" = "1" ] ||
  fail "default start must not launch optional services"

run_start --web
grep -Fxq 'pnpm:dev:desktop' "$log_file" ||
  fail "--web must retain Desktop"
grep -Fxq 'pnpm:dev:web' "$log_file" || fail "--web must launch Web"
if grep -Fq 'ensure-postgres:' "$log_file" || grep -Fq 'binary:server:' "$log_file"; then
  fail "--web must not launch the backend"
fi

run_start --server
grep -Fxq 'pnpm:dev:desktop' "$log_file" ||
  fail "--server must retain Desktop"
grep -Fxq 'ensure-postgres:.env' "$log_file" ||
  fail "--server must prepare PostgreSQL"
grep -Fxq 'binary:migrate:up' "$log_file" ||
  fail "--server must run migrations"
grep -Fxq 'binary:server:' "$log_file" ||
  fail "--server must launch the backend"
if grep -Fq 'pnpm:dev:web' "$log_file"; then
  fail "--server must not launch Web"
fi

run_start --all
grep -Fxq 'pnpm:dev:desktop' "$log_file" || fail "--all must launch Desktop"
grep -Fxq 'binary:server:' "$log_file" || fail "--all must launch the backend"
grep -Fxq 'pnpm:dev:web' "$log_file" || fail "--all must launch Web"

set +e
(
  cd "$fixture"
  PATH="$stub_bin:$PATH" TOOLS_TEST_LOG="$log_file" \
    bash scripts/operica-tools.sh start --unknown >/dev/null 2>&1
)
invalid_status=$?
set -e
[ "$invalid_status" = "2" ] || fail "unknown start flags must exit 2"

echo "operica-tools.test.sh: PASS"
