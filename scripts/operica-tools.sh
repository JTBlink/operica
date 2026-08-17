#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Build, package, and launch helper.
#
# Usage:
#   bash scripts/operica-tools.sh                  # Package Desktop for the current platform
#   bash scripts/operica-tools.sh desktop [...]    # Same, forwarding extra package arguments
#   bash scripts/operica-tools.sh build            # Cross-compile and archive Go server binaries
#   bash scripts/operica-tools.sh start            # Clean this checkout, then start Desktop and a backend if needed
#   bash scripts/operica-tools.sh start --server   # Desktop + local backend (force build/migrate)
#   bash scripts/operica-tools.sh start --web      # Desktop + Web (backend still auto-attached if needed)
#   bash scripts/operica-tools.sh start --all      # Desktop + local backend + Web
#   bash scripts/operica-tools.sh kill              # Stop all services for this checkout
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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

usage() {
  cat <<'EOF'
Operica 本地开发与发布工具

用法:
  ./scripts/operica-tools.sh <命令> [参数]

不传命令时，默认打包当前平台的桌面端。

命令:
  desktop [参数...]
             打包当前平台桌面端，参数透传给 desktop package
  build      交叉编译 Go 服务端二进制并归档
  start [--server] [--web] [--all]
             启动前会先停止当前 checkout 的已有开发进程；默认启动桌面端，
             若本地后端未运行会自动一并启动以确保可登录；可按需附加 Web
  kill [--all]
             停止当前 checkout 的桌面端、本地后端和 Web
  help       显示帮助信息

start 参数:
  --server   显式确保/重启本地后端；启动 PostgreSQL、编译 Go 二进制并执行迁移
  --web      附加 Web 开发服务器；本地后端未运行时仍会自动附加
  --all      等同于 --server --web
  -h, --help 显示帮助信息

kill 参数:
  --all      停止当前 checkout 的所有开发进程，也是 kill 的默认行为
  -h, --help 显示帮助信息
  kill 不会停止共享 PostgreSQL，也不会停止其他 checkout 的进程

本地登录提示:
  默认账号: 未设置。配置 AUTO_LOGIN_EMAIL 后，本地请求会自动使用该账号登录
  默认密码: 无。Operica 使用邮箱验证码登录，不使用账号密码
  登录验证码: 优先使用 OPERICA_DEV_VERIFICATION_CODE 配置的 6 位验证码；
              未配置时，从本地后端日志中的 verification code 获取
  安全提示: 固定验证码仅用于本地开发，不要在 production 或公网环境启用

环境变量:
  ENV_FILE        --server 或 --web 使用的 env 文件
                  默认主 checkout 使用 .env，linked worktree 使用 .env.worktree
  AUTO_LOGIN_EMAIL
                  本地开发自动登录账号，默认未设置
  OPERICA_DEV_VERIFICATION_CODE
                  非 production 环境的固定 6 位登录验证码，默认未设置
  PLATFORMS       build 的 GOOS/GOARCH 列表，以空格分隔
                  默认使用当前系统平台
  OUT_DIR         build 产物目录，默认 dist/release
  SKIP_GO=1       build 时跳过 Go 二进制编译
  WITH_FRONTEND=1 build 时额外构建并归档 Web

示例:
  ./scripts/operica-tools.sh start
      清理当前 checkout，再启动桌面端；本地后端未运行时自动启动

  ./scripts/operica-tools.sh start --server
      启动桌面端和本地后端

  ./scripts/operica-tools.sh start --all
      启动桌面端、本地后端和 Web

  ./scripts/operica-tools.sh kill
      停止当前 checkout 的全部开发进程

  ./scripts/operica-tools.sh desktop --mac --arm64
      打包 macOS arm64 桌面端，不发布产物

  PLATFORMS="linux/amd64 linux/arm64" ./scripts/operica-tools.sh build
      交叉编译两个 Linux 平台的服务端产物
EOF
}

# --- helpers ----------------------------------------------------------------

runtime_pid_file() {
  local runtime_dir="${TMPDIR:-/tmp}"
  local repo_hash
  repo_hash="$(printf '%s' "$REPO_ROOT" | cksum | awk '{print $1}')"
  printf '%s/operica-tools-%s.pids\n' "${runtime_dir%/}" "$repo_hash"
}

