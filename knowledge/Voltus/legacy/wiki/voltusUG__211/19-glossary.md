---
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0341]
---

# Voltus 术语表

## 电源完整性基础 (Power Integrity Basics)

- **Power grid** -- 芯片上由互连金属线构成的大型供电网络，将电源从 pad 分配到所有门和晶体管，功能类似于电力输配系统。
- **IR drop** -- 因电流流经 VDD 网络自身电阻而产生的电压降低（V = I x R）。
- **Ground bounce** -- 因电流流经 Ground 网络自身电阻而导致的地网络电压升高。
- **Power** -- 电源电压，也称 VDD 或 VCC。
- **Ground** -- 电流回路导体，也称 VSS 或 GND。
- **VDD** -- 电源节点（电压供应）的通用名称，等同于 VCC。
- **VSS** -- 地节点（电流回路）的通用名称，等同于 GND。
- **DC** -- 直流电（Direct Current），电流单向流动，power grid 中的电流通常为 DC。
- **AC** -- 交流电（Alternating Current），电流以固定频率周期性反向，信号线上的电流通常为 AC。

## 分析方法 (Analysis Methods)

- **Static analysis** -- 不使用时域仿真的电路分析方法。
- **Dynamic analysis** -- 基于 time 域的电路分析方法，在指定时段（如一个时钟周期）内分析电路网表的电流和电压。
- **Transient analysis** -- 基于 time 域的瞬态分析。
- **Steady-state analysis** -- 假设所有组件处于稳定值的分析方法。
- **Ipeak analysis** -- 基于晶体管饱和峰值电流的静态 power-grid 分析。

## 功耗分析相关 (Power Analysis)

- **Activity** -- 每时钟周期的信号翻转次数。
- **Transition density** -- 每秒钟的信号翻转次数（跳变和下降总和）。
- **Input duty cycle** -- 0 到 1 之间的值，表示信号为 1 的时间比例。
- **Transition time** -- 信号从低到高或高到低切换的时间间隔。
- **Average current** -- 流经每个 tap point 的渐近平均电流。
- **Peak current** -- 电流波形的最大值。
- **Tap currents** -- 晶体管等器件连接到 power grid 所产生的电流。
- **Toggle count format (TCF) file** -- 包含切换活动信息（toggle count 和 net/pin 在逻辑 1 状态的概率）的文件格式。
- **Value change dump (VCD) file** -- 标准 Verilog 文件格式（IEEE 1364），包含测试向量和设计中所有 net 的切换活动信息。

## 电压与 Rail 分析 (Rail Analysis)

- **Effective instance voltage (EIV)** -- Rail 分析中得到的 rail-to-rail 电压，通过处理电压波形得到特定窗口内 power 与 ground pin 之间的最差有效电压。EIV 可在四种窗口下评估：switching、timing、both（默认）、elapse。
- **EIV method** -- 计算 EIV 的方法：worst（默认）、best、average、worst-average。
- **Power-grid signoff (PGS)** -- 芯片在 tapeout 前必须通过静态 power-grid 分析的签收流程。

## 电迁移与可靠性 (Electromigration & Reliability)

- **Electromigration (EM)** -- 导电电子与扩散金属原子之间的动量传递引起的金属质量迁移，在高电流密度金属线中发生，可能导致空洞或小丘。
- **Joule heating** -- 高电流导致特定线段过热而引发的电迁移机制。
- **Fusing** -- 因过大瞬时电流导致的导线瞬间失效，与电迁移相关，有时归为 Joule heating 的子集。

## 电源网格视图 (Power-Grid Views)

- **Power-grid view** -- 单元或模块 power grid 的模型，包含提供 current loading 信息的 power-port 信息。
- **Abstract power-grid view** -- 详细 power-grid view 的简化形式，将模块或 macro 的内部电流负载替换为端口引脚上的等效阻抗值。
- **Detailed power-grid view** -- 从 GDSII 提取的单元或 macro 内部电源走线的详细电气模型，包含电阻和 current loading 信息。
- **Port power-grid view** -- 不含内部电路和 power grid 细节的简单电气视图，创建无需提取过程。

## 时序相关 (Timing)

- **Delay** -- 信号从给定输入传播到给定输出所需的时间。
- **Clock skew** -- 时钟信号从源点到达不同触发器的路径延迟之差。
- **Clock slew** -- 信号在缓冲器或接收端从低阈值上升至高阈值（或相反）所需的时间，通常以 10% 和 90% 电源电压为阈值。
- **Clock signal jitter** -- 电源电压波动引起的延迟、skew 和 slew rate 变化。
- **Signal skew** -- 信号在整个设计中到达时间的差异。
- **Setup time** -- 时钟沿前数据必须保持稳定的时间。
- **Setup-time violation** -- 输入信号变化晚于指定 setup time。
- **Hold time** -- 时钟沿后输入数据必须保持稳定的时间。
- **Hold-time violation** -- 输入信号变化早于指定 hold time。

## 设计结构 (Design Structure)

