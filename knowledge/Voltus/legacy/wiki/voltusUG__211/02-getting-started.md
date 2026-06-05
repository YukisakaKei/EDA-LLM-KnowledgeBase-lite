---
source: knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl | entries: [0018, 0019, 0020, 0021, 0022, 0023, 0024, 0025, 0026, 0027, 0028, 0029]
---

# Getting Started — Voltus 快速入门

## 产品与安装信息

产品、版本和安装信息见安装包内的 README 文件，也可在 downloads.cadence.com 下载前预览。

---

## 运行时环境设置

将以下路径加入 shell 启动脚本：

```bash
# 必须：将可执行文件加入 PATH
export PATH=$PATH:install_dir/bin

# 可选：man page 路径
export MANPATH=$MANPATH:install_dir/share/voltus/man           # legacy man pages
export MANPATH=$MANPATH:install_dir/share/voltus/stylus/man    # Common UI man pages
export MANPATH=$MANPATH:install_dir/share/tcltools/man         # Tcl man pages
```

支持的平台列表见 README 文件。

---

## 临时文件位置

每次 Voltus 会话启动时自动创建临时目录，命名格式：

```
voltus_temp_[pid]_[hostname]_[user]_xxxxxx
```

- 默认位置：`/tmp`
- 若设置了环境变量 `TMPDIR`，则在 `$TMPDIR` 下创建
- 会话正常退出或收到可捕获信号（如 SIGSEGV）时自动删除

---

## 启动 Voltus

### 启动命令

```bash
voltus              # GUI 模式启动（默认），自动创建 log 和 cmd 文件
voltus -no_gui      # 非 GUI 模式（batch/脚本模式）
```

系统按许可功能从高到低依次尝试 checkout：
- Voltus IC Power Integrity Solution XL（优先）
- Voltus IC Power Integrity Solution L

### Voltus Console

- **非 GUI 模式**：启动 Voltus 的 shell 窗口即为 console，提示符为 `voltus>`
- **GUI 模式**：console 嵌入在主窗口内
- 在 console 中执行其他操作（如 vi）时，Voltus 会话暂停
- `Ctrl-Z` 挂起会话，`fg` 恢复

---

## Tab 补全

Voltus console 支持 Tab 键补全，覆盖三类场景：

| 场景 | 示例 |
|------|------|
| 命令名补全 | `set_power_<Tab>` → 列出所有匹配命令 |
| 参数名补全 | `set_pg_library_mode -enable_m<Tab>` → 补全参数名 |
| Enum 值补全 | `set_pg_library_mode -cell_type <Tab>` → 列出可选值 |

- 查看命令所有参数：输入命令名后接 `-` 再按 Tab
- 其他上下文下 Tab 补全 Unix 文件/目录名
- `man` 命令的第一个参数也支持 Tab 补全：`man set_power_p<Tab>`

---

## 命令行编辑

Voltus console 提供类 GNU Emacs 的行编辑功能，编辑命令区分大小写。

**常用控制字符（`^` = Ctrl）：**

| 按键 | 功能 |
|------|------|
| `^A` | 移到行首 |
| `^E` | 移到行尾 |
| `^B` / `^F` | 向左/右移动 [n] 字符 |
| `^P` / `^N` | 历史记录上一条/下一条 [n] |
| `^R` | 向后搜索历史记录 |
| `^K` | 删除到行尾 |
| `^D` | 删除光标处字符 [n] |
| `^Y` | 粘贴上次删除的文本 |
| `^L` | 重新显示当前行 |

重复计数：`Esc n <命令>`，例如 `Esc 4 ^F` 向右移动 4 个字符。

---

## 偏好设置

偏好设置在新设计导入前配置，可设置 Verilog/DEF/PDEF 解析器的特殊字符、层次分隔符等。

### 初始化文件

| 文件 | 用途 |
|------|------|
| `.ssvrc` | 设置 Tcl 参数或添加用户自定义 Tcl 命令 |
| `ssv.pref.tcl` | GUI 中 Design/Console 标签页设置的偏好（保存在工作目录） |
| `.ssv` | GUI 中 Console 标签页设置的偏好 |

**读取顺序（后读取的优先级更高）：**

1. `~/.ssvrc`（home 目录）
2. `./.ssvrc`（工作目录）
3. `./ssv.pref.tcl`（工作目录）
4. `~/.ssv`（home 目录）

---

## 访问文档与帮助

### 命令行帮助

```tcl
help                        # 列出所有命令及语法
help <command_name>         # 查看指定命令的语法
man <command_name>          # 查看指定命令的完整说明
```

示例：
```tcl
help set_power_include_file
man set_power_include_file
```

### GUI 帮助

- **Help > Documentation Library**：打开 Cadence Help 窗口，访问全部文档
- **Help > Text Command Reference / User Guide / What's New**：直接打开对应文档
- 各 Form 右下角的 **Help** 按钮：打开该 Form 对应的 Menu Reference 条目

### 命令行启动 Cadence Help

```bash
cd installation_dir/tools/bin
./cdnshelp
```

---

## 数据准备：Power 和 IR Drop 分析所需输入

### 必需数据

| 数据 | 说明 |
|------|------|
| Timing Libraries | Synopsys dot lib 文件，指定 PVT corner；STA 生成的 Timing Window File (TWF)（在 Innovus 平台内运行时可选） |
| Verilog | 网表文件 |
| SDC | 时序约束文件 |
| LEF | Technology LEF、标准单元、IO、memory 和 IP 的 LEF |
| DEF | 平铺 DEF 或顶层+各 block 的多个 DEF |
| SPEF | 平铺或多个 SPEF（顶层+各 block） |
| Spice Subckts | 设计中所有单元的 Spice 网表及模型；建议 macro/memory/IO 单元包含器件 X/Y 位置文件，且使用提取后的 Spice 网表 |
| GDS | IO、memory、IP 的 GDS 文件 |
| Layer map | GDS 层名与层号的映射（metal、via、contact、poly、diffusion） |
| Power pad location | 电源/地 pad 的 X/Y 坐标文件或 pad 单元名；需列出所有待分析的 power domain 及其电压 |
| Extraction tech file | Quantus 或 process 文件 |

> 若有 Innovus 数据库，DEF 可选；此时需提供 LEF、Verilog、SDC 和 timing library。

### 可选数据

| 数据 | 说明 |
|------|------|
| CPF | Common Power Format 文件 |
| Package model | 封装 RLC 数据（pin-based R/L/C 或 Spice subcircuit），用于分析封装压降和电感影响 |
| Filler/Decap 单元列表 | decap 优化所需 |
| VCD / TCF / FSDB | 向量驱动分析；boundary TCF/VCD 用于标注主输入活动率；全局 flop 活动率；clock gating 实例及输出活动率 |
| LVS rule file | Calibre/Hercules/Assura，用于器件识别 |
| Design power | 预期总功耗（时间平均）；自定义单元和 IP 的功耗文件（dot lib 中无 internal/leakage power 定义时使用） |
| EM rules | 每层金属的单位面积电流限制（通常由 foundry 提供） |
