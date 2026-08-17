#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

fail() {
  echo "operica-tools.test.sh: $*" >&2
  exit 1
}

help_output="$(bash scripts/operica-tools.sh help)"

legacy_brand="Oper""cia"
if grep -Fq "$legacy_brand" <<<"$help_output"; then
  fail "help must use the Operica product name"
fi
grep -Fq 'Operica 本地开发与发布工具' <<<"$help_output" ||
  fail "help must show the Operica product name"

grep -Fq 'start [--server] [--web] [--all]' <<<"$help_output" ||
  fail "start help must list the optional service flags"
grep -Fq '默认启动桌面端' <<<"$help_output" ||
  fail "start help must state that desktop is the default"
grep -Fq '启动前会先停止当前 checkout 的已有开发进程' <<<"$help_output" ||
  fail "start help must describe automatic cleanup"
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
  fail "help must explain that Operica has no password login"
grep -Fq 'OPERICA_DEV_VERIFICATION_CODE' <<<"$help_output" ||
  fail "help must explain how to find the local verification code"
grep -Fq 'kill [--all]' <<<"$help_output" ||
  fail "help must list the kill command"
grep -Fq '不会停止共享 PostgreSQL' <<<"$help_output" ||
  fail "help must state that kill preserves shared PostgreSQL"

tmp_dir="$(mktemp -d)"
held_launcher_pid=""
stale_renderer_pid=""
backend_fixture_pid=""

cleanup() {
  if [ -n "$stale_renderer_pid" ] && kill -0 "$stale_renderer_pid" 2>/dev/null; then
    kill -TERM "$stale_renderer_pid" 2>/dev/null || true
    wait "$stale_renderer_pid" 2>/dev/null || true
  fi
  if [ -n "$held_launcher_pid" ] && kill -0 "$held_launcher_pid" 2>/dev/null; then
    kill -TERM "$held_launcher_pid" 2>/dev/null || true
    wait "$held_launcher_pid" 2>/dev/null || true
  fi
  if [ -n "$backend_fixture_pid" ] && kill -0 "$backend_fixture_pid" 2>/dev/null; then
    kill -TERM "$backend_fixture_pid" 2>/dev/null || true
    wait "$backend_fixture_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp_dir"
}

trap cleanup EXIT

fixture="$tmp_dir/repo"
stub_bin="$tmp_dir/bin"
log_file="$tmp_dir/commands.log"
mkdir -p "$fixture/scripts" "$fixture/server/bin" "$stub_bin"
cp scripts/operica-tools.sh "$fixture/scripts/operica-tools.sh"

backend_port_file="$tmp_dir/backend.port"
(
  cd "$tmp_dir"
  exec node -e '
    const fs = require("node:fs");
    const http = require("node:http");
    const server = http.createServer((_request, response) => response.end("backend"));
    server.listen(0, "127.0.0.1", () => {
      fs.writeFileSync(process.argv[1], String(server.address().port));
    });
  ' "$backend_port_file"
) &
backend_fixture_pid=$!
for _ in {1..50}; do
  [ -s "$backend_port_file" ] && break
  sleep 0.1
done
[ -s "$backend_port_file" ] || fail "backend fixture did not start"
backend_fixture_port="$(cat "$backend_port_file")"

cat >"$fixture/.env" <<EOF
DATABASE_URL=postgres://test:test@localhost:5432/test
PORT=$backend_fixture_port
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
if [ "${TOOLS_TEST_HOLD:-0}" = "1" ]; then
  trap 'exit 0' INT TERM
  while :; do sleep 1; done
fi
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
if [ "${TOOLS_TEST_HOLD:-0}" = "1" ] && [ "$(basename "$0")" = "server" ]; then
  trap 'exit 0' INT TERM
  while :; do sleep 1; done
fi
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

kill -TERM "$backend_fixture_pid" 2>/dev/null || true
wait "$backend_fixture_pid" 2>/dev/null || true
backend_fixture_pid=""

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

stale_port_file="$tmp_dir/stale-renderer.port"
(
  cd "$fixture"
  exec node -e '
    const fs = require("node:fs");
    const http = require("node:http");
    const server = http.createServer((_request, response) => response.end("stale"));
    process.on("SIGTERM", () => server.close(() => process.exit(0)));
    server.listen(0, "127.0.0.1", () => {
      fs.writeFileSync(process.argv[1], String(server.address().port));
    });
  ' "$stale_port_file" electron-vite
) &
stale_renderer_pid=$!