process_belongs_to_checkout() {
  local pid="$1"
  local cwd

  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1)"

  case "$cwd" in
    "$REPO_ROOT" | "$REPO_ROOT"/*) return 0 ;;
    *) return 1 ;;
  esac
}

process_is_active() {
  local pid="$1"
  local state

  kill -0 "$pid" 2>/dev/null || return 1
  state="$(ps -p "$pid" -o stat= 2>/dev/null | awk '{print $1}')"
  case "$state" in
    "" | Z*) return 1 ;;
    *) return 0 ;;
  esac
}

port_in_use() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

# Appends root_pid and all of its descendants (post-order, deduped) to the
# caller's PIDS_OUT array. Callers must `local PIDS_OUT=()` before use.
# A single `kill` on a job's top-level pid misses nested children (e.g.
# pnpm -> turbo -> electron-vite -> electron), which then linger and keep
# their ports bound — walk the whole tree instead.
collect_process_tree() {
  local root_pid="$1"
  local child existing found

  while IFS= read -r child; do
    [ -n "$child" ] && collect_process_tree "$child"
  done < <(pgrep -P "$root_pid" 2>/dev/null || true)

  found=0
  for existing in "${PIDS_OUT[@]-}"; do
    [ -n "$existing" ] || continue
    if [ "$existing" = "$root_pid" ]; then
      found=1
      break
    fi
  done
  [ "$found" = "0" ] && PIDS_OUT+=("$root_pid")
  return 0
}

# TERM every pid, wait up to 5s for exit, then KILL any survivors.
terminate_pids() {
  local pids=("$@")
  local pid iteration alive

  [ "${#pids[@]}" -eq 0 ] && return 0

  for pid in "${pids[@]}"; do
    kill -TERM "$pid" 2>/dev/null || true
  done

  for iteration in {1..50}; do
    alive=0
    for pid in "${pids[@]}"; do
      if process_is_active "$pid"; then
        alive=1
        break
      fi
    done
    [ "$alive" = "0" ] && break
    sleep 0.1
  done

  for pid in "${pids[@]}"; do
    if process_is_active "$pid"; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done
  return 0
}

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

  echo "==> 打包 Operica Desktop"
  [ -d node_modules ] || pnpm install --frozen-lockfile
  pnpm -C apps/desktop package -- "${package_args[@]}"
}

# --- build (server release) -------------------------------------------------

cmd_build() {
  version_vars
  local platforms="${PLATFORMS:-$(go env GOOS)/$(go env GOARCH)}"
  local out_dir="${OUT_DIR:-dist/release}"
  local go_targets=(server operica migrate)

  echo "==> 打包 Operica ${VERSION} (commit ${COMMIT})"
  echo "    输出目录: ${out_dir}"
  rm -rf "$out_dir"
  mkdir -p "$out_dir"

  if [ "${SKIP_GO:-0}" != "1" ]; then
    for platform in $platforms; do
      local goos="${platform%%/*}" goarch="${platform##*/}"
      local stage="$out_dir/operica_${VERSION}_${goos}_${goarch}"
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

      local archive="operica_${VERSION}_${goos}_${goarch}.tar.gz"
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

      local archive="operica-web_${VERSION}.tar.gz"
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
  local go_targets=(server operica migrate)
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

  echo "==> 启动前清理当前 checkout 的已有开发进程..."
  cmd_kill --all

  local env_loaded=0
  if [ -z "$env_file" ]; then
    [ -f .git ] && env_file=".env.worktree" || env_file=".env"
  fi
  if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
    # shellcheck disable=SC1091
    . scripts/local-env.sh
    env_loaded=1

    echo "==> 使用 env: $env_file"
  fi

  local backend_port="${PORT:-8080}"
  local reuse_backend=0
  if [ "$start_server" = "0" ] && ! port_in_use "$backend_port"; then
    echo "==> 本地后端 (localhost:${backend_port}) 未运行，自动附加以确保可登录"
    start_server=1
  elif [ "$start_server" = "0" ]; then
    reuse_backend=1
  fi

  if { [ "$start_server" = "1" ] || [ "$start_web" = "1" ]; } && [ "$env_loaded" = "0" ]; then
    echo "缺少 env 文件: $env_file" >&2
    echo "从 .env.example 创建 .env，或运行 'make worktree-env'。" >&2
    exit 1
  fi

  local desktop_port="${DESKTOP_RENDERER_PORT:-5173}"
  local busy_ports=()

  port_in_use "$desktop_port" && busy_ports+=("桌面端 (${desktop_port})")
  if [ "$start_server" = "1" ] && port_in_use "$backend_port"; then
    busy_ports+=("本地后端 (${backend_port})")
  fi
  if [ "$start_web" = "1" ] && port_in_use "${FRONTEND_PORT:-3000}"; then
    busy_ports+=("Web (${FRONTEND_PORT:-3000})")
  fi

  if [ "${#busy_ports[@]}" -gt 0 ]; then
    echo "端口已被占用，无法启动: ${busy_ports[*]}" >&2
    echo "请先运行 './scripts/operica-tools.sh kill' 清理残留进程后重试。" >&2
    exit 1
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
  if [ "$start_server" = "1" ]; then
    echo "  后端:  http://localhost:${backend_port}"
  elif [ "$reuse_backend" = "1" ]; then
    echo "  后端:  http://localhost:${backend_port} (复用已运行的进程)"
  fi
  [ "$start_web" = "1" ] && echo "  Web:    http://localhost:${FRONTEND_PORT:-3000}"
  echo ""

  local child_pids=()
  local exit_status=0
  local pid_file
  pid_file="$(runtime_pid_file)"

  cleanup_start() {
    local PIDS_OUT=()
    local pid
    for pid in "${child_pids[@]}"; do
      collect_process_tree "$pid"
    done
    terminate_pids "${PIDS_OUT[@]}"
    rm -f -- "$pid_file"
  }

  record_start_pids() {
    local tmp_pid_file="${pid_file}.$$"
    (
      umask 077
      printf '%s\n' "${child_pids[@]}" >"$tmp_pid_file"
      mv -f -- "$tmp_pid_file" "$pid_file"
    )
  }

  trap cleanup_start EXIT INT TERM

  pnpm dev:desktop &
  child_pids+=("$!")
  record_start_pids

  if [ "$start_server" = "1" ]; then
    ./server/bin/server &
    child_pids+=("$!")
    record_start_pids
  fi

  if [ "$start_web" = "1" ]; then
    pnpm dev:web &
    child_pids+=("$!")
    record_start_pids
  fi

  wait "${child_pids[@]}" || exit_status=$?
  cleanup_start
  trap - EXIT INT TERM
  return "$exit_status"
}

