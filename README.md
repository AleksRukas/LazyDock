# 🦥⚓ LazyDock

> **"Why remember 40 Docker CLI flags when you have 10 fingers and 0 motivation?"**

[![Bash](https://img.shields.io/badge/Language-Bash_5.0+-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-Compose_Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Laziness Level](https://img.shields.io/badge/Laziness-100%25-orange?logo=couchbase&logoColor=white)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 🧐 What is LazyDock?

**LazyDock** is an interactive, zero-dependency, single-file Bash TUI for humans who are tired of typing:

```bash
docker compose --profile manual up -d my-insanely-long-container-name-prod
```
...only to realize you had a typo, your RAM is full of Linux page cache, and your Docker JSON log file has quietly grown to 45 Gigabytes.

**LazyDock** turns everyday container chores into single-digit keypresses. No Python runtime required. No Node.js build steps. No 200MB Go binary. Just pure, unadulterated, lightweight Bash.

---

## ✨ Features for the Truly Exhausted

| Icon | Feature | What It Actually Does |
| :---: | :--- | :--- |
| 🛑 | **Stop Containers** | See what’s running and kill one (or all of them) without copy-pasting container IDs like a peasant. |
| 🚀 | **One-Key Start** | Dynamically parses your `docker-compose.yaml` (including profiles) and launches services in detached mode. |
| 🔄 | **The "Turn It Off and On Again"** | Stops the container, flushes the host OS page cache, and boots it back up fresh. |
| 🔨 | **Rebuild & Recompile** | Choose between standard cached build or full `--no-cache` nuclear rebuild without remembering compose flags. |
| 🧹 | **Memory Unclogger** | Runs `sync && sudo sysctl -w vm.drop_caches=3` and prints your freed RAM so you can breathe again. |
| 📜 | **Lazy Log Viewer** | Tails the last 100 lines and follows live output with a single keypress. |
| 🧼 | **The Log Purge & Follow** | Truncates bloated Docker JSON log files to `0 bytes` in-place (`truncate -s 0`) and starts streaming fresh logs from clean slate. |
| 📊 | **Vitals Glance** | Instant container status table + host memory breakdown. |

---

## 🖥️ Menu Preview

```text
======================================================
         🦥 LazyDock - Minimum Effort Docker          
======================================================
Project Directory: /your/project/dir

Actions:
  [1] 🛑 Stop running container(s)
  [2] 🚀 Start a container (docker compose up -d)
  [3] 🔄 Restart a container (Stop -> Drop Cache -> Start)
  [4] 🔨 Rebuild / Recompile & Start (--build)
  [5] 🧹 Drop Memory Caches (sync & sysctl drop_caches=3)
  [6] 📜 View Container Logs (-f --tail 100)
  [7] 🧼 Clear Container Log & Stream Fresh Logs
  [8] 📊 Show Status (Containers & Memory)
  [q] 🚪 Exit

Enter your choice [1-8 or q]: 
```

---

## ⚡ Quickstart

### 1. Download into your project directory
Drop `lazydock.sh` right next to your `docker-compose.yaml` (or `docker-compose.yml`):

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/LazyDock/main/lazydock.sh -o lazydock.sh
chmod +x lazydock.sh
```

### 2. Run it
```bash
./lazydock.sh
```

*(Tip: Add `alias ldock="./lazydock.sh"` to your `~/.bashrc` or `~/.zshrc` to achieve maximum sloth status).*

---

## ⚙️ Configuration (Optional)

LazyDock automatically detects `docker-compose.yaml` or `docker-compose.yml` in its current directory.

If your services use Docker Compose **Profiles**, LazyDock defaults to `manual`. You can override this anytime:

```bash
export COMPOSE_PROFILES="prod,gpu"
./lazydock.sh
```

---

## 💡 Why `truncate -s 0` for logs?

Docker’s default `json-file` logging driver never resets logs until the container is deleted. If you run long-living containers or verbose LLM inference servers, log files grow massive. 

Option `[7]` locates the container's physical log file path via `docker inspect` and runs:

```bash
sudo truncate -s 0 /var/lib/docker/containers/<id>/<id>-json.log
```

This instantly wipes the file on disk without stopping the container or breaking Docker's active file descriptor, then immediately starts tailing new output.

---

## 📜 License

[MIT](LICENSE) © 2026. Do whatever you want with it—just don't expend unnecessary energy doing so. 🦥
