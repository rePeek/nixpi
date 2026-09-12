# nixpi — Nix-native Pi Runtime Wrapper

使用 Nix 为 [Pi coding agent](https://github.com/earendil-works/pi) 提供稳定的运行时环境。Nix 负责可执行文件和系统依赖；Git 仓库作为配置 source of truth；Pi 在运行时拥有可写的 `~/.pi/agent/`。

## 三层架构

```
                    nixpi repo (Git)
                         │
                    config/*.json
                    source of truth
                         │
          ┌──────────────┴──────────────┐
          │                             │
       dev mode                    normal mode
          │                             │
          │                             ▼
          │                      /nix/store/.../config
          │                      immutable snapshot
          │                             │
          │                             │ bootstrap copy
          │                             │ (only if missing)
          │                             ▼
          ▼                        ~/.pi/agent/
 ~/.pi/agent-dev/                  writable local state
 direct symlink                    (Pi can modify)
 writable via repo                 changes don't persist to Git
 changes → git diff
```

## 职责划分

| 层面 | 谁负责 |
|------|--------|
| Pi 可执行文件 | Nix (`pkgs.pi-coding-agent`) |
| Node.js / npm | Nix (`pkgs.nodejs`) |
| 系统工具 (git, rg, coreutils) | Nix (runtimePkgs) |
| 配置源码 | Git repo (`config/`) |
| 扩展安装与版本 | Pi (`packages` in settings.json) |
| 运行时配置 | Pi (writable `~/.pi/agent/`) |

## 项目结构

```
nixpi/
├── flake.nix              # Flake 入口
├── module.nix             # Wrapper 模块：runtime PATH + config management
└── config/                # 配置源码 (source of truth)
    ├── settings.json
    ├── pi-fff.json
    ├── hashline.json
    ├── claude-code-style.json
    └── web-search.json
```

## 配置管理模式

### Seed 模式 (默认)

适用于生产环境或日常使用。

- 首次运行时，从 `/nix/store` snapshot 复制配置到 `~/.pi/agent/`
- Pi 可以自由修改配置
- 修改不会回写到 Git repo
- 下次 `nix build` 会生成新的 snapshot，但不会覆盖已存在的配置

```bash
nix build
./result/bin/pi
# ~/.pi/agent/settings.json 现在是 writable copy
```

### Mutable 模式

适用于开发调试配置。

- 直接 symlink 到 Git working tree
- Pi 修改配置 = 修改 working tree
- `git diff` 可以看到所有变更
- 修改会持久化到 Git

```bash
nix run .#pi-dev
# ~/.pi/agent-dev/settings.json -> ~/nixpi/config/settings.json
# /ccstyle 修改 → git diff 可见
```

## 使用方法

### 正常模式 (seed)

```bash
# 构建 wrapped pi
nix build

# 运行 (首次会 bootstrap 配置)
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
- 直接编辑 `~/.pi/agent/*.json`
- 或运行 `pi` 让扩展修改

**开发模式用户**：
- 编辑 `config/*.json`
- 运行 `nix run .#pi-dev`
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

Pi 会在启动时自动安装这些扩展。如需 pin 版本，加 `@x.y.z`。


## 工作流示例

### 场景 1：日常使用

```bash
# 首次安装
nix profile install github:your-user/nixpi
pi

# Pi 自动安装扩展，配置已经 bootstrap 好
# 正常使用，Pi 可以修改配置
```

### 场景 2：调整配置

```bash
# 进入开发模式
cd ~/nixpi
nix run .#pi-dev

# 运行 /ccstyle 或其他修改配置的命令
pi
# 在 Pi 里运行 /ccstyle

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

# 重新构建
nix build

# 下次运行 pi 时，新的配置会 bootstrap 到 ~/.pi/agent/
# (只影响不存在的文件，不会覆盖你的修改)
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
# 检查 settings.json
cat ~/.pi/agent/settings.json

# 手动触发安装
pi --packages-install
```

### 配置没有更新

Seed 模式只在文件不存在时 bootstrap。如果需要重置：

```bash
rm ~/.pi/agent/settings.json
# 下次运行 pi 会重新 bootstrap
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
