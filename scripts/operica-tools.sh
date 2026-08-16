#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Build, package, and launch helper.
#
# Usage:
#   bash scripts/operica-tools.sh                  # Package Desktop for the current platform
#   bash scripts/operica-tools.sh desktop [...]    # Same, forwarding extra package arguments
#   bash scripts/operica-tools.sh build            # Cross-compile and archive Go server binaries
#   bash scripts/operica-tools.sh start            # Start Desktop development only
#   bash scripts/operica-tools.sh start --server   # Desktop + local backend
#   bash scripts/operica-tools.sh start --web      # Desktop + Web
#   bash scripts/operica-tools.sh start --all      # Desktop + local backend + Web
#   bash scripts/operica-tools.sh help
#
# Environment variables for build:
#   PLATFORMS       Space-separated GOOS/GOARCH list (default: current platform)
#   OUT_DIR         Artifact directory (default: dist/release)
#   SKIP_GO=1       Skip Go cross-compilation
#   WITH_FRONTEND=1 Also build and archive Web (default: disabled)
#
# Environment variables for start --server/--web:
#   ENV_FILE        Env file (default: .env, or .env.worktree in a linked worktree)
# ==========================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<'EOF'
Opercia 本地开发与发布工具

用法:
  ./scripts/operica-tools.sh <命令> [参数]

不传命令时，默认打包当前平台的桌面端。

命令:
  desktop [参数...]
             打包当前平台桌面端，参数透传给 desktop package
  build      交叉编译 Go 服务端二进制并归档
  start [--server] [--web] [--all]
             默认仅启动桌面端；可按需附加本地后端和 Web
  help       显示帮助信息

start 参数:
  --server   附加本地后端；启动 PostgreSQL、编译 Go 二进制并执行迁移
  --web      附加 Web 开发服务器；不会自动启动后端
  --all      附加本地后端和 Web，等同于 --server --web
  -h, --help 显示帮助信息

本地登录提示:
  默认账号: 未设置。配置 AUTO_LOGIN_EMAIL 后，本地请求会自动使用该账号登录
  默认密码: 无。Opercia 使用邮箱验证码登录，不使用账号密码
  登录验证码: 优先使用 OPERCIA_DEV_VERIFICATION_CODE 配置的 6 位验证码；
              未配置时，从本地后端日志中的 verification code 获取
  安全提示: 固定验证码仅用于本地开发，不要在 production 或公网环境启用

环境变量:
  ENV_FILE        --server 或 --web 使用的 env 文件
                  默认主 checkout 使用 .env，linked worktree 使用 .env.worktree
  AUTO_LOGIN_EMAIL
                  本地开发自动登录账号，默认未设置
  OPERCIA_DEV_VERIFICATION_CODE
                  非 production 环境的固定 6 位登录验证码，默认未设置
  PLATFORMS       build 的 GOOS/GOARCH 列表，以空格分隔
                  默认使用当前系统平台
  OUT_DIR         build 产物目录，默认 dist/release
  SKIP_GO=1       build 时跳过 Go 二进制编译
  WITH_FRONTEND=1 build 时额外构建并归档 Web

示例:
  ./scripts/operica-tools.sh start
      仅启动桌面端开发进程

  ./scripts/operica-tools.sh start --server
      启动桌面端和本地后端

  ./scripts/operica-tools.sh start --all
      启动桌面端、本地后端和 Web

  ./scripts/operica-tools.sh desktop --mac --arm64
      打包 macOS arm64 桌面端，不发布产物

  PLATFORMS="linux/amd64 linux/arm64" ./scripts/operica-tools.sh build
      交叉编译两个 Linux 平台的服务端产物
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
  local start_server=0
  local start_web=0
  local env_file="${ENV_FILE:-}"
  local go_targets=(server opercia migrate)
  local arg

  for arg in "$@"; do
    case "$arg" in
      --server) start_server=1 ;;
      --web) start_web=1 ;;
      --all)
        start_server=1
        start_web=1
        ;;
      -h | --help)
        usage
        return
        ;;
      *)
        echo "start: 未知参数: $arg" >&2
        usage >&2
        return 2
        ;;
    esac
  done

  if [ "$start_server" = "1" ] || [ "$start_web" = "1" ]; then
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
  fi

  if [ "$start_server" = "1" ]; then
    version_vars
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
  fi

  echo ""
  echo "✓ 就绪，启动桌面端..."
  [ "$start_server" = "1" ] && echo "  后端:  http://localhost:${PORT:-8080}"
  [ "$start_web" = "1" ] && echo "  Web:    http://localhost:${FRONTEND_PORT:-3000}"
  echo ""

  local child_pids=()
  local exit_status=0

  cleanup_start() {
    local pid
    for pid in "${child_pids[@]}"; do
      kill "$pid" 2>/dev/null || true
    done
  }

  trap cleanup_start EXIT INT TERM

  pnpm dev:desktop &
  child_pids+=("$!")

  if [ "$start_server" = "1" ]; then
    ./server/bin/server &
    child_pids+=("$!")
  fi

  if [ "$start_web" = "1" ]; then
    pnpm dev:web &
    child_pids+=("$!")
  fi

  wait "${child_pids[@]}" || exit_status=$?
  cleanup_start
  trap - EXIT INT TERM
  return "$exit_status"
}

# --- dispatch ---------------------------------------------------------------

case "${1:-desktop}" in
  desktop)
    [ "$#" -eq 0 ] || shift
    cmd_desktop "$@"
    ;;
  build) cmd_build ;;
  start)
    shift
    cmd_start "$@"
    ;;
  help | -h | --help) usage ;;
  *)
    echo "未知命令: $1" >&2
    usage >&2
    exit 2
    ;;
esac
