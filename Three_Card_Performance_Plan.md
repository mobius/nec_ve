# NEC VE 1.0 三卡性能方案评估

> 服务器: 2x Intel Xeon Gold 6252 + 当前 1x VE 1.0 卡  
> 扩展目标: 再增加 2 张 VE 卡（10BE-P / 10B-P 混装）  
> 评估时间: 2026-05-19

---

## 1. 当前系统拓扑

### 1.1 CPU & 内存

| 项目 | 规格 |
|------|------|
| CPU | 2x Intel Xeon Gold 6252 (Cascade Lake) |
| 核心 | 24C/48T × 2 = 48C/96T |
| 频率 | 2.1 GHz Base, 3.7 GHz Turbo |
| 内存 | 62 GB (~64 GB) DDR4 |
| NUMA | 2 nodes |
| UPI | 3x 10.4 GT/s (双路互联) |

**⚠️ 内存瓶颈预警**: 三卡并行时，主机内存可能成为瓶颈。建议扩展到 **128GB~256GB**。

### 1.2 PCIe 拓扑

```
CPU0 (NUMA node 0)
├── 17:00.0  Root Port A  Port #1   x16  空  → 可用
├── 3a:00.0  Root Port A  Port #5   x16  空  → 可用
└── 5d:00.0  Root Port A  Port #9   x16  有VE卡(5e:00.0) → 已用

CPU1 (NUMA node 1)
├── 80:00.0  Root Port A  Port #0   x4   空  → ❌ 不可用(仅x4)
├── 85:00.0  Root Port A  Port #1   x8   有设备 → ❌ 不可用(仅x8)
├── ae:00.0  Root Port A  Port #5   x16  空  → 可用
└── d7:00.0  Root Port A  Port #9   x16  空  → 可用
```

**可用 x16 插槽: 4 个** (17, 3a, ae, d7)，足够装 3 张卡。

### 1.3 当前 VE 卡状态

```
5e:00.0  NEC Corporation Vector Engine 1.0 (rev 01)
  Subsystem: NEC Corporation Device 0000
  NUMA node: 0
  Region 0: Memory at 1f000000000 (64-bit, prefetchable) [size=64G]
  LnkCap:  Speed 8GT/s, Width x16
  LnkSta:  Speed 8GT/s (ok), Width x16 (ok)
```

✅ **Gen3 x16 全速运行**

---

## 2. 10BE-P vs 10B-P 型号分析

### 2.1 型号识别

| 型号 | 说明 | 兼容性 |
|------|------|--------|
| **10B-P** | NEC VE 1.0 标准版 | 1bcf:001c |
| **10BE-P** | NEC VE 1.0 增强版 / 早期工程版 | 1bcf:001c |

从 `lspci` Device ID (`1bcf:001c`) 看，**两者核心芯片完全相同**，可以混装使用。

### 2.2 可能的差异

| 维度 | 10B-P | 10BE-P | 影响 |
|------|-------|--------|------|
| 散热方案 | 标准散热器 | 可能不同 | 需确认机箱风道 |
| 固件版本 | 可能较新 | 可能较早 | 建议统一刷到最新 |
| 功耗限制 | 标准 TDP | 可能放宽 | 需确认电源余量 |
| 背板接口 | 标准 | 可能不同 | 不影响功能 |

**结论**: 可以混装，但建议将三张卡固件统一到相同版本。

---

## 3. 三卡物理安装方案

### 3.1 推荐方案: 2+1 NUMA 均衡分布

```
CPU0 (NUMA0)          CPU1 (NUMA1)
┌─────────────┐       ┌─────────────┐
│  17:00.0    │       │  ae:00.0    │
│  VE Card #1 │       │  VE Card #2 │
│  (新增)     │       │  (新增)     │
├─────────────┤       ├─────────────┤
│  3a:00.0    │       │  d7:00.0    │
│  (保留)     │       │  (保留)     │
├─────────────┤       └─────────────┘
│  5d:00.0    │
│  VE Card #0 │
│  (现有)     │
└─────────────┘
```

**分配逻辑**:
- CPU0 负担 2 张卡（现有 + 新增）
- CPU1 负担 1 张卡（新增）
- 这样每个 NUMA 节点都有卡，避免跨 NUMA 访问