for _ in {1..50}; do
  [ -s "$stale_port_file" ] && break
  sleep 0.1
done
[ -s "$stale_port_file" ] || fail "stale renderer fixture did not start"
stale_renderer_port="$(cat "$stale_port_file")"

: >"$log_file"
set +e
(
  cd "$fixture"
  PATH="$stub_bin:$PATH" TOOLS_TEST_LOG="$log_file" \
    DESKTOP_RENDERER_PORT="$stale_renderer_port" \
    bash scripts/operica-tools.sh start >/dev/null 2>&1
)
restart_status=$?
set -e
[ "$restart_status" = "0" ] ||
  fail "start must clean stale checkout processes before checking ports"
for _ in {1..50}; do
  kill -0 "$stale_renderer_pid" 2>/dev/null || break
  sleep 0.1
done
if kill -0 "$stale_renderer_pid" 2>/dev/null; then
  fail "start must stop the stale renderer process"
fi
wait "$stale_renderer_pid" 2>/dev/null || true
stale_renderer_pid=""
grep -Fxq 'pnpm:dev:desktop' "$log_file" ||
  fail "start must launch Desktop after cleaning stale processes"

set +e
(
  cd "$fixture"
  PATH="$stub_bin:$PATH" TOOLS_TEST_LOG="$log_file" \
    bash scripts/operica-tools.sh start --unknown >/dev/null 2>&1
)
invalid_status=$?
set -e
[ "$invalid_status" = "2" ] || fail "unknown start flags must exit 2"

: >"$log_file"
(
  cd "$fixture"
  PATH="$stub_bin:$PATH" TOOLS_TEST_LOG="$log_file" TOOLS_TEST_HOLD=1 \
    bash scripts/operica-tools.sh start --all >/dev/null 2>&1
) &
held_launcher_pid=$!

for _ in {1..50}; do
  if grep -Fxq 'pnpm:dev:desktop' "$log_file" 2>/dev/null &&
    grep -Fxq 'binary:server:' "$log_file" 2>/dev/null &&
    grep -Fxq 'pnpm:dev:web' "$log_file" 2>/dev/null; then
    break
  fi
  sleep 0.1
done

grep -Fxq 'pnpm:dev:desktop' "$log_file" || fail "kill test Desktop did not start"
grep -Fxq 'binary:server:' "$log_file" || fail "kill test backend did not start"
grep -Fxq 'pnpm:dev:web' "$log_file" || fail "kill test Web did not start"

kill_output="$(
  cd "$fixture"
  PATH="$stub_bin:$PATH" TOOLS_TEST_LOG="$log_file" \
    bash scripts/operica-tools.sh kill --all
)"

for _ in {1..50}; do
  kill -0 "$held_launcher_pid" 2>/dev/null || break
  sleep 0.1
done
if kill -0 "$held_launcher_pid" 2>/dev/null; then
  fail "kill --all must stop the start launcher and all services"
fi
wait "$held_launcher_pid" 2>/dev/null || true
held_launcher_pid=""

grep -Fq '共享 PostgreSQL 保持运行' <<<"$kill_output" ||
  fail "kill --all must report that PostgreSQL was preserved"

ancestor_guard_output="$(
  cd "$fixture"
  PATH="$stub_bin:$PATH" TOOLS_TEST_LOG="$log_file" \
    bash -c 'bash scripts/operica-tools.sh kill --all' 'pnpm dev:desktop'
)"
grep -Fq '没有运行中的 Operica 开发进程' <<<"$ancestor_guard_output" ||
  fail "kill must ignore matching command text in its ancestor processes"

no_process_output="$(
  cd "$fixture"
  PATH="$stub_bin:$PATH" TOOLS_TEST_LOG="$log_file" \
    bash scripts/operica-tools.sh kill
)"
grep -Fq '没有运行中的 Operica 开发进程' <<<"$no_process_output" ||
  fail "repeated kill must succeed when no processes remain"

set +e
(
  cd "$fixture"
  PATH="$stub_bin:$PATH" TOOLS_TEST_LOG="$log_file" \
    bash scripts/operica-tools.sh kill --unknown >/dev/null 2>&1
)
invalid_kill_status=$?
set -e
[ "$invalid_kill_status" = "2" ] || fail "unknown kill flags must exit 2"

echo "operica-tools.test.sh: PASS"