- **Cell** -- 实现基本逻辑功能的晶体管组（如 NAND、NOR、XOR、flip-flop），通常不包含其他单元 placement。
- **Block** -- 可包含其他 block、cell 或晶体管的高层次单元。
- **Core** -- 包含设计主要功能的 block。
- **Macro** -- LEF 文件中引用的 cell，其几何数据存储在 DEF 或 GDSII 中。
- **Embedded block** -- 为特定设计创建的大型定制 block。
- **Hierarchical design** -- 在多个抽象层次组织逻辑的设计方法。
- **Netlist** -- 设计中所有组件及其互连关系的 ASCII 或二进制描述。
- **Port** -- 标记输出文件中特定位置的命名几何图形。
- **Feedthrough** -- 单元内可同时连接到顶层 routing 的信号 net，常用于 abutment 拼接。
- **Filler cell** -- 仅填充空间而不实现逻辑功能的 standard cell，用于填补 power/ground rail 间隙或作为 placeholder。
- **Simultaneously switching output (SSO)** -- 多个输出同时切换，用于评估对 power grid 的影响。
- **Promoted geometries** -- 单元/模块内必须在 full-chip level 考虑的几何图形，以确保 power grid 提取精度。

## 文件格式 (File Formats)

- **GDSII** -- 图形设计系统 v2.0 Stream 格式的二进制文件。
- **LEF/DEF** -- Library Exchange Format / Design Exchange Format，布局工具广泛使用的版图格式。
- **SPEF** -- Standard Parasitic Exchange Format，支持传递真正的耦合电容到下游分析工具。
- **DSPF** -- Detailed Standard Parasitic Format，寄生电阻电容的文件化传递格式，不能表示真实耦合电容（将其建模为对地去耦）。
- **SPICE** -- 晶体管级电路仿真程序，原由 UC Berkeley 开发，现常作为此类仿真器的通用称呼。
- **HSPICE** -- Synopsys 的商用 SPICE 仿真器实现。
- **SDC file** -- Synopsys Design Constraints 文件，基于 TCL 语言的时序和面积约束描述。
- **Piecewise linear (PWL)** -- 电路仿真中电压源的波形表示方式，无重复模式。
- **Pulse** -- 电路仿真中展现周期性重复模式的波形表示方式。

## 寄生参数与模型 (Parasitics & Models)

- **Parasitic capacitance** -- 导体或器件之间引起不必要效应的任何电容。
- **Decoupling capacitance (decap)** -- 为平滑 power rail 而添加的电容，通常接在 power 与 ground 之间。
- **Decoupling cells** -- 包含 decoupling capacitance 的单元。
- **Decoupled capacitance** -- 替代耦合电容的集总电容，通常用于支持静态时序分析。
- **Effective current source model (ECSM)** -- 用于延迟计算的高精度非线性驱动模型。
- **Miller capacitance** -- 晶体管栅极与源/漏之间的耦合电容。
- **Flat extraction** -- 将互连寄生电阻电容提取到晶体管级别的过程。

## 制造工艺相关 (Manufacturing)

- **Chemical mechanical polishing (CMP)** -- 去除表面不平整、实现硅片表面均匀平坦化的工艺过程。
- **Dishing** -- 因 CMP 导致宽互连线横截面积减小，发生在铜线凹陷或突出于相邻介电层时。
- **Erosion** -- 互连线横截面积的减小和介电层的局部变薄。
- **Slotting** -- 在宽线上按规则间隔插入小槽以减少 dishing 效应。
- **Cladding** -- 铜互连与 low-k 介电材料之间的阻挡层，保护互连免受介电材料的化学反应。
- **Optical proximity correction (OPC)** -- 自动生成掩模特征以补偿亚波长光刻效应的工艺。
- **Wire-edge enlargement** -- 因邻近走线导致导线宽度和间距的有效变化，属光学效应。
- **Skin effect** -- 时变电流集中在导体表面的现象，穿透深度与频率成反比。
- **Flip chip** -- 将芯片倒装通过焊料凸点直接连接到基板或电路板的封装方式。

## 材料与层次 (Layers & Materials)

- **Conductor layer** -- 集成电路中承载电流的材料层。
- **Dielectric layer** -- 最高钝化层以下的所有沉积层。
- **Diffusion layer** -- 衬底表面以下的层次，包括有源区，但不包括 polysilicon（属于 conductor layer）。
- **Passivation layer** -- 工艺最高导体层以上的沉积层。
- **Substrate** -- 集成电路制作或贴附的支撑材料。
- **Planar dielectric** -- 平坦的介电层，与 conformal dielectric 相对。
- **Via** -- 两个相邻金属 routing 层之间的连接点。

## 辅助概念 (Other Concepts)

- **Angled resistor** -- 非水平也非垂直的电阻器（与 X 或 Y 轴夹角小于 30 度分别称为 horizontal 或 vertical resistor）。
- **Horizontal resistor** -- 与 X 轴夹角小于 30 度的电阻器。
- **Vertical resistor** -- 与 Y 轴夹角小于 30 度的电阻器。
- **HSPICE** -- 见文件格式章节。
- **Itaputil** -- Cadence 工具，用于报告 tap current 文件特性或提取数据到新文件。
- **ASCII format** -- 人类可读的文本格式（American Standard Code for Information Interchange）。
- **Panning** -- 以某点为中心平移设计视图而不改变缩放比例。
- **Zooming** -- 放大或缩小芯片选定区域视图。
- **Tapeout** -- 将最终版图设计文件交付给掩模制造商的流程。
- **Moore's Law** -- Gordon Moore 的观察：硅集成电路的晶体管数量约每 18 个月翻一番。
- **Noise injection** -- 因切换 net/circuitry 通过互连或衬底寄生耦合而出现非预期电压值。
- **Interconnect** -- 集成电路中门和单元之间的物理走线和 via。
