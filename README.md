# nixpi — Nix-native Pi Runtime Wrapper

使用 Nix 为 [Pi coding agent](https://github.com/earendil-works/pi) 提供稳定的运行时环境。Nix 负责可执行文件和系统依赖；Git 仓库作为配置 source of truth；Pi 在 agent dir 下安装扩展并保存运行时状态。

## 架构

```
nixos-config/
└── components/nixpi/     # git submodule
    ├── flake.nix
    ├── module.nix
    └── config/           # source of truth
        ├── settings.json
        ├── pi-fff.json
        ├── hashline.json
        ├── claude-code-style.json
        └── web-search.json
              │
              │ symlink
              ▼
        ~/.pi/agent/*.json   (mutable, Pi 可直接修改)
```

## 职责划分

| 层面 | 谁负责 |
|------|--------|
| Pi 可执行文件 | Nix (`pkgs.pi-coding-agent`) |
| Node.js / npm | Nix (`pkgs.nodejs`) |
| 系统工具 (git, rg, coreutils) | Nix (runtimePkgs) |
| 配置源码 | Git repo (`config/`) |
| 配置部署 | symlink 从 working tree → `~/.pi/agent/*.json` |
| 扩展安装与版本 | Pi (`packages` in settings.json，自动安装) |
| 运行时状态 | Pi (`sessions/`, `npm/`, `git/` 等) |

## 使用方法

作为 submodule 集成到 nixos-config：

```nix
# flake.nix
{
  inputs = {
    self.submodules = true;

    nixpi = {
      url = "path:./components/nixpi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

```nix
# modules/nixos/server/pi.nix
{ inputs, ... }:
{
  nixpkgs.overlays = [ inputs.nixpi.overlays.default ];
}
```

之后 `pkgs.pi` 即为带完整 runtime PATH 的 wrapped 版本。

## 配置管理

配置文件从 checkout 的 `config/` 目录 symlink 到 `~/.pi/agent/`。默认 checkout
位置是 `~/nixos-config/components/nixpi/config`；在其他位置使用时，设置
`NIXPI_CONFIG_DIR`：

```bash
export NIXPI_CONFIG_DIR="$HOME/src/nixos-config/components/nixpi/config"
```

只有找不到该目录时，wrapper 才会使用 Nix store 中的只读快照，并向 stderr 输出提示。
正常开发使用工作树路径，因此：

- Pi 可以直接修改这些 JSON 文件
- 修改立即出现在 `git diff`
- 新增扩展：编辑 `config/settings.json` → Pi 启动时自动安装

```bash
# 修改配置
vim config/settings.json

# 查看变更
git diff

# 提交
git add config/
git commit -m "update pi config"
```

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

## Overlay

将 wrapped pi 注入 nixpkgs：

```nix
{
  nixpkgs.overlays = [ nixpi.overlays.default ];
}
```

## 故障排除

### 扩展未安装

```bash
# 检查 settings.json 指向
readlink ~/.pi/agent/settings.json
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
