# NEC Vector Engine 1.0 三卡性能测试套件

适用于 ESC4000 G4 服务器（Rocky Linux 8.x）上安装了三块 NEC VE 1.0 卡的环境。  
**测试结果：42/42 PASS，覆盖硬件识别、驱动、功能、多卡并行、性能基准、稳定性、NUMA 亲和及故障恢复。**

---

## 目录结构

```
nec_ve/
├── PerfTest/                  # 测试套件主目录
│   ├── run_tests.sh           # 主入口：运行全部或分类测试
│   ├── Makefile               # 编译所有 VE/MPI/AVEO 测试程序
│   ├── scripts/               # 各测试脚本（每个 TC 对应一个或多个）
│   │   ├── common.sh          # 公共库：自动检测 VE 节点，设置环境变量
│   │   ├── check_link_speed.sh
│   │   ├── check_firmware.sh
│   │   ├── check_numa.sh
│   │   ├── check_dmesg.sh
│   │   ├── stress_30min.sh
│   │   ├── stress_thermal.sh
│   │   ├── perf_baseline.sh
│   │   ├── perf_bandwidth.sh
│   │   ├── perf_pcie.sh
│   │   ├── perf_latency.sh
│   │   └── ...（其余脚本见 scripts/ 目录）
│   ├── ve_matmul.c            # 核心 benchmark：N×N 矩阵乘法（VE native）
│   ├── ve_bandwidth.c         # HBM 带宽测试（VE native）
│   ├── ve_mem_check.c         # HBM 内存大小验证（VE native）
│   ├── ve_float_test.c        # 浮点精度测试（VE native）
│   ├── ve_segfault.c          # 故障注入（VE native）
│   ├── aveo_bandwidth.c       # PCIe 带宽测试（AVEO Host 端）
│   ├── aveo_multi_test.c      # 多卡 AVEO 并发测试（AVEO Host 端）
│   ├── mpi_hello.c            # MPI 基础通信测试
│   ├── mpi_allreduce_test.c   # MPI AllReduce 测试
│   ├── mpi_pingpong.c         # MPI Ping-Pong 延迟测试
│   ├── sample.c               # Hello World 示例
│   ├── results/               # 各 TC 输出结果（运行时生成，不入库）
│   └── logs/                  # 测试运行日志（运行时生成，不入库）
├── docs/
│   ├── research/              # 环境调研文档
│   ├── plan/                  # 测试计划文档
│   └── impl/                  # 实现记录与最终结果报告
├── install_missing_deps.sh    # MPI runtime 和 nfort shared lib 安装辅助脚本
├── NEC_VE_Installation_Report.md
├── Three_Card_Test_Cases.md
├── Three_Card_Performance_Plan.md
└── README.md
```

---

## 硬件环境

| 项目 | 规格 |
|------|------|
| 服务器 | ASUS ESC4000 G4 |
| CPU | 2× Intel Xeon Gold 6252（24C/48T，NUMA 0/1） |
| VE 卡 | 3× NEC Vector Engine 1.0 |
| VE1（PCIe 3b:00.0） | NUMA 0，HBM 48 GB，固件 5400 |
| VE2（PCIe af:00.0） | NUMA 1，HBM 48 GB，固件 5127 ⚠️ |
| VE3（PCIe d8:00.0） | NUMA 1，HBM 48 GB，固件 5400 |
| OS | Rocky Linux 8.10，内核 4.18.0 |
| VEOS | 3.6.1 |

> ⚠️ VE2 固件版本（5127）低于 VE1/VE3（5400），建议以 root 权限升级。

---

## 前置条件

### 必须安装的软件包

```bash
# NEC VE 基础软件栈（驱动、VEOS、编译器）
yum install ve_drv-dkms veos veosinfo nec-nc++ nec-ncc

# MPI runtime
yum install nec-mpi-runtime-3-10-0

# AVEO nfort shared library（VE 侧动态库）
yum install nec-nfort-shared-5.4.1
```

安装后激活 MPI 环境变量：

```bash
source /opt/nec/ve/mpi/3.10.0/bin64/necmpivars-runtime.sh
```

> `libnfort_m.so.2` 是 VE 架构 ELF（machine 251），**不能**用 `ldconfig` 注册。  
> 运行时由 VE 动态链接器通过 `VE_LD_LIBRARY_PATH` 加载（`common.sh` 自动设置，无需手动操作）。

