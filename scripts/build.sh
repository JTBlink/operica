#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# 打包 / 编译 / 启动脚本。
#
# 用法:
#   bash scripts/build.sh                  # 默认：打包当前平台桌面端
#   bash scripts/build.sh desktop [...]    # 同上；额外参数透传给 desktop package
#   bash scripts/build.sh build            # 交叉编译 Go 服务端二进制并归档
#   bash scripts/build.sh start            # 编译本机二进制并启动后端 + 前端
#   bash scripts/build.sh help
#
# build 子命令环境变量:
#   PLATFORMS       空格分隔的 GOOS/GOARCH 列表（默认: 当前系统平台）
#   OUT_DIR         产物输出目录 (默认: dist/release)
#   SKIP_GO=1       跳过 Go 交叉编译
#   WITH_FRONTEND=1 额外构建并归档 Web（默认不构建）
#
# start 子命令环境变量:
#   ENV_FILE        env 文件 (默认: .env，worktree 下 .env.worktree)
# ==========================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<'EOF'
用法: bash scripts/build.sh [命令] [参数]

命令:
  desktop    打包当前平台桌面端（默认），参数透传给 desktop package
  build      交叉编译 Go 服务端二进制并归档（需 WITH_FRONTEND=1 才额外构建 Web）
  start      编译本机二进制并启动后端 + 前端 (含 Postgres 与迁移)
  help       显示本帮助
EOF
}

# --- helpers ----------------------------------------------------------------

version_vars() {
  VERSION="${VERSION:-$(git describe --tags --match 'v[0-9]*' --always --dirty 2>/dev/null || echo dev)}"
  COMMIT="${COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
  DATE="${DATE:-$(date -u '+%Y-%m-%dT%H:%M:%SZ')}"
  LDFLAGS="-s -w -X main.version=${VERSION} -X main.commit=${COMMIT} -X main.date=${DATE}"
}

# --- desktop (default) ------------------------------------------------------

cmd_desktop() {
  local package_args=("$@")
  local arg has_publish=0

  for arg in "$@"; do
    case "$arg" in
      --publish | --publish=*) has_publish=1 ;;
    esac
  done
  if [ "$has_publish" = "0" ]; then
    package_args+=(--publish never)
  fi

  echo "==> 打包 Opercia Desktop"
  [ -d node_modules ] || pnpm install --frozen-lockfile
  pnpm -C apps/desktop package -- "${package_args[@]}"
}

# --- build (server release) -------------------------------------------------

cmd_build() {
  version_vars
  local platforms="${PLATFORMS:-$(go env GOOS)/$(go env GOARCH)}"
  local out_dir="${OUT_DIR:-dist/release}"
  local go_targets=(server opercia migrate)

  echo "==> 打包 Opercia ${VERSION} (commit ${COMMIT})"
  echo "    输出目录: ${out_dir}"
  rm -rf "$out_dir"
  mkdir -p "$out_dir"

  if [ "${SKIP_GO:-0}" != "1" ]; then
    for platform in $platforms; do
      local goos="${platform%%/*}" goarch="${platform##*/}"
      local stage="$out_dir/opercia_${VERSION}_${goos}_${goarch}"
      mkdir -p "$stage"

      echo ""
      echo "==> [go] 编译 ${goos}/${goarch}..."
      for target in "${go_targets[@]}"; do
        local ext=""
        [ "$goos" = "windows" ] && ext=".exe"
        (cd server && CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" \
          go build -trimpath -ldflags "$LDFLAGS" \
          -o "$REPO_ROOT/$stage/${target}${ext}" "./cmd/${target}")
        echo "    ✓ ${target}${ext}"
      done

      local archive="opercia_${VERSION}_${goos}_${goarch}.tar.gz"
      tar -czf "$out_dir/$archive" -C "$out_dir" "$(basename "$stage")"
      rm -rf "$stage"
      echo "    → $archive"
    done
  fi

  if [ "${WITH_FRONTEND:-0}" = "1" ]; then
    echo ""
    echo "==> [web] turbo build..."
    [ -d node_modules ] || pnpm install --frozen-lockfile
    STANDALONE=true pnpm build

    local web_standalone="apps/web/.next/standalone"
    local web_static="apps/web/.next/static"
    if [ -d "$web_standalone" ]; then
      local stage="$out_dir/web"
      mkdir -p "$stage"
      cp -R "$web_standalone/." "$stage/"
      mkdir -p "$stage/apps/web/.next"
      [ -d "$web_static" ] && cp -R "$web_static" "$stage/apps/web/.next/static"
      [ -d "apps/web/public" ] && cp -R "apps/web/public" "$stage/apps/web/public"

      local archive="opercia-web_${VERSION}.tar.gz"
      tar -czf "$out_dir/$archive" -C "$out_dir" web
      rm -rf "$stage"
      echo "    → $archive"
    else
      echo "    ⚠ 未找到 ${web_standalone}（next.config 需 output: 'standalone'），跳过 web 归档。"
    fi
  fi

  echo ""
  echo "✓ 打包完成。产物位于 ${out_dir}/:"
  ls -1 "$out_dir"
}

# --- start (local dev) ------------------------------------------------------

cmd_start() {
  version_vars
  local env_file="${ENV_FILE:-}"
  local go_targets=(server opercia migrate)

  if [ -z "$env_file" ]; then
    [ -f .git ] && env_file=".env.worktree" || env_file=".env"
  fi
  if [ ! -f "$env_file" ]; then
    echo "缺少 env 文件: $env_file" >&2
    echo "从 .env.example 创建 .env，或运行 'make worktree-env'。" >&2
    exit 1
  fi

  set -a
  # shellcheck disable=SC1090
  . "$env_file"
  set +a
  # shellcheck disable=SC1091
  . scripts/local-env.sh

  echo "==> 使用 env: $env_file"
  bash scripts/ensure-postgres.sh "$env_file"

  echo "==> 编译本机二进制..."
  mkdir -p server/bin
  for target in "${go_targets[@]}"; do
    (cd server && CGO_ENABLED=0 go build -trimpath -ldflags "$LDFLAGS" \
      -o "bin/${target}" "./cmd/${target}")
    echo "    ✓ ${target}"
  done

  echo "==> 执行数据库迁移..."
  ./server/bin/migrate up

  echo ""
  echo "✓ 就绪，启动服务..."
  echo "  后端:  http://localhost:${PORT:-8080}"
  echo "  前端:  http://localhost:${FRONTEND_PORT:-3000}"
  echo ""

  trap 'kill 0' EXIT
  ./server/bin/server &
  pnpm dev:web &
  wait
}

# --- dispatch ---------------------------------------------------------------

case "${1:-desktop}" in
  desktop)
    [ "$#" -eq 0 ] || shift
    cmd_desktop "$@"
    ;;
  build) cmd_build ;;
  start) cmd_start ;;
  help | -h | --help) usage ;;
  *)
    echo "未知命令: $1" >&2
    usage >&2
    exit 2
    ;;
esac
