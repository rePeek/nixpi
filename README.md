# nixpi — Nix-native Pi Runtime Wrapper

使用 Nix 为 [Pi coding agent](https://github.com/earendil-works/pi) 提供稳定的运行时环境。Nix 负责可执行文件和系统依赖；Git 仓库作为配置 source of truth；Pi 在 agent dir 下安装扩展并保存运行时状态。

## 三层架构

```
                   Git repo
                      │
               config/*.json
               source of truth
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
       normal                     dev
          │                        │
      Nix store               working tree
 immutable snapshot          mutable checkout
          │                        │
       symlink                  symlink
          ▼                        ▼
 ~/.pi/agent/*.json    ~/.pi/agent-dev/*.json
     read-only              writable via repo
```

## 职责划分

| 层面 | 谁负责 |
|------|--------|
| Pi 可执行文件 | Nix (`pkgs.pi-coding-agent`) |
| Node.js / npm | Nix (`pkgs.nodejs`) |
| 系统工具 (git, rg, coreutils) | Nix (runtimePkgs) |
| 配置源码 | Git repo (`config/`) |
| normal 配置 | Nix store snapshot → `~/.pi/agent/*.json` symlink |
| dev 配置 | working tree → `~/.pi/agent-dev/*.json` symlink |
| 扩展安装与版本 | Pi (`packages` in settings.json，安装到 agent dir) |
| 运行时状态 | Pi (`sessions/`, `npm/`, `git/` 等) |

## 项目结构

```
nixpi/
├── flake.nix              # Flake 入口
├── module.nix             # Wrapper 模块：runtime PATH + config symlink
└── config/                # 配置源码 (source of truth)
    ├── settings.json
    ├── pi-fff.json
    ├── hashline.json
    ├── claude-code-style.json
    └── web-search.json
```

## 配置管理模式

### Immutable / normal 模式 (默认)

适用于日常使用和系统集成。

- 配置文件 symlink 到 `/nix/store/.../config/` snapshot
- `~/.pi/agent/*.json` 是只读的声明式配置入口
- 更新 nixpi 后，下一次运行新的 wrapper 会刷新 symlink 到新的 store snapshot
- Pi 仍然可以在 `~/.pi/agent/` 下安装扩展、保存 sessions 等运行时状态
- 不建议在 normal 下运行 `pi install npm:foo` 修改 settings；应修改 `config/settings.json` 后 rebuild/switch

```bash
nix build
./result/bin/pi
# ~/.pi/agent/settings.json -> /nix/store/.../config/settings.json
```

### Mutable / dev 模式

适用于开发调试配置。

- 配置文件 symlink 到 Git working tree
- Pi 修改配置 = 修改 working tree
- `git diff` 可以看到所有变更
- 使用独立的 `~/.pi/agent-dev/`，不污染 normal 状态

```bash
nix run .#pi-dev
# ~/.pi/agent-dev/settings.json -> ~/nixpi/config/settings.json
# /ccstyle 修改 → git diff 可见
```

## 使用方法

### 正常模式 (immutable)

```bash
# 构建 wrapped pi
nix build

# 运行
./result/bin/pi

# 或安装到用户环境
nix profile install .
pi
```

### 开发模式 (mutable)

使用独立的 agent 目录和 symlink 到 working tree：

```bash
# 必须在 nixpi repo 根目录运行
nix run .#pi-dev

# 修改配置后
git diff
git commit
```

### 编辑配置

**正常模式用户**：
- 修改 `config/*.json`
- `nix build` / `nixos-rebuild switch` / `nix profile upgrade`
- 下次运行 `pi` 时，`~/.pi/agent/*.json` 会指向新的 Nix store snapshot

**开发模式用户**：
- 编辑 `config/*.json`，或在 `nix run .#pi-dev` 中运行会改配置的 Pi 命令
- `git diff` 查看变更

### 扩展管理

扩展由 Pi 原生管理。编辑 `config/settings.json`：

```json
{
  "packages": [
    "npm:@firstpick/pi-themes-bundle",
    "npm:pi-cc-extensions",
    "npm:@ff-labs/pi-fff",
    "npm:pi-hashline-edit",
    "npm:pi-web-access"
  ]
}
```

Pi 启动时会自动安装配置中新声明但本地缺失的扩展。如需 pin 版本，加 `@x.y.z`。

`pi update --extensions` 只用于把已安装且未 pin 的扩展升级到 npm 最新版；新增扩展不需要手动 update。

## 工作流示例

### 场景 1：日常使用

```bash
# 首次安装
nix profile install github:your-user/nixpi
pi

# 配置来自 Nix store symlink
# Pi 自动安装 settings.json 里声明但缺失的扩展
```

### 场景 2：调整配置

```bash
# 进入开发模式
cd ~/nixpi
nix run .#pi-dev

# 在 Pi 里运行 /ccstyle 或其他修改配置的命令

# 查看变更
git diff config/claude-code-style.json

# 提交
git add config/
git commit -m "update ccstyle config"
git push
```

### 场景 3：更新到新配置版本

```bash
cd ~/nixpi
git pull

# 重新构建或切换 Nix generation
nix build
# 或 nixos-rebuild switch / nix profile upgrade

# 下次运行 pi 时，配置 symlink 会刷新到新的 /nix/store snapshot
```

## Overlay

将 wrapped pi 注入 nixpkgs：

```nix
{
  inputs.nixpi.url = "github:your-user/nixpi";

  nixpkgs.overlays = [ nixpi.overlays.default ];
}
```

之后 `pkgs.pi` 即为带完整 runtime PATH 的 wrapped 版本。

## 故障排除

### 扩展未安装

```bash
# 检查 settings.json 指向
readlink ~/.pi/agent/settings.json
cat ~/.pi/agent/settings.json

# 手动触发安装
pi --packages-install
```

### 配置没有更新

```bash
# 检查 symlink 是否指向当前 generation 的 /nix/store snapshot
readlink ~/.pi/agent/settings.json

# 重新构建 / 切换 generation 后再运行 pi
nix build
./result/bin/pi
```

### Node/npm 不在 PATH

```bash
# Nix wrapper 应该自动提供 node
which node
node --version
```

### 扩展加载失败

```bash
pi /extensions
```

## License

MIT
