# AJohn-Skills

个人 skill 仓库，跨工具统一管理（Claude Code、Codex 等）。

## 结构

```
AJohn-Skills/
├── install.sh          # 安装 / 移除符号链接
├── template/SKILL.md   # 新建 skill 的模板
└── skills/             # 所有 skill 的唯一真源
    └── <skill-name>/
        └── SKILL.md    # 兼容 Agent Skills 标准格式，Claude 与 Codex 通用
```

## 使用

```bash
git clone https://github.com/zzyAJohn/AJohn-Skills.git ~/AJohn-Skills
~/AJohn-Skills/install.sh            # 装机后初始化（也用于同步更新）
~/AJohn-Skills/install.sh --remove   # 移除所有指向本仓库的链接
```

安装后，`skills/` 下每个目录会以符号链接出现在：

- `~/.claude/skills/<name>` （Claude Code）
- `~/.codex/skills/<name>` （Codex）

在仓库里修改 skill 即时生效，无需重新安装；新增 skill 后重跑一次 `install.sh`。

## 新增 skill

1. 复制 `template/` 为 `skills/<skill-name>/`
2. 填写 `SKILL.md`（frontmatter 至少包含 `name` 和 `description`）
3. 跑 `./install.sh`，提交并推送

## 约定

- 某个 skill 只想给部分工具用时，改 `install.sh` 里的 `EXCLUDES`
- 目标目录下已存在同名真实目录时，脚本会警告并跳过，不覆盖——需手动迁移