### 权限说明

全部测试无需 `sudo`。已将所有特权操作替换为等价方案：

| 原操作 | 替代方案 |
|--------|---------|
| `sudo vecmd state get` | `systemctl is-active ve-os-launcher@N.service` |
| `sudo lspci -vv` | `/sys/bus/pci/devices/.../current_link_speed` |
| `sudo vecmd fwup check` | `/sys/class/ve/veN/fw_version` |

---

## 编译

```bash
cd PerfTest
make all        # 编译全部 VE / MPI / AVEO 测试程序
make check      # 验证所有二进制存在
make clean      # 清除编译产物
```

编译器说明：

| 类型 | 编译器 | 说明 |
|------|--------|------|
| VE native | `ncc` / `nc++` | 运行在 VE 卡上的程序 |
| MPI | `mpicc` | NEC MPI，运行在 VE 卡上 |
| AVEO Host | `g++` + `-lveo` | 运行在 x86 主机，通过 AVEO 调用 VE |

---

## 运行测试

```bash
cd PerfTest
source /opt/nec/ve/mpi/3.10.0/bin64/necmpivars-runtime.sh

bash run_tests.sh all      # 运行全部 42 个测试
bash run_tests.sh hw       # 只运行硬件识别测试
bash run_tests.sh drv      # 只运行驱动/VEOS 测试
bash run_tests.sh func     # 只运行单卡功能测试
bash run_tests.sh mult     # 只运行多卡并行测试
bash run_tests.sh perf     # 只运行性能基准测试
bash run_tests.sh strs     # 只运行稳定性/压力测试
bash run_tests.sh numa     # 只运行 NUMA 亲和测试
bash run_tests.sh fail     # 只运行故障恢复测试
```

结果保存在 `PerfTest/results/TC-XXX.txt`，汇总日志在 `PerfTest/logs/test_run_YYYYMMDD_HHMMSS.log`。

---

## 测试案例说明

### TC-HW：硬件识别（4 项）

| ID | 测试内容 | 方法 |
|----|---------|------|
| TC-HW-001 | PCIe 设备检测 | `lspci` 检测三块 VE 卡 |
| TC-HW-002 | PCIe 链路速度 | sysfs `current_link_speed/width`（Gen3 x16） |
| TC-HW-003 | NUMA 节点分配 | sysfs `numa_node` |
| TC-HW-004 | `/dev/veN` 设备文件存在性 | ls /dev/ve0~ve2 |

### TC-DRV：驱动与 VEOS（5 项）

| ID | 测试内容 |
|----|---------|
| TC-DRV-001 | VEOS 服务运行状态（systemd） |
| TC-DRV-002 | 三卡 VE ONLINE 状态 |
| TC-DRV-003 | 固件版本一致性（警告：VE2 版本偏低） |
| TC-DRV-004 | 内核模块 `ve_drv`、`vp` 加载 |
| TC-DRV-005 | dmesg 中无 VE 相关错误 |

### TC-FUNC：单卡功能（15 项，每卡 5 项）

| ID | 测试内容 | 精度/指标 |
|----|---------|---------|
| TC-FUNC-001 | Hello World（ve_exec） | 字符串匹配 |
| TC-FUNC-002 | 点积运算（N=10M） | 误差 = 0 |
| TC-FUNC-003 | 矩阵乘法（4096×4096） | checksum 验证 |
| TC-FUNC-004 | HBM 内存大小 | ≥ 45 GB（实测 48 GB） |
| TC-FUNC-005 | 编译器向量化验证 | 编译器输出含 `Vectorized loop` |
| TC-FUNC-006 | 重复加载稳定性（10 轮） | 无失败，三卡保持 ONLINE |

### TC-MULT：多卡并行（5 项）

| ID | 测试内容 |
|----|---------|
| TC-MULT-001 | 三卡并行独立任务（backgrounding） |
| TC-MULT-002 | 混合负载（点积 + 矩阵乘 + Hello World 同时） |
| TC-MULT-003 | MPI 基础通信（`mpirun -ve 1-3 -np 3`） |
| TC-MULT-004 | MPI AllReduce（3 rank，结果验证） |
| TC-MULT-005 | AVEO 多设备并发（veo_proc_create × 3 卡） |

### TC-PERF：性能基准（6 项）