### 3.2 替代方案: 1+2 NUMA 均衡分布

将现有卡保留在 CPU0，两张新卡都装到 CPU1:

```
CPU0: 5d:00.0 (现有) + 1 个空槽
CPU1: ae:00.0 (新增) + d7:00.0 (新增)
```

**优点**: CPU0 压力更小，现有配置无需改动。  
**缺点**: CPU0 只有 1 张卡，NUMA0 的 48 个线程可能闲置。

### 3.3 推荐选择: **方案 A (2+1)**

理由:
1. 充分利用双路 CPU 的内存带宽
2. 每路至少 1 张卡，避免单 NUMA 瓶颈
3. 与当前卡同 NUMA 的新卡可以利用现有的 numa_node 0 优化配置

---

## 4. 散热与供电评估

### 4.1 功耗估算

| 组件 | 数量 | 单卡 TDP | 总计 |
|------|------|---------|------|
| VE 1.0 卡 | 3 | ~300W | **~900W** |
| Xeon Gold 6252 | 2 | ~150W | ~300W |
| 系统其余 | 1 | ~100W | ~100W |
| **整机总计** | | | **~1300W** |

### 4.2 散热要求

- 3 张 VE 卡会产生大量热量
- 每张卡需要独立的散热风道
- 机箱必须有足够的风扇位（建议 4U 或塔式服务器）
- 卡间距至少 2 slot（避免热堆积）

### 4.3 电源要求

- 建议电源: **1600W+**（留 20% 余量）
- 需确认主板供电能力（PCIe 插槽供电规格）
- VE 卡需要 8pin/6pin PCIe 供电接口

---

## 5. 多卡软件配置

### 5.1 VEOS 多节点自动识别

VEOS 安装后，系统会自动识别所有 VE 卡并创建对应的设备节点:

```
/dev/ve0    /dev/veslot0    → 第 0 张卡
/dev/ve1    /dev/veslot1    → 第 1 张卡
/dev/ve2    /dev/veslot2    → 第 2 张卡
```

服务 `ve-os-launcher@N.service` 会为每张卡自动启动一个 VEOS 实例。

### 5.2 指定卡运行程序

```bash
# 在第 0 张卡运行
ve_exec -N 0 ./program

# 在第 1 张卡运行
ve_exec -N 1 ./program

# 在第 2 张卡运行
ve_exec -N 2 ./program
```

### 5.3 多卡并行方案

#### 方案 1: 独立任务（ embarrassingly parallel ）

不同任务跑在不同卡上，无通信:

```bash
ve_exec -N 0 ./task_a &
ve_exec -N 1 ./task_b &
ve_exec -N 2 ./task_c &
wait
```

#### 方案 2: MPI 跨卡并行

使用 NEC MPI 在卡间通信:

```bash
mpirun -ve 0-2 -np 3 ./mpi_program
```

**通信路径**: VE0 ↔ VH(Host) ↔ VE1（通过 PCIe 或共享内存）  
**注意**: 跨卡 MPI 通信需要经过主机内存，带宽受限。

#### 方案 3: AVEO / VEDA 多设备

```c
// AVEO 示例: 查询并使用多张卡
veo_proc_handle *proc0 = veo_proc_create(0);  // 卡 0
veo_proc_handle *proc1 = veo_proc_create(1);  // 卡 1
veo_proc_handle *proc2 = veo_proc_create(2);  // 卡 2
```

#### 方案 4: OpenMP Offload

```c
#pragma omp target device(0)  // 指定卡 0
#pragma omp target device(1)  // 指定卡 1
```

### 5.4 NUMA 亲和性优化

```bash
# 卡 0 在 NUMA0，绑定 NUMA0 的 CPU
numactl --cpunodebind=0 --membind=0 ve_exec -N 0 ./program

# 卡 1 在 NUMA1，绑定 NUMA1 的 CPU
numactl --cpunodebind=1 --membind=1 ve_exec -N 1 ./program
```

---

## 6. 性能预期

### 6.1 单卡理论峰值

| 指标 | VE 1.0 值 |
|------|----------|
| 向量寄存器 | 256 × 256-bit |
| 向量 Lane | 8 (FP64) / 16 (FP32) |
| 核心频率 | ~1.4 GHz |
| **FP64 峰值** | **~1.3 TFLOPS** |
| **FP32 峰值** | **~2.6 TFLOPS** |
| HBM2 容量 | 48 GB |
| HBM2 带宽 | ~1.2 TB/s |

