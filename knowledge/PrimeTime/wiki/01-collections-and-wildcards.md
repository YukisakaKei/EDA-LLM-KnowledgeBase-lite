---
source: knowledge/PrimeTime/json/htmlView_20/topic | entries: [0009, 0017]
---

# Collections 与 Wildcards

## Collections（集合）

### 概述

Synopsys 工具（包括 PrimeTime）在内部构建一个由对象及其属性组成的数据库。数据库包含多种对象类：design、library、port、cell、net、pin、clock 等。大多数命令操作这些对象。

Collection 的核心特征：

- Collection 是**数据库对象的有序序列**，支持常量时间的随机访问
- Collection 有内部表示（对象本身）和字符串表示（一般仅用于错误消息）
- 空字符串 `""` 等价于空集合（零元素）

### 同质与异质集合

Collection 可以是同质的（所有对象属于同一类）或异质的（包含不同类的对象）。不同命令创建的集合类型不同，具体取决于应用。

### 集合生命周期

Collection 仅在**被引用时**保持活跃。典型引用方式：
- 将命令结果赋值给变量
- 作为参数传递给命令或过程

```tcl
pt_shell> set ports [get_ports *]
```

以下操作会删除集合：
```tcl
pt_shell> unset ports
pt_shell> set ports "value"
```

集合在以下情况会**隐式删除**：其父对象（或相关前置对象）被删除。例如，若 ports 集合归属于某个 design，当该 design 被移除时集合也被隐式删除，此时引用该集合的变量仍保留字符串表示但已无效：

```tcl
pt_shell> remove_design TOP
Removing design 'TOP'...
pt_shell> query_objects $ports
Error: No such collection '_sel26' (SEL-001)
```

### 遍历集合

使用 `foreach_in_collection` 遍历集合中的对象。**不能**使用 Tcl 原生的 `foreach`，因为 `foreach` 要求 list 输入，而 collection 不是 list——用 `foreach` 会直接销毁集合。

`foreach_in_collection` 参数：迭代变量、被遍历的集合、每次迭代执行的脚本。注意它**不接受多个迭代变量**（与 `foreach` 不同）。

```tcl
pt_shell> foreach_in_collection s1 $collection {
  echo [get_object_name $s1]
}
```

### 集合操作命令

| 命令 | 功能 | 备注 |
|------|------|------|
| `add_to_collection` | 将对象名或集合添加到基础集合，创建新集合 | 支持 `-unique` 去重 |
| `append_to_collection` | 将对象追加到已有集合（就地修改） | 比 `add_to_collection` 快得多 |
| `remove_from_collection` | 从集合中移除指定对象，返回新集合 | |
| `compare_collections` | 验证两个集合包含相同对象（可选相同顺序） | 成功返回 0 |
| `copy_collection` | 创建包含相同对象的新集合 | 并非所有集合都可复制 |
| `index_collection` | 提取集合中单个对象，创建新集合 | 常量时间操作 |
| `sizeof_collection` | 返回集合中的对象数量 | |

```tcl
# 追加示例
pt_shell> set dports [remove_from_collection [all_inputs] CLK]
{"in1", "in2", "in3"}
```

### 过滤（Filtering）

使用 `filter_collection` 对集合进行过滤，基于表达式筛选匹配的对象：

```tcl
pt_shell> filter_collection [get_cells *] "is_hierarchical == true"
{"i1", "i2"}
```

也可以在创建集合的命令中直接使用 `-filter` 选项（通常更高效）：

```tcl
pt_shell> get_cells * -filter "is_hierarchical == true"
{"i1", "i2"}
```

#### 过滤表达式语法

表达式由关系表达式通过 `AND`/`OR` 连接组成，支持括号。

**关系运算符：**

| 运算符 | 含义 |
|--------|------|
| `==` | 等于 |
| `!=` | 不等于 |
| `>` | 大于 |
| `<` | 小于 |
| `>=` | 大于等于 |
| `<=` | 小于等于 |
| `=~` | 模式匹配 |
| `!~` | 不匹配模式 |

**比较规则：**
- 字符串属性可与任意运算符比较
- 数值属性不能与模式匹配运算符比较
- 布尔属性只能使用 `==` 和 `!=`，值只能为 `true` 或 `false`

**存在性运算符：**
- `defined(attr)` — 属性已定义
- `undefined(attr)` — 属性未定义

```tcl
(sense == setup_clk_rise) and defined(sdf_cond)
```

### 排序（Sorting）

使用 `sort_collection` 按属性排序，默认升序，`-descending` 降序：

```tcl
pt_shell> sort_collection [get_ports *] {direction full_name}
{"in1", "in2", "out1", "out2"}
```

### 隐式查询（Implicit Query）

当创建集合的命令作为**主命令**在命令行直接使用时，会自动查询集合内容并显示结果：

```tcl
pt_shell> get_ports in*
{"in0", "in1", "in2"}
```

当集合作为**参数**传递给其他命令时，集合在主命令完成后立即销毁：

```tcl
pt_shell> set_input_delay 3.0 [get_ports in*]   ;# get_ports 创建的集合在 set_input_delay 完成后销毁
```

使用 `query_objects -verbose` 可显示详细对象类型信息：

```tcl
pt_shell> query_objects -verbose [get_ports in*]
{"port:in0", "port:in1", "port:in2"}
```

只有将集合保存到变量，才能使集合持久化：

```tcl
pt_shell> set iports [get_ports in*]
{"in0", "in1", "in2"}
```

### 相关命令

`add_to_collection` / `as_collection` / `append_to_collection` / `compare_collections` / `copy_collection` / `filter_collection` / `foreach_in_collection` / `index_collection` / `query_objects` / `remove_from_collection` / `sizeof_collection` / `sort_collection`

---

## Wildcards（通配符）

### 支持的 Wildcard 字符

| 字符 | 含义 |
|------|------|
| `*` | 匹配任意长度的字符串 |
| `?` | 匹配单个字符 |

### 支持 Wildcard 的命令

以下命令支持通配符模式匹配：

```tcl
get_cells      get_clocks     get_designs
get_lib_cells  get_lib_pins   get_libs
get_nets       get_pins       get_ports
list_libs
```

此外，所有执行隐式 get 操作的命令也支持通配符。

### 转义 Wildcard

当需要匹配字面量的 `*` 或 `?` 字符时，需要使用反斜杠转义：

```tcl
# 匹配名称中实际包含 * 的 net（而非将 * 作为通配符）
get_nets "net\*1"
```

### 转义转义字符

在 Tcl 中，反斜杠 `\` 本身也是转义字符。当需要传递一个字面量反斜杠时（如配合通配符转义），需要双重转义 `\\`：

```tcl
# 实际传递给命令的是 net\*1，其中 \* 表示字面量星号
get_nets "net\\*1"
```