| ID | 测试内容 | 结果 |
|----|---------|------|
| TC-PERF-001 | 单卡 MatMul 算力基线 | VE1/VE2/VE3：54.16 / 54.08 / 53.81 GFLOPS |
| TC-PERF-002 | HBM 内存带宽 | 353 – 358 GB/s |
| TC-PERF-003 | 三卡并行总吞吐 | 162.04 GFLOPS |
| TC-PERF-004 | PCIe 传输带宽（AVEO） | H2D ~10 GB/s，D2H ~5.3 GB/s |
| TC-PERF-005 | MPI Ping-Pong 延迟 | ~1.52 – 1.54 μs（所有节点对） |
| TC-PERF-006 | 功耗与温度监控 | 满载 ~99W/卡，峰值温度 ~64°C |

### TC-STRS：稳定性/压力（3 项）

| ID | 测试内容 | 结果 |
|----|---------|------|
| TC-STRS-001 | 30 分钟压力测试 | 673 轮，0 失败 |
| TC-STRS-002 | Fork Bomb 稳定性 | 无残留进程 |
| TC-STRS-003 | 热节流检测（20 轮） | 性能降幅 0%，无热节流 |

### TC-NUMA：NUMA 亲和（3 项）

| ID | 测试内容 |
|----|---------|
| TC-NUMA-001 | 同 NUMA 绑定 vs 跨 NUMA 对比 |
| TC-NUMA-002 | NUMA 均衡负载 |
| TC-NUMA-003 | Host 内存饱和下 VE 稳定性（vmstat 监控） |

### TC-FAIL：故障恢复（2 项）

| ID | 测试内容 |
|----|---------|
| TC-FAIL-001 | 故障隔离：VE segfault 不影响其余两卡 |
| TC-FAIL-002 | 服务恢复：VEOS 重启后 VE 恢复 ONLINE |

---

## 性能汇总

### 算力

| 卡 | 矩阵乘法算力（4096×4096，FP64） |
|----|-------------------------------|
| VE1 | 54.16 GFLOPS |
| VE2 | 54.08 GFLOPS |
| VE3 | 53.81 GFLOPS |
| **三卡并行** | **162.04 GFLOPS** |

### 内存带宽（HBM）

| 卡 | 带宽 |
|----|------|
| VE1 | 358.28 GB/s |
| VE2 | 358.28 GB/s |
| VE3 | 353.34 GB/s |

### PCIe 传输（AVEO）

| 方向 | 带宽 |
|------|------|
| Host → VE（H2D） | ~9.7 – 10.4 GB/s |
| VE → Host（D2H） | ~5.3 – 5.4 GB/s |

### MPI 节点间延迟

| 节点对 | Ping-Pong 延迟 |
|--------|--------------|
| VE1 ↔ VE2 | 1.52 μs |
| VE1 ↔ VE3 | 1.54 μs |
| VE2 ↔ VE3 | 1.53 μs |

### 功耗与温度（满载）

| 状态 | 每卡功耗 | 三卡合计 | 峰值温度 |
|------|---------|---------|---------|
| 空闲 | ~42–51 W | ~140 W | ~42°C |
| 满载 | ~92–101 W | **~292 W** | **64.4°C** |

> TJmax ≈ 105°C，满载温度裕量约 40°C。

---

## 已知注意事项

1. **VE2 固件偏旧**：fw=5127（VE1/VE3 为 5400），性能目前无差异，建议以 root 升级。
2. **MPI 使用 MPMD 语法**：非连续节点对（如 VE1+VE3）须用 `-np 1 -ve A ... : -np 1 -ve B`，不支持 `-ve A,B` 逗号语法。
3. **VE_LD_LIBRARY_PATH**：AVEO 运行时需要此变量指向 nfort lib，`common.sh` 自动设置，无需手动配置。
4. **sysfs 温度传感器**：`sensor_15`（单位 1/1,000,000 °C）提供 VE 核心温度，`veda-smi` 可获取更精细的各核心温度。

---

## 文档

| 路径 | 内容 |
|------|------|
| `docs/research/` | 硬件环境调研（PCIe 拓扑、NUMA、软件栈） |
| `docs/plan/` | 测试计划与依赖分析 |
| `docs/impl/20260520_013000_nec_ve_final_results.md` | **最终测试结果报告**（含完整性能数据） |
| `Three_Card_Test_Cases.md` | 测试案例详细设计 |
| `NEC_VE_Installation_Report.md` | 软件安装报告 |