### 6.2 三卡理论峰值

| 模式 | FP64 | FP32 | HBM 总量 |
|------|------|------|---------|
| 单卡 | 1.3 TFLOPS | 2.6 TFLOPS | 48 GB |
| 三卡 (理想) | **3.9 TFLOPS** | **7.8 TFLOPS** | **144 GB** |

### 6.3 实际可达成性能

| 场景 | 单卡实测 | 三卡预期 | 效率 |
|------|---------|---------|------|
| 矩阵乘法 (512³) | 33.6 GFLOPS | ~100 GFLOPS | 取决于并行度 |
| 内存带宽测试 | ~800 GB/s | ~2.4 TB/s | 近线性扩展 |
| MPI 跨卡通信 | N/A | 受限于 PCIe | 需要避免频繁通信 |

**关键瓶颈**:
1. 主机内存带宽 (6-channel DDR4 ~150 GB/s) 远小于 3×HBM (~3.6 TB/s)
2. 跨卡数据交换必须经过主机内存
3. 整机功耗和散热

---

## 7. 安装 checklist

### 硬件准备

- [ ] 确认机箱有足够空间（3 张双宽卡 + 风道间隙）
- [ ] 确认电源 ≥ 1600W，有足够 PCIe 供电线
- [ ] 确认主板有 3+ 个 CPU 直连的 x16 插槽
- [ ] 准备散热方案（机箱风扇 / 风道改造）

### BIOS 设置

- [ ] Above 4G Decoding: **Enabled**
- [ ] Resizable BAR: **Enabled** (如有)
- [ ] SR-IOV: **Enabled** (如有需要)
- [ ] PCIe 插槽设置为 x16 模式（而非 x8/x4）

### 系统配置

- [ ] 主机内存扩展到 **≥128GB**（推荐 256GB）
- [ ] 安装新卡后检查 `lspci | grep NEC`
- [ ] 检查每张卡链路速度: `lspci -vv -s xx:00.0 | grep LnkSta`
- [ ] 重启系统，确认所有卡 `vecmd state get` 显示 ONLINE
- [ ] 检查 `/dev/ve0`, `/dev/ve1`, `/dev/ve2` 都存在

### 固件统一

```bash
# 检查各卡固件版本
sudo /opt/nec/ve/bin/vecmd fwup -N 0 check
sudo /opt/nec/ve/bin/vecmd fwup -N 1 check
sudo /opt/nec/ve/bin/vecmd fwup -N 2 check

# 如不一致，统一刷到最新版本
```

---

## 8. 推荐内存升级

当前 62GB 内存对于三卡配置偏少:

| 配置 | 主机内存 | 说明 |
|------|---------|------|
| 最小配置 | 128 GB | 勉强可用，数据预取受限 |
| **推荐配置** | **256 GB** | 每张卡可分配 ~80GB 主机缓冲区 |
| 理想配置 | 512 GB | 大数据集场景无压力 |

VE 卡虽然有 48GB HBM，但数据加载、中间结果、MPI 缓冲都需要主机内存。

---

## 9. 总结

### 可行性: ✅ 完全可行

- 服务器有 4 个可用 x16 插槽，足够装 3 张卡
- 当前 VE 卡运行正常（Gen3 x16, ONLINE）
- 10BE-P 和 10B-P 可以混装
- VEOS 和 MPI 已安装，支持多卡

### 推荐配置

| 项目 | 建议 |
|------|------|
| 插槽分配 | CPU0: 2张, CPU1: 1张（或反之） |
| 内存升级 | **256GB DDR4** |
| 电源 | **1600W+** |
| 散热 | 确保每张卡独立风道 |
| 固件 | 统一三张卡到相同版本 |
| 编程 | 独立任务 > AVEO > MPI |

### 性能预期

- **FP64**: 最高 ~3.9 TFLOPS（三卡理想并行）
- **FP32**: 最高 ~7.8 TFLOPS
- **HBM 总容量**: 144 GB
- **实际效率**: 70~85%（取决于并行度和通信模式）