# --- kill (local dev) -------------------------------------------------------

cmd_kill() {
  local arg
  local pid_file
  local line pid command
  local root_pid
  local protected_pid parent_pid
  local kill_targets=()
  local root_targets=()
  local protected_pids=()

  for arg in "$@"; do
    case "$arg" in
      --all) ;;
      -h | --help)
        usage
        return
        ;;
      *)
        echo "kill: 未知参数: $arg" >&2
        usage >&2
        return 2
        ;;
    esac
  done

  pid_file="$(runtime_pid_file)"

  # Never select this command or one of its parent shells. A wrapper command
  # can legitimately contain text such as "pnpm dev:desktop", which would
  # otherwise look like a stale development process during the ps scan.
  protected_pid="$$"
  while [[ "$protected_pid" =~ ^[0-9]+$ ]] && [ "$protected_pid" -gt 1 ]; do
    protected_pids+=("$protected_pid")
    parent_pid="$(ps -p "$protected_pid" -o ppid= 2>/dev/null | tr -d ' ')"
    [ -n "$parent_pid" ] || break
    protected_pid="$parent_pid"
  done

  process_is_protected() {
    local candidate="$1"
    local protected
    for protected in "${protected_pids[@]}"; do
      [ "$protected" = "$candidate" ] && return 0
    done
    return 1
  }

  add_unique_pid() {
    local candidate="$1"
    local existing
    process_is_protected "$candidate" && return
    for existing in "${root_targets[@]-}"; do
      [ -n "$existing" ] || continue
      [ "$existing" = "$candidate" ] && return
    done
    root_targets+=("$candidate")
  }

  if [ -f "$pid_file" ]; then
    while IFS= read -r pid; do
      if process_belongs_to_checkout "$pid"; then
        add_unique_pid "$pid"
      fi
    done <"$pid_file"
  fi

  # Discover processes from starts created before PID tracking existed, and
  # direct pnpm/server invocations. The cwd check keeps the scope in this checkout.
  while IFS= read -r line; do
    read -r pid command <<<"$line"
    case "$command" in
      *"scripts/operica-tools.sh start"* | *"pnpm dev:desktop"* | *"pnpm dev:web"* | \
        *"turbo dev --filter=@operica/desktop"* | *"turbo dev --filter=@operica/web"* | \
        *"electron-vite"* | *"next-server"* | *"server/bin/server"*)
        if process_belongs_to_checkout "$pid"; then
          add_unique_pid "$pid"
        fi
        ;;
    esac
  done < <(ps -axo pid=,command=)

  if [ "${#root_targets[@]}" -eq 0 ]; then
    rm -f -- "$pid_file"
    echo "当前 checkout 没有运行中的 Operica 开发进程。"
    return
  fi

  local PIDS_OUT=()
  for root_pid in "${root_targets[@]}"; do
    collect_process_tree "$root_pid"
  done
  kill_targets=("${PIDS_OUT[@]}")

  echo "==> 停止当前 checkout 的 ${#kill_targets[@]} 个 Operica 开发进程..."
  terminate_pids "${kill_targets[@]}"

  rm -f -- "$pid_file"
  echo "✓ 已停止桌面端、本地后端和 Web。共享 PostgreSQL 保持运行。"
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
  kill)
    shift
    cmd_kill "$@"
    ;;
  help | -h | --help) usage ;;
  *)
    echo "未知命令: $1" >&2
    usage >&2
    exit 2
    ;;
esac
