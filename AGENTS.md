# AGENTS.md

## What this is
- Ops/config repo for running `llama-server` (llama.cpp, Vulkan) via `llama-tool.py` (stdlib-only Python; no pip/venv). No app source to build/test.
- Models/engines vendored locally (`vendor/`, `models/` gitignored). Presets live in `presets/*.env`.
- Tuned for [llama-slot-proxy](https://github.com/shuricksumy/llama-slot-proxy) (slot-pinned prompt cache).

## Entrypoint
- `./llama-tool.py <cmd> [subcmd]` with `--help`. Subcommands: `init`, `run`, `engine`, `models`, `cache`, `log`, `services`. Implemented in `tools/`.
- Help is self-documenting; don't duplicate flags.

## Config system (critical)
- `llama.env` (committed) + `presets/<name>.env` (plain bash). Resolved via `tools/_env.py` by `bash -c 'set -a; source llama.env; source presets/<name>.env; set +a; env'`.
- Presets use `: "${VAR:=default}"` so env overrides work per-invocation (e.g. `LLAMA_CTX_SIZE=16384 ./llama-tool.py run <preset>`).
- `LLAMA_API_KEY` must stay empty in `llama.env` (committed); put real value in `deploy/llama-server.env` (gitignored) via systemd `EnvironmentFile=` or export in shell. Never hardcode secrets.
- Shared vars in `llama.env` take precedence as "already-set" when sourcing preset; for vars where preset must override (e.g. embedding presets need larger `LLAMA_BATCH_SIZE`/`LLAMA_UBATCH_SIZE`), use plain assignment in preset (breaks `:=` idiom deliberately).
- Paths derived from `LLAMA_ENV_DIR`; `deploy/*.service`/`deploy/llama-server.logrotate` have hardcoded paths/user/group and must be edited per host.

## Engines
- `./llama-tool.py engine install|check|list|use [tag]` — fetches prebuilt Vulkan x64 from `ggml-org/llama.cpp` releases to `vendor/llama.cpp/<tag>/`, manages `vendor/llama.cpp/current` symlink. `LLAMA_CPP_VERSION` in `llama.env` selects active version; override per-run.

## Models
- `./llama-tool.py models list-files <org>/<repo>`, `download <org>/<repo> <file.gguf> [mmproj.gguf] [--preset name] [--port N] [--embedding]`, `list`, `check`, `delete <preset>`.
- Downloads to `models/<org>/<repo>/`, verify sha256 against HF API (`?blobs=true`), write `.part` then rename. Presets get `# hf-source:`/`# hf-sha256:` (and mmproj tags) — don't strip; `check`/`delete`/`list` rely on them. `--embedding` sets `--embedding --pooling last` and raises batch sizes (use plain assignment in generated preset).

## Running
- Foreground: `./llama-tool.py run --list`, `./llama-tool.py run <preset>`, `./llama-tool.py run` (uses `ACTIVE_PRESET`), `--dry-run`. Validates paths; under `--dry-run` degrades to warnings.
- As service (normal): `./llama-tool.py services enable <preset> --now` (arms daily restart timer too). Every preset is its own `llama-server@<preset>` instance (no anonymous default). `init` installs units but doesn't enable anything.
- `ARG_SPEC` order in `tools/run.py` must stay identical to original run-llama.sh (interleaved bool/value flags) — don't reorder.

## Services / logs / cache
- `./llama-tool.py services {list,status,restart,start,stop,enable,disable}` works by number (from `list`) or name. `enable/disable` also pair with `llama-server-restart@<preset>.timer` (use `--no-restart-timer` to skip). `restart` with no args only touches running instances.
- `./llama-tool.py log [file] [-n N] [--no-follow]` tails `LLAMA_LOG_FILE` (from `llama.env`/`ACTIVE_PRESET`) with `tail -F`.
- `./llama-tool.py cache check [url]` sends same prompt twice to verify `cached_tokens`. `./llama-tool.py cache stats [logfile]` parses logs (tolerates slot padding/completion wording differences).

## First-time setup (host)
1. `cp deploy/llama-server.env.example deploy/llama-server.env` and set secrets
2. Edit `deploy/llama-server@.service` (User/Group/WorkingDirectory), `deploy/llama-server.logrotate` paths if not in `/opt/llama-service`
3. `./llama-tool.py init` (copies units to `/etc/`, runs `daemon-reload`; prompts unless `-y`/`--dry-run`)
4. `./llama-tool.py engine install`
5. `./llama-tool.py models download <org>/<repo> <file.gguf> ...`
6. `./llama-tool.py services enable <preset> --now`

## Gotchas
- `tools/_env.py`: must use single bash invocation with `set -a` and source both files in order (don't split). CLI env overrides must be visible.
- Network/SSL: use `tools/_common.py::urlopen()`/`describe_url_error()` (handles SSL CA issues better than catching only `HTTPError`).
- HF downloads: need `?blobs=true` for size/sha256; download to `.part` and verify before rename.
- llama.cpp assets: default `ubuntu-vulkan-x64` is flat tar with CPU dispatch variants.
- Slot caching: `LLAMA_PARALLEL` >= agents in proxy config; `LLAMA_CTX_SIZE` split across slots.
- Never commit secrets; `llama.env` history had a leaked key once (history rewritten) — don't repeat.
- `deploy/llama-mem-report.service` not installed by `init` (manual). Binds `0.0.0.0` with no auth — trusted network only.
- `MemorySwapMax=0` on `llama-server@.service` requires cgroup v2.
- Migrating from old `llama-server.service`: disable old, enable named instances, run `init`, remove stale unit files.
