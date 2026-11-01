# ASHWAKE：安卓手机首次导入与更新

适用：Android 12 + Godot 4.7 Android Editor。本项目已用 Godot 4.7.2 检查。

**APK 是成品，不是源码。** 这套流程把 GitHub [公开源码仓库](https://github.com/qq2422271727-hue/AICG) 下载到手机，然后用 Godot 运行。以后更新源码只需拉取，不需要重新安装 APK；已经安装的独立 APK 不会随源码更新。任何人都能查看这个公开仓库，请勿提交密码或私人文件。

## 1. 安装 Termux（只做一次）

从 [Termux 官方推荐的 F-Droid 页面](https://f-droid.org/en/packages/com.termux/) 下载并安装 Termux。页面有直接下载 APK 的入口，不必先装 F-Droid 客户端。也可使用 [Termux 官方 GitHub Releases](https://github.com/termux/termux-app/releases)。不要使用网盘、群聊转发包；Termux 与插件要使用同一来源。

打开 Termux，每次粘贴下面的一行，再按回车；上一条完成后才执行下一条：

```sh
pkg update && pkg upgrade
pkg install git
termux-setup-storage
```

出现确认安装时输入 `y` 并回车。存储权限弹窗选择允许。如果拒绝过权限，到安卓设置 → 应用 → Termux → 权限中允许文件访问，再执行最后一行。

## 2. 下载公开源码（无需 GitHub 登录）

前提：仓库根目录能看到 `project.godot`。在 Termux 执行：

```sh
mkdir -p ~/storage/shared/Documents
git clone -c core.filemode=false -c core.symlinks=false https://github.com/qq2422271727-hue/AICG.git ~/storage/shared/Documents/ASHWAKE
```

下载位置是手机“内部存储 → Documents → ASHWAKE”，不是 Termux 私有目录，也不是 `Android/data`。

若提示 `ASHWAKE` 已存在且不为空：**不要删除、不要覆盖。** 先用文件管理器把原文件夹改名备份，再重新下载；或让助手根据错误信息检查。

### 仅在出现 `detected dubious ownership` 时

安卓共享存储的文件所有者可能与 Termux 不同。确认这确实是你刚克隆的项目，再逐行执行：

```sh
cd ~/storage/shared/Documents/ASHWAKE
pwd -P
git config --global --add safe.directory "$(pwd -P)"
git status --short
```

`pwd -P` 应显示你这个 ASHWAKE 文件夹的真实路径。只信任此路径，**不要设置 `safe.directory '*'`**。这会允许 Git 信任此项目的配置，只应对你自己控制的项目使用。

共享存储不支持完整的 Unix 权限和符号链接；上面的克隆选项不依赖它们。本项目目前只有普通源码/资源文件，没有符号链接、需要执行权限的构建脚本或 Git LFS。若出现 `Permission denied`、`Operation not permitted` 或 Git 锁文件错误，停止并保留错误文字，不要反复重装或清空文件夹。

## 3. 在 Godot 打开

1. 给 Godot Android Editor 所需的文件访问权限（若系统提供“所有文件访问权限”，允许后重试）。
2. Godot 项目管理器 → **Import / 导入**。
3. 选择“内部存储 → Documents → ASHWAKE → `project.godot`”，导入并编辑。
4. 等资源导入结束，点击右上角 **▶ 运行项目**。

以后一直打开这一份项目，不要同时编辑 ZIP 解压出来的另一份。第一次运行或更新后导入资源需要一点时间。

## 4. 以后拿到新版本

先停止游戏并退出 Godot 项目编辑界面，避免编辑器和 Git 同时写文件。打开 Termux：

```sh
cd ~/storage/shared/Documents/ASHWAKE
git status --short
```

如果没有列出文件，继续：

```sh
git pull --ff-only
```

看到成功更新，或 `Already up to date.`，再重新打开 Godot 项目，等导入完成，点 ▶。`--ff-only` 不会自动生成合并提交；历史发生分叉时会停止。

如果 `git status --short` 列出了文件，或拉取出现 `would be overwritten` / `Not possible to fast-forward`：**先停下，不要强制更新。** Godot 修改项目设置也会产生本地改动，不一定是你改过代码。

## 5. 手机改过内容怎么办

建议初期手机只运行和试玩，改动由开发端统一提交。手机确实改过内容时：

1. 退出 Godot，使用文件管理器把整个 `Documents/ASHWAKE` 文件夹复制为一个新名字，例如 `ASHWAKE_手机备份_2026-11-01`。打开备份检查你改过的脚本还在。
2. 把 `git status --short` 的结果和不含敏感信息的错误文字发给助手，再决定保留、提交或合并哪些改动。
3. 不要执行 `git reset --hard`、`git clean -fd`，也不要删除项目后重来。不要把备份文件夹放进项目内。

`.gitignore` 已排除 `.godot` 缓存、导出 APK、签名密钥和常见凭证；保留 `.gd.uid`、资源 `.import` 设置、`project.godot`、`export_presets.cfg`。忽略规则并不能检查所有秘密，也不能删除已进入 Git 历史的秘密；公开仓库的文件对所有人可见，更不能存放凭证。

## 官方依据

- [Godot Android Editor：文件权限与 Termux 同步](https://docs.godotengine.org/en/stable/tutorials/editor/using_the_android_editor.html)
- [Godot 版本控制：应排除的缓存及导出设置](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html)
- [Termux 安装来源](https://github.com/termux/termux-app#installation)
- [Termux 存储访问说明](https://github.com/termux/termux-tools/blob/master/doc/termux.1.md.in)
- [Git 安全目录与文件系统配置](https://git-scm.com/docs/git-config)
- [Git pull 的快进更新](https://git-scm.com/docs/git-pull)

此流程依据官方文档和项目文件检查编写；尚未在你的手机上实际执行，具体权限弹窗可能因机型不同而变化。
