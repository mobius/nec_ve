# NEC VE 1.0 驱动安装与测试计划

> 计划时间: 2026-05-19 22:55:57  
> 目标: 在三卡 ESC4000G4 上完成 VE 驱动安装验证与性能基准测试

---

## 1. 当前安装状态评估

### 1.1 已完成的安装

| 组件 | 版本 | 状态 |
|------|------|------|
| 操作系统 | Rocky Linux 8.10 | ✅ |
| 内核 | 4.18.0-553.124.1.el8_10.x86_64 | ✅ |
| ve_drv (驱动模块) | 3.6.1 | ✅ 已加载 |
| VEOS (VE OS) | 3.6.1 | ✅ 运行中 |
| ve-firmware | 1.7.0 | ✅ |
| vp-kmod | 3.6.0 | ✅ |
| glibc-ve1 | 2.21 | ✅ |
| libsysve-ve1 | 3.6.0 | ✅ |
| veoffload-aveo | 3.6.0 | ⚠️ 运行时库不完整 |
| veoffload-veda | 3.6.1 | ✅ |
| ncc/nc++/nfort | 5.4.1 | ✅ |
| nec-mpi-devel | 3.10.0 | ⚠️ 无 mpirun |

### 1.2 已配置的源

- `/etc/yum.repos.d/TSUBASA-repo.repo`
- `/etc/yum.repos.d/TSUBASA-restricted.repo`
- `yum groupinstall ve-devel` 已完成

---

## 2. 待解决问题清单

| 优先级 | 问题 | 影响 | 建议方案 |
|--------|------|------|---------|
| P0 | `libncc.so.2` 链接警告 | 所有 VE 程序编译 | 确认符号链接已创建 |
| P1 | `libnfort_m.so.2` 缺失 | AVEO 程序无法运行 | 安装 nec-nfort-runtime 或寻找兼容包 |
| P1 | `mpirun` 未找到 | MPI 测试无法执行 | 确认 nec-mpi-runtime 包安装状态 |
| P1 | `veosinfo.h` 头文件缺失 | 无法编译使用 veosinfo 的程序 | 安装 veosinfo-devel 包 |
| P2 | VE 卡编号 1/2/3 | 测试脚本需适配 | 脚本中动态检测 VE 节点 |
| P2 | 主机内存 62GB | 三卡运行时可能瓶颈 | 计划升级至 256GB |

---

## 3. 测试实施计划

### 3.1 测试架构

```
PerfTest/
├── Makefile              # 统一编译管理
├── run_tests.sh          # 主测试入口
├── sample.c              # Hello World
├── ve_float_test.c       # 浮点向量点积
├── ve_matmul.c           # 矩阵乘法基准
├── ve_bandwidth.c        # HBM 带宽测试
├── ve_mem_check.c        # 内存容量检测
├── ve_segfault.c         # 故障注入
├── mpi_hello.c           # MPI 基础
├── mpi_allreduce_test.c  # MPI 集合通信
├── mpi_pingpong.c        # MPI 延迟
├── aveo_multi_test.c     # AVEO 多设备
├── aveo_bandwidth.c      # PCIe 带宽
└── scripts/              # 辅助脚本
```

### 3.2 测试类别与权重

| 类别 | 数量 | 权重 | 说明 |
|------|------|------|------|
| 硬件识别 (HW) | 4 | 必须 | PCIe、链路、NUMA、设备节点 |
| 驱动状态 (DRV) | 5 | 必须 | VEOS、ONLINE、固件、模块、日志 |
| 单卡功能 (FUNC) | 6 | 必须 | Hello World、浮点、矩阵、内存、编译器、稳定性 |
| 多卡并行 (MULT) | 5 | 必须 | 独立任务、混合负载、MPI、AVEO |
| 性能基准 (PERF) | 6 | 必须 | GFLOPS、HBM带宽、总吞吐、PCIe、MPI延迟、功耗 |
| 稳定性 (STRS) | 3 | 必须 | 30分钟压力、fork炸弹、温度监控 |
| NUMA亲和性 (NUMA) | 3 | 建议 | 绑定、均衡、内存饱和 |
| 故障恢复 (FAIL) | 2 | 建议 | 隔离、恢复 |

### 3.3 通过标准

| 等级 | 条件 |
|------|------|
| **完全通过** | 所有"必须"项通过 + 所有"建议"项通过 |
| **基本可用** | 所有"必须"项通过，"建议"项失败 ≤3 个 |
| **有条件可用** | "必须"项失败 ≤2 个，且为功能非核心项 |
| **不可用** | 任意核心"必须"项失败 |

---

## 4. 执行步骤

### Phase 1: 环境确认
1. [ ] 确认 BIOS 设置 (Above 4G Decoding, SR-IOV)
2. [ ] 确认电源 ≥2000W
3. [ ] 清洁前置防尘网
4. [ ] 确认机房温度 ≤25°C

### Phase 2: 软件修复
1. [ ] 修复 `libncc.so.2` 链接（如未修复）
2. [ ] 安装/修复 `libnfort_m.so.2`（AVEO 依赖）
3. [ ] 查找 `mpirun` 安装方案
4. [ ] 安装 `veosinfo` 开发头文件

### Phase 3: 编译与验证
1. [ ] `make all` 编译全部测试程序
2. [ ] 单卡功能验证（逐卡运行 Hello World）
3. [ ] 多卡并行验证

### Phase 4: 性能基准
1. [ ] 单卡 MatMul 基线
2. [ ] HBM 带宽测试
3. [ ] 三卡总吞吐量
4. [ ] 温度与功耗监控

### Phase 5: 稳定性
1. [ ] 30 分钟连续压力测试
2. [ ] 频繁创建/销毁测试
3. [ ] 故障隔离测试

---

## 5. 风险与回退方案

| 风险 | 概率 | 影响 | 回退方案 |
|------|------|------|---------|
| AVEO 库无法修复 | 中 | AVEO/PCIe 测试 SKIP | 使用 vecmd 和 ve_exec 替代 AVEO |
| MPI 运行时缺失 | 中 | MPI 测试 SKIP | 使用独立进程并行替代 MPI |
| 散热不足导致降频 | 低 | 性能不达标 | 降低负载运行，改善机房环境 |
| 电源功率不足 | 低 | 系统不稳定 | 限制同时运行的卡数 |

---

*文档版本: 1.0*  
*计划依据: NEC_VE_Installation_Report.md, Three_Card_Performance_Plan.md*
