# ClipBar

ClipBar 是一个 SwiftUI 原生 macOS 菜单栏剪切板管理工具。它支持后台记录文本和图片、搜索文本历史、固定最多 9 条常用内容，并可选择复制回剪切板或自动粘贴到前台 App。

## 发布状态

这是一个开源源码发布版本。当前仓库提供完整源码和本地构建脚本，但暂不提供 Developer ID 签名和 Apple notarization 公证后的安装包。

因此：

- 开发者可以 clone 源码后自行构建和安装。
- 未签名或临时签名的 App 可能被 macOS Gatekeeper 拦截。
- 面向普通用户的正式下载包需要后续完成 Developer ID 签名、公证和打包流程。

## 系统要求

- macOS 14 或更高版本
- Xcode / Swift 6 toolchain
- 如需自动粘贴到前台 App，需要授予 macOS 辅助功能权限

确认 Xcode 环境：

```bash
xcode-select -p
xcodebuild -version
```

`xcode-select -p` 应输出类似：

```text
/Applications/Xcode.app/Contents/Developer
```

## 从源码安装

克隆仓库后进入项目目录：

```bash
git clone https://github.com/Mark-Zzm/ClipBar.git
cd ClipBar
```

第一次安装到“应用程序”：

```bash
Scripts/install_clipbar_app.sh
```

脚本会生成 release 版本的 `ClipBar.app`，安装到：

```text
/Applications/ClipBar.app
```

以后请从“应用程序”里的 ClipBar 打开，不要从 Xcode 或项目 `build` 文件夹打开。macOS 辅助功能权限会绑定到 `/Applications/ClipBar.app`，这是最稳定的长期使用方式。

更新已安装版本：

```bash
Scripts/update_clipbar_app.sh
```

如果更新后直接粘贴失效，请到系统设置重新允许 `/Applications/ClipBar.app` 的辅助功能权限。

## 开发构建

SwiftPM 构建：

```bash
swift build
```

手动生成项目目录内的 App 包：

```bash
Scripts/build_clipbar_app.sh
```

生成后运行：

```bash
open build/ClipBar.app
```

开发期间也可以直接运行，但不建议用它测试辅助功能权限：

```bash
swift run ClipBar
```

运行后，顶部菜单栏会出现剪切板图标。点击图标打开面板；复制文本或图片后，App 会在运行期间持续记录。

## 使用

- 默认点击历史记录会直接粘贴到唤起 ClipBar 前的前台 App。
- 在设置窗口里可以把点击行为切换为“只复制到剪切板”。
- 设置窗口可从面板左下角“设置...”打开。
- 点击历史记录右侧的固定按钮，可以选择固定到 1-9 的具体位置。
- 主面板切到“固定”分类后，可直接拖拽固定内容调整 1-9 固定位顺序。
- 设置窗口里的“固定内容”区域也支持拖拽调整 1-9 固定位顺序。
- 固定内容最多 9 条，默认使用 `Option + 1-9` 复用，避免和搜索框输入数字冲突。
- 固定内容快捷键可在设置里改为 `Control + 1-9`、`Command + 1-9`、`Control + Option + 1-9`、自定义每个固定位或关闭。
- 默认一键唤起面板快捷键是 `Control + Option + Space`，也可在设置里改成自定义快捷键或关闭。
- 自定义快捷键时，点击录制框后按下组合键，全部按键第一次完全松开时完成录制；最多支持三键组合。
- 直接粘贴需要 macOS 辅助功能权限。长期使用时请给 `/Applications/ClipBar.app` 授权；授权后退出并重新打开 ClipBar。
- 点击主面板左下角“退出”可以完全结束 ClipBar。

## 隐私与数据

ClipBar 是本地剪切板工具，当前版本不提供云同步，也不会主动上传剪切板内容。

- 文本和图片历史保存在本机 Application Support 目录。
- 默认保存最近 1000 条普通历史。
- 固定内容不因普通历史清理而删除。
- 图片记录会在本机保存对应文件引用。
- 自动粘贴需要辅助功能权限；没有权限时会降级为只复制到剪切板。

剪切板内容可能包含密码、验证码、密钥、私人图片或其他敏感信息。长期运行前请确认你能接受本地保存剪切板历史这一行为。

## 验证

项目提供了一个独立验证目标：

```bash
swift run CoreChecks
swift build
Scripts/build_clipbar_app.sh
```

`CoreChecks` 覆盖核心规则：重复内容跳过、文本搜索、固定快捷键、历史上限清理、清空历史保留固定内容。

## 第一版范围

- 只记录文本和图片。
- 所有数据只保存在本机 Application Support 目录。
- 默认保存最近 1000 条普通历史，固定内容不因普通历史清理而删除。
- 自动粘贴需要 macOS 辅助功能权限；没有权限时会降级为复制到剪切板。
- 暂不包含签名分发、App Store、云同步、OCR、富文本或文件复制记录。

## 反馈

Bug、建议和功能请求请通过 GitHub Issues 提交：

```text
https://github.com/Mark-Zzm/ClipBar/issues
```

## License

ClipBar is released under the MIT License. See [LICENSE](LICENSE) for details.
