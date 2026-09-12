# nixpi — Nix-native Pi Runtime Wrapper

使用 Nix 为 [Pi coding agent](https://github.com/can1357/pi-coding-agent) 提供稳定的运行时环境。Nix 负责可执行文件和系统依赖；扩展安装、`settings.json`、插件配置全部归 Pi 原生管理。

## 职责划分

```
         nixpi (Nix)
              │
     ┌────────┴────────┐
     ▼                 ▼
  Pi executable     runtime
  /nix/store        node / npm
                    rg / git / …
     │
     ▼
  ~/.pi/agent          ← 全部由 Pi 拥有
  ├── settings.json    ← Pi
  ├── npm/             ← Pi / npm
  ├── hashline.json    ← extension
  ├── web-search.json  ← extension
  └── sessions/        ← Pi
```

| 层面 | 谁负责 |
|------|--------|
| Pi 可执行文件 | Nix (`pkgs.pi-coding-agent`) |
| Node.js / npm | Nix (`pkgs.nodejs`) |
| 系统工具 (rg, git, coreutils) | Nix (integrations 声明) |
| 扩展安装与版本 | Pi (`packages` in settings.json) |
| settings.json | Pi (writable, `~/.pi/agent/`) |
| 插件配置文件 | 扩展自身 (writable) |
| 环境变量 (PI_FFF_MODE 等) | Nix (integrations 声明) |

## 项目结构

```
nixpi/
├── flake.nix              # Flake 入口
├── module.nix             # Wrapper 模块：runtime PATH + env
└── integrations/          # 每个扩展的 Nix 侧集成声明
    ├── default.nix
    ├── pi-cc-extensions.nix # （目前无 Nix 需求，占位）
    ├── pi-fff.nix          # env: PI_FFF_MODE=override
    ├── pi-hashline-edit.nix # runtimePkgs: ripgrep
    └── pi-web-access.nix   # runtimePkgs: git
```

## 使用方法

### 构建和运行

```bash
# 构建 wrapped pi
nix build

# 运行
./result/bin/pi

# 或安装到用户环境
nix profile install .
pi
```

### 开发模式

使用独立的 agent 目录 (`~/.pi/agent-dev`)，不影响日常环境：

```bash
nix run .#pi-dev
```

### 配置扩展

扩展由 Pi 原生管理。首次启动前，编辑 `~/.pi/agent/settings.json`：

```json
{
  "packages": [
    "npm:@firstpick/pi-themes-bundle@0.1.6",
    "npm:pi-cc-extensions@0.8.70",
    "npm:@ff-labs/pi-fff@0.10.6",
    "npm:pi-hashline-edit@0.8.3",
    "npm:pi-web-access@0.13.0"
  ]
}
```

Pi 会在启动时自动安装这些扩展。带版本号的包会被 pin 到指定版本。

## Integrations

每个 integration 文件描述扩展需要的 **Nix 侧** 需求：

| Integration | env | runtimePkgs |
|-------------|-----|-------------|
| `pi-cc-extensions` | — | —（占位，目前无 Nix 需求） |
| `pi-fff` | `PI_FFF_MODE=override` | — |
| `pi-hashline-edit` | — | `ripgrep` |
| `pi-web-access` | — | `git` |

添加新集成：在 `integrations/` 下创建 `.nix` 文件并加入 `default.nix` 列表。

## 为什么不用 Nix 管理 settings.json？

Pi 的 `pi install` / `pi remove` 会直接持久化到 `settings.json`。如果 Nix 生成只读的 `settings.json` symlink 到 `/nix/store`，会导致：

- `pi install` → EROFS (只读文件系统)
- 扩展想修改配置 → 失败
- 双 ownership 冲突

让 Pi 完全拥有 `~/.pi/agent/` 可以避免这些问题，同时 Nix 仍确保运行时环境稳定可复现。

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
