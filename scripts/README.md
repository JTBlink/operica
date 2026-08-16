# scripts/

支撑 `Makefile` 目标、安装 / 自托管流程以及 CI 校验的辅助脚本。大部分脚本通过
`make` 间接调用 —— 下面各表标注了每个脚本的入口。

## 本地开发

| 脚本 | 调用方 | 用途 |
| --- | --- | --- |
| `dev.sh` | `make dev` | 端到端引导当前 checkout：检查前置依赖（node/pnpm/go/docker）、创建 env 文件（`.env`，在 worktree 内则为 `.env.worktree`）、`pnpm install`、确保 Postgres 就绪、执行迁移，然后同时启动 Go 后端和 `pnpm dev:web`。 |
| `ensure-postgres.sh <env-file>` | `make dev/server/test/migrate-*`、`check.sh` | 确保目标数据库可用。本地主机会拉起共享的 `postgres` Docker Compose 服务并在缺失时创建数据库；远程 `DATABASE_URL` 则跳过 Docker，改用 `pg_isready` 做连通性预检。 |
| `local-env.sh` | 被 `dev.sh`、`check.sh` source | 共享的 env 派生逻辑。在加载 env 文件*之后* source 它，用于补全派生默认值（端口、`MULTICA_PUBLIC_URL`、`MULTICA_SERVER_URL`、`PLAYWRIGHT_BASE_URL` 等）并导出。 |
| `init-worktree-env.sh [env-file]` | `make worktree-env` | 生成每个 worktree 独立的 `.env.worktree`，其中数据库名唯一、后端/前端端口根据 worktree 路径哈希派生以避免冲突。设置 `FORCE=1` 可覆盖已存在的文件。 |

## 编译与发布

| 脚本 | 调用方 | 用途 |
| --- | --- | --- |
| `operica-tools.sh` / `operica-tools.sh desktop` | `make release` | 默认命令。打包当前平台的 Electron 桌面端（Go CLI 由 `bundle-cli.mjs` 自动编译内嵌），不构建 Web 也不编译服务端二进制；额外参数透传给 desktop package（如 `--mac --arm64`），未显式指定 `--publish` 时自动使用 `--publish never`。 |
| `operica-tools.sh build` | `make release-server` | 交叉编译 Go 服务端二进制（server/opercia/migrate）并归档到 `OUT_DIR`（默认 `dist/release`）。默认平台跟随本机；需多平台时用 `PLATFORMS="linux/amd64 linux/arm64 …"` 覆盖。另支持 `SKIP_GO=1`、`WITH_FRONTEND=1`（额外构建 Web standalone 归档）。 |
| `operica-tools.sh start [--server] [--web] [--all]` | `make run` | 默认仅启动 Electron 桌面端 (`pnpm dev:desktop`)。`--server` 会额外加载 env、确保 Postgres、编译本机二进制、执行迁移并启动后端；`--web` 会额外启动 Web；`--all` 同时附加后端和 Web。 |
| `operica-tools.sh kill [--all]` | 直接调用 | 停止当前 checkout 的桌面端、本地后端和 Web 开发进程；默认即为 `--all`。通过 checkout 路径和 PID 记录限制作用域，不停止其他 worktree，也不停止共享 PostgreSQL。 |

## 校验 / CI

| 脚本 | 调用方 | 用途 |
| --- | --- | --- |
| `check.sh` | `make check` | 完整校验流水线：确保 Postgres → `pnpm typecheck` → `pnpm test` → Go 测试 → 若后端/前端未运行则启动 → Playwright E2E。只会停止由自己启动的服务。 |
| `test-go.sh [--race]` | `make test`、`check.sh` | 分两轮运行 Go 测试套件：先跑常规包，再以受限并行度（`-p 2 -parallel 2`）跑 `./pkg/agent/...`，因为那些基于子进程的测试有硬性超时。两轮都在 agent-CLI 守卫下运行。 |
| `go-test-with-agent-cli-guard.sh -- <cmd...>` | `test-go.sh` | 运行命令时用桩二进制（来自 `agent-cli-command-names.txt`）在 `PATH` 中遮蔽所有真实 agent CLI。若测试调用了真实 agent CLI，桩会记录并使运行失败 —— 防止测试启动外部 agent。 |
| `agent-cli-command-names.txt` | `go-test-with-agent-cli-guard.sh` | 数据文件：需守卫的 agent CLI 名称（claude、codex、copilot、cursor-agent、opencode 等）。 |
| `operica-tools.test.sh` | `check.sh` | `operica-tools.sh` 的启动行为测试，断言桌面端为 `start` 默认目标，后端和 Web 只能通过显式参数附加。 |
| `test-go.test.sh` | `check.sh` | `test-go.sh` 的单元测试 —— 打桩 `go` 并断言精确的 `go test` 参数序列与 usage/退出码行为。 |
| `helm-config.test.sh` | CI | 对 `deploy/helm/opercia` 的 chart 执行 `helm lint`，并断言 `templates/configmap.yaml` 渲染出预期的配置值（默认值与覆盖值）。 |
| `selfhost-config.test.sh` | CI | 断言自托管栈的 `docker compose config` 渲染出预期的配置值。 |

## 安装与自托管

| 脚本 | 调用方 | 用途 |
| --- | --- | --- |
| `install.sh` | `curl … \| bash` | Unix 安装器。安装/升级 `opercia` CLI（Homebrew 或回退到发布二进制），加 `--with-server` 时还会配置自托管服务器。 |
| `install.ps1` | `irm … \| iex` | Windows 安装器。默认安装 CLI，或在 `MULTICA_MODE=local` 时启动本地服务器 + 安装 + 配置。 |
| `install.test.sh` | CI | `install.sh` 的沙盒测试，用桩 `curl`/`brew` 模拟各种 Homebrew 失败模式与发布二进制回退路径。 |
| `install.ps1.test.ps1` | CI | `install.ps1` 的 PowerShell 测试。 |
| `selfhost-wait.sh [official\|build]` | `make selfhost`、`make selfhost-build` | 轮询自托管后端 `/health`（从 `docker compose port` 读回*实际发布*的主机端口），随后打印前端/后端 URL 及后续 CLI 操作指引。 |

## 代码生成与其他

| 脚本 | 调用方 | 用途 |
| --- | --- | --- |
| `generate-reserved-slugs.mjs` | `pnpm generate:reserved-slugs` | 从 `server/internal/handler/reserved_slugs.json`（唯一事实来源）重新生成 `packages/core/paths/reserved-slugs.ts`。CI 会重跑并用 `git diff --exit-code` 防止两端漂移。 |
| `screenshot-pr-cards.mjs` | `pnpm exec node scripts/screenshot-pr-cards.mjs` | 独立的 Playwright 截图脚本，捕获 PR 卡片演示 issue。通过本地认证流程以 `dev@localhost` 登录，并将裁剪后的 PNG 保存到 `./.screenshots/`。 |
