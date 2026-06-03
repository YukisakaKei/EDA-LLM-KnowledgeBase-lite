# Proc 规划：getConnectedBufInvNetLength

## 算法流程

### 步骤 1：参数验证
- 获取输入 pin 的指针
- 检查 pin 是否存在，不存在则报错

### 步骤 2：获取扇出 instance
- 使用 `all_fanout -from $pinName -only_cells` 命令获取 instance 指针列表
- 遍历指针列表，使用 `get_property full_name` 获取每个 instance 的完整名称
- 得到 instance name list

### 步骤 3：过滤 buf/inv
- 使用 `filter_collection` 直接过滤 `all_fanout` 的输出
- 过滤条件：`is_buffer == true || is_inverter == true`
- 得到 buf/inv cell 的集合（仍属于 get_* 系统的指针）

### 步骤 4：提取 instance 名字列表
- 使用 `get_property $buf_inv_insts full_name` 从 get_* 系统指针提取名字列表
- 得到 instance 名字列表

### 步骤 5：指针系统转换
- 遍历 instance 名字列表
- 使用 `dbGet top.insts.name $inst_name -p` 将名字转换为 dbGet 系统的指针

### 步骤 6：计算输出 net 长度
对每个 buf/inv instance：
- 获取其所有输出 pin（`isOutput == 1`）
- 对每个输出 pin：
  - 获取所在的 net
  - 遍历 net 的所有 wire segment
  - 累加每条 wire 的长度（`dbGet wire.length`）

### 步骤 7：返回总长度
- 返回所有 buf/inv 输出 net 的总长度（浮点数）

---

## 伪代码

```tcl
proc getConnectedBufInvNetLength {pinName} {
    
    # 1. 初始化
    set total_length 0
    
    # 2. 使用 all_fanout 获取所有扇出 instance
    set fanout_insts [all_fanout -from $pinName -only_cells]
    
    # 3. 使用 filter_collection 直接过滤 buf/inv
    set buf_inv_insts [filter_collection $fanout_insts {is_buffer == true || is_inverter == true}]
    
    # 4. 提取 instance 名字列表
    set inst_names [get_property $buf_inv_insts full_name]
    
    # 5. 遍历每个 buf/inv instance 名字
    foreach inst_name $inst_names {
        
        # 6. 通过名字转换到 dbGet 系统的指针
        set inst_ptr [dbGet top.insts.name $inst_name -p]
        
        # 7. 获取这个 instance 的所有输出 pin
        set output_pins [dbGet $inst_ptr.instTerms {.isOutput == 1}]
        
        foreach output_pin $output_pins {
            
            # 8. 获取输出 pin 所在的 net
            set output_net [dbGet $output_pin.net]
            
            # 9. 计算这个 net 的长度
            set net_length 0
            set wires [dbGet $output_net.wires]
            foreach wire $wires {
                set wire_length [dbGet $wire.length]
                set net_length [expr $net_length + $wire_length]
            }
            
            # 10. 累加总长度
            set total_length [expr $total_length + $net_length]
        }
    }
    
    # 11. 返回总长度
    return $total_length
}
```
