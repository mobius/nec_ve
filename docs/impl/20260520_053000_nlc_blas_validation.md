# 20260520 NLC BLAS 验证记录

## 目标
安装并验证 NEC Numeric Library Collection (NLC) 3.1.0 的 cblas_dgemm 性能，
与自研 nfort 内核（433 GFLOPS）和理论峰值（2160 GFLOPS）对比。

## NLC 包安装路径

NLC 由多个包组成，需全部安装：

| 包名 | 来源 | 内容 |
|------|------|------|
| `nec-nlc-inst` | nec-sdk-community | 目录结构 + 软链接 |
| `nec-nlc-base-3.1.0` | nec-sdk-runtime | nlcvars.sh 脚本 |
| `nec-blas-ve-3.1.0` | nec-sdk-community | VE BLAS 运行时 `.so` |
| `nec-blas-ve-devel-3.1.0` | nec-sdk-community | 头文件 `cblas.h`、静态库 |

安装命令：
```bash
sudo dnf install -y nec-nlc-inst nec-nlc-base-3.1.0 \
  nec-blas-ve-3.1.0 nec-blas-ve-devel-3.1.0
```

关键路径：
- 头文件：`/opt/nec/ve/nlc/3.1.0/include/cblas.h`
- 动态库：`/opt/nec/ve/nlc/3.1.0/lib/libblas_openmp.so`（VE native ELF，machine 251）
- C BLAS 接口：`/opt/nec/ve/nlc/3.1.0/lib/libcblas.so`

## 编译方式

```makefile
NLC_HOME    = /opt/nec/ve/nlc/3.1.0
NLC_INC     = -I$(NLC_HOME)/include
NLC_LDFLAGS = -L$(NLC_HOME)/lib -lcblas -lblas_openmp -Wl,-rpath,$(NLC_HOME)/lib

ve_nlc_dgemm: ve_nlc_dgemm.c
    ncc -O3 -fopenmp $(NLC_INC) -o $@ $< $(NLC_LDFLAGS)
```

注意：`libcblas.so` 提供 C 接口（`cblas_dgemm`），`libblas_openmp.so` 提供 Fortran 接口（`dgemm_`）并做实际计算。两者必须同时链接。

运行时需设置：
```bash
export OMP_NUM_THREADS=8
export VE_LD_LIBRARY_PATH=/opt/nec/ve/nlc/3.1.0/lib
```

## 测试结果（N=4096，8 核，5 次取最大值）

| 卡 | NLC cblas_dgemm | 峰值占比 |
|----|----------------|---------|
| VE1 | **1734–1768 GFLOPS** | 80.3–81.9% |
| VE2 | **1732–1760 GFLOPS** | 80.2–81.5% |
| VE3 | **1720–1760 GFLOPS** | 79.6–81.5% |

## 性能对比全表

| 方法 | GFLOPS | 峰值占比 | 倍数 |
|------|--------|---------|------|
| 单线程 C（原始基线） | 54 | 2.5% | 1× |
| C + OpenMP k-blocking（ncc） | 155 | 7.2% | 2.9× |
| nfort 混合内核（C harness + Fortran DGEMM） | 433 | 20.0% | 8× |
| **NLC cblas_dgemm（本次）** | **~1750** | **~81%** | **32×** |
| 理论峰值 | 2160 | 100% | 40× |

## 根因分析

- **NLC BLAS 为何大幅领先 nfort 内核（4×）**：
  NLC BLAS 针对 VE 的 8×256-wide SIMD 寄存器做了手工汇编级调优，包括：
  - 多层 cache/TLB 感知 blocking（L1→L2→HBM 三级）
  - 软件流水（hide HBM latency）
  - register file 全利用（256 VR × 64-bit × 8 核 = 1024 SIMD lanes）
  - 与 nfort opt(1800) 的区别：opt(1800) 是编译器 idiom 识别，只能做单层优化；
    NLC 是 NEC 工程师手写的专用实现

- **剩余 19% 差距**：理论峰值假设每时钟同时发出 2 FMA（FP64 throughput），
  实际 DGEMM 受限于 B 矩阵的 HBM 预取效率，~81% 为当前 VE 1.0 上 DGEMM 的实际上界

## 新增文件
- `PerfTest/ve_nlc_dgemm.c`：NLC cblas_dgemm C 测试程序（5次运行取最大值）
- `PerfTest/scripts/perf_nlc_dgemm.sh`：TC-PERF-007 测试脚本（阈值 1200 GFLOPS）
- `PerfTest/Makefile`：新增 NLC 编译规则和 `ve_nlc_dgemm` 目标
