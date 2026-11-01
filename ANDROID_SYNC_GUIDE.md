# ASHWAKE：安卓手机首次导入与更新

> 更新提示：新版源码正式发布到公开仓库的 `main` 分支后，已有 GitSync 用户可安全拉取；审阅分支上的未合并改动不会自动出现在 `main`。
> GitSync 用户继续打开 `Documents/AICG/project.godot`。独立提供或从 GitHub 下载的源码 ZIP 请解压到新文件夹；ZIP 解压目录不是 Git 克隆，不会通过 Pull 更新。
> 请勿把 ZIP 覆盖进 GitSync 管理的目录，也不要覆盖手机本地改动。源码发布、导出或回归通过均不代表已完成安卓实机测试；已安装的独立 APK 不会随源码更新。

适用：Android 12 + Godot 4.7 Android Editor。本项目已用 Godot 4.7.2 检查。

**APK 是成品，不是源码。** 这套流程把 GitHub [公开源码仓库](https://github.com/qq2422271727-hue/AICG) 下载到手机，然后用 Godot 运行。以后更新源码只需拉取，不需要重新安装 APK；已经安装的独立 APK 不会随源码更新。任何人都能查看这个公开仓库，请勿提交密码或私人文件。

## 推荐：GitSync 图形界面，不用 Termux

第一次下载源码，之后只手动拉取更新。**不启用自动同步，也不需要安装 Godot Git 插件。** 手机先作为试玩端，代码由开发端提交到 GitHub。

### 1. 安装与认证选择（只做一次）

1. 从 [Google Play](https://play.google.com/store/apps/details?id=com.viscouspot.gitsync) 或 [F-Droid](https://f-droid.org/packages/com.viscouspot.gitsync/) 安装 **GitSync**，包名是 `com.viscouspot.gitsync`；不要使用来历不明的安装包。
2. 初次设置选择 **Client mode / 客户端模式**，不要选 Sync mode。保持定时同步、应用打开/关闭触发同步等自动功能关闭；本流程不需要为自动同步开启无障碍服务。
3. GitSync 会申请 **All files access / 所有文件访问权限**。这是一项较广的共享存储读写权限，不只限于 AICG 文件夹；确认信任该应用后再允许。不愿授权就先停止，不要绕过系统限制。
4. 本仓库公开，可先尝试用下方 HTTPS 地址直接克隆；**若当前版本提供免登录克隆入口，就不必授权 GitHub 账号**。若设置流程要求登录，按官方教程选择 **GitHub → OAuth**，在浏览器的 GitHub 登录页登录，检查授权对象和权限后确认，再返回 GitSync。不要为此生成 PAT，也不要把密码、授权码或令牌发给助手；遇到不确定的授权页可先取消。
5. 若要求填写作者信息，使用自己的 GitHub 用户名；邮箱可从 GitHub 邮箱设置复制自己的隐私 `noreply` 地址，不要编造。仅拉取不会发布作者提交信息。

公开仓库的 Git 克隆/拉取本身不要求登录；GitSync 官方教程展示了 OAuth 流程，但这里未实测当前安装版本的免登录入口，不能保证按钮位置或可用性。OAuth 是备用认证方式，不是公开仓库的硬性要求。

### 2. 把 AICG 下载到 Documents

1. 在 GitSync 的克隆流程选择仓库 **`qq2422271727-hue/AICG`**；如需填地址，使用 `https://github.com/qq2422271727-hue/AICG.git`。
2. 选择 **Nested clone / 嵌套克隆**，然后选择内部存储的 **Documents** 文件夹作为父目录；不要选 Direct clone。
3. 等克隆完成。应得到 **`Documents/AICG/project.godot`**，分支为 **`main`**。不要把源码放进 `Android/data`。

如果已有 `Documents/AICG`，不要接受覆盖或清空提示。先退出 Godot，备份原文件夹，并把当前界面或错误文字发给助手确认。旧 ZIP 项目可以保留为备份，不要让两个同步工具管理同一文件夹。

### 3. 在手机 Godot 导入

打开 Godot 项目管理器 → **Import / 导入** → 内部存储 → **Documents → AICG → `project.godot`** → 编辑。等资源导入完成，点 **▶ 运行项目**。若看不到文件，检查 Godot 的文件访问权限。

以后一直打开这份 `Documents/AICG` 项目，不要误开旧 ZIP 解压出来的另一份。

### 4. 以后更新，只点 Pull Changes

1. 停止游戏，保存需要保留的编辑，**退出 Godot 项目并关闭 Godot**。
2. 打开 GitSync，选中 AICG / `main`，先检查本地改动；若有未提交文件、本地提交或冲突，先停下备份，不要继续拉取。
3. 本地没有改动时，手动选择 **Pull Changes / 拉取更改**。它会下载并合并远端更新，不等同于 Termux 的 `--ff-only`；因此这里要求手机暂不提交代码。
4. 看到成功或已是最新，再打开同一份 Godot 项目，等待导入后运行。

**不要点 Force Pull、Force Push、Push Changes 或 Sync All Changes。** Force Pull 可能丢弃手机改动，Force Push 可能改写远端历史；Sync All Changes 会先拉取再上传本地改动，不是单纯下载。也不要为解除限制而随手提交或丢弃文件。

日常源码更新不用重新下载源码 ZIP，也不用重新下载或安装游戏 APK；已安装的独立 APK 不会随源码更新，试玩新代码请从 Godot 运行。

### 5. 出错或手机改过文件

- **有本地改动或冲突：** 关闭 Godot，先把整个 `Documents/AICG` 复制到项目外的备份文件夹，检查修改过的脚本还在；把改动列表和不含敏感信息的错误文字发给助手。
- **权限或文件夹错误：** 确认两个应用指向同一份 `Documents/AICG`，检查 Android 设置里的文件权限。不要删除 `.git`、清空项目或反复重装。
- **登录、网络或拉取失败：** 保留原文件，记录 GitSync 版本和完整错误；截图遮住邮箱、令牌、授权码。不确定操作时先停，不用 Force Pull“修复”。

Godot 修改项目设置也会产生本地改动，不一定是你改过代码。公开仓库不能存放密码、签名密钥或私人文件。

## 备用：Termux 命令行

只有你愿意使用终端时再选本方案；已经使用上面的 GitSync 就不必执行。两种方案二选一，不要同时同步同一项目。下面保留原来的 `Documents/ASHWAKE` 路径，区别于 GitSync 的 `Documents/AICG`。

### 1. 安装 Termux（只做一次）

从 [Termux 官方推荐的 F-Droid 页面](https://f-droid.org/en/packages/com.termux/) 下载并安装 Termux。页面有直接下载 APK 的入口，不必先装 F-Droid 客户端。也可使用 [Termux 官方 GitHub Releases](https://github.com/termux/termux-app/releases)。不要使用网盘、群聊转发包；Termux 与插件要使用同一来源。

打开 Termux，每次粘贴下面的一行，再按回车；上一条完成后才执行下一条：

```sh
pkg update && pkg upgrade
pkg install git
termux-setup-storage
```

出现确认安装时输入 `y` 并回车。存储权限弹窗选择允许。如果拒绝过权限，到安卓设置 → 应用 → Termux → 权限中允许文件访问，再执行最后一行。

### 2. 下载公开源码（无需 GitHub 登录）

前提：仓库根目录能看到 `project.godot`。在 Termux 执行：

```sh
mkdir -p ~/storage/shared/Documents
git clone -c core.filemode=false -c core.symlinks=false https://github.com/qq2422271727-hue/AICG.git ~/storage/shared/Documents/ASHWAKE
```

下载位置是手机“内部存储 → Documents → ASHWAKE”，不是 Termux 私有目录，也不是 `Android/data`。

若提示 `ASHWAKE` 已存在且不为空：**不要删除、不要覆盖。** 先用文件管理器把原文件夹改名备份，再重新下载；或让助手根据错误信息检查。

#### 仅在出现 `detected dubious ownership` 时

安卓共享存储的文件所有者可能与 Termux 不同。确认这确实是你刚克隆的项目，再逐行执行：

```sh
cd ~/storage/shared/Documents/ASHWAKE
pwd -P
git config --global --add safe.directory "$(pwd -P)"
git status --short
```

`pwd -P` 应显示你这个 ASHWAKE 文件夹的真实路径。只信任此路径，**不要设置 `safe.directory '*'`**。这会允许 Git 信任此项目的配置，只应对你自己控制的项目使用。

共享存储不支持完整的 Unix 权限和符号链接；上面的克隆选项不依赖它们。本项目目前只有普通源码/资源文件，没有符号链接、需要执行权限的构建脚本或 Git LFS。若出现 `Permission denied`、`Operation not permitted` 或 Git 锁文件错误，停止并保留错误文字，不要反复重装或清空文件夹。

### 3. 在 Godot 打开

1. 给 Godot Android Editor 所需的文件访问权限（若系统提供“所有文件访问权限”，允许后重试）。
2. Godot 项目管理器 → **Import / 导入**。
3. 选择“内部存储 → Documents → ASHWAKE → `project.godot`”，导入并编辑。
4. 等资源导入结束，点击右上角 **▶ 运行项目**。

以后一直打开这一份项目，不要同时编辑 ZIP 解压出来的另一份。第一次运行或更新后导入资源需要一点时间。

### 4. 以后拿到新版本

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

### 5. 手机改过内容怎么办

建议初期手机只运行和试玩，改动由开发端统一提交。手机确实改过内容时：

1. 退出 Godot，使用文件管理器把整个 `Documents/ASHWAKE` 文件夹复制为一个新名字，例如 `ASHWAKE_手机备份_2026-11-01`。打开备份检查你改过的脚本还在。
2. 把 `git status --short` 的结果和不含敏感信息的错误文字发给助手，再决定保留、提交或合并哪些改动。
3. 不要执行 `git reset --hard`、`git clean -fd`，也不要删除项目后重来。不要把备份文件夹放进项目内。

`.gitignore` 已排除 `.godot` 缓存、导出 APK、签名密钥和常见凭证；保留 `.gd.uid`、资源 `.import` 设置、`project.godot`、`export_presets.cfg`。忽略规则并不能检查所有秘密，也不能删除已进入 Git 历史的秘密；公开仓库的文件对所有人可见，更不能存放凭证。

## 官方依据

- [GitSync 官方项目与安装信息](https://github.com/ViscousPot/GitSync)
- [GitSync 官方作者教程：Android 权限、OAuth 与 Nested clone](https://viscouspotenti.al/posts/gitsync-all-devices-tutorial)（其中自动同步用于笔记场景，本游戏不启用）
- [GitSync Client Mode：Pull、Sync All 与强制操作的区别](https://gitsync.viscouspotenti.al/wiki/sync-options/in-app/client-mode)
- [Godot Android Editor：文件权限与 Termux 同步](https://docs.godotengine.org/en/stable/tutorials/editor/using_the_android_editor.html)
- [Godot 版本控制：应排除的缓存及导出设置](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html)
- [Termux 安装来源](https://github.com/termux/termux-app#installation)
- [Termux 存储访问说明](https://github.com/termux/termux-tools/blob/master/doc/termux.1.md.in)
- [Git 安全目录与文件系统配置](https://git-scm.com/docs/git-config)
- [Git pull 的快进更新](https://git-scm.com/docs/git-pull)

此流程依据官方文档和项目文件检查编写；**尚未在 Android 实机上测试 GitSync 与本项目的同步，也没有替你操作手机**。按钮译名和权限弹窗可能随版本、机型变化；界面不一致时先发截图确认。
