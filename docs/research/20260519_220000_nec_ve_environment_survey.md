# NEC VE 环境调研

**时间**：2026-05-19 22:00  
**目标**：摸清服务器上三张 NEC Vector Engine 1.0 卡的硬件/软件环境

---

## 硬件

| 卡号 | PCIe BDF | NUMA节点 | 链路速度 | 链路宽度 | 固件版本 |
|------|----------|---------|---------|---------|---------|
| VE1  | 3b:00.0  | NUMA0   | 8.0 GT/s (Gen3) | x16 | 5400 |
| VE2  | af:00.0  | NUMA1   | 8.0 GT/s (Gen3) | x16 | **5127** ⚠️ |
| VE3  | d8:00.0  | NUMA1   | 8.0 GT/s (Gen3) | x16 | 5400 |

主机：双路 Intel Xeon Gold 6252 @ 2.1GHz

## 设备节点与VE编号

- `/dev/ve0`、`/dev/ve1`、`/dev/ve2` 均存在
- `ve_exec -N 0` 返回 "Node '0' is Offline"
- 活跃 VEOS 服务：`ve-os-launcher@1`、`@2`、`@3`
- **实际 `ve_exec` 节点号为 1、2、3**（非0起始）

## 软件栈

| 组件 | 状态 |
|------|------|
| 内核模块 `ve_drv` | ✅ 已加载 |
| 内核模块 `vp` | ✅ 已加载 |
| VEOS (`ve-os-launcher`) | ✅ 节点1/2/3 活跃 |
| NCC 编译器 | ✅ 可用 |
| AVEO | ❌ `libnfort_m.so.2` 缺失 |
| MPI (`mpirun`) | ❌ 未安装 |

## 权限约束

- `sudo` 无法免密使用，所有测试必须以普通用户权限运行
- `vecmd state get` 需要 sudo → 替换为 `systemctl is-active ve-os-launcher@N.service`
- `lspci -vv` 读取 PCIe capabilities 需要 sudo → 替换为 `/sys/bus/pci/devices/0000:XX:00.0/current_link_{speed,width}`
- `vecmd fwup check` 需要 sudo → 替换为 `/sys/class/ve/veN/fw_version`

## sysfs 路径参考

```
/sys/class/ve/ve{0,1,2}/fw_version        # 固件版本
/sys/class/ve/ve{0,1,2}/ve_state          # 硬件状态
/sys/bus/pci/devices/0000:XX:00.0/current_link_speed
/sys/bus/pci/devices/0000:XX:00.0/current_link_width
/sys/bus/pci/devices/0000:XX:00.0/numa_node
```

注：sysfs 中 `ve0/ve1/ve2` 索引与 `ve_exec` 节点号（1/2/3）**不是**一一对应关系。
