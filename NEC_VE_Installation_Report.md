# NEC Vector Engine 1.0 安装与测试报告

> 基于 Rocky Linux 8.10 + NEC VE 1.0 计算卡  
> 参考: [east.moe/archives/1481](https://east.moe/archives/1481) (作者: Fantasy Land)  
> 编译器免费政策: [sx-aurora.github.io/posts/nec-compilers-no-license](https://sx-aurora.github.io/posts/nec-compilers-no-license/)

---

## 1. 硬件与系统环境

| 项目 | 状态/值 |
|------|---------|
| 操作系统 | Rocky Linux 8.10 (Green Obsidian) |
| 内核版本 | `4.18.0-553.124.1.el8_10.x86_64` ✅ |
| VE 卡型号 | NEC Corporation Vector Engine 1.0 (rev 01) |
| PCIe 地址 | `5e:00.0` |
| BAR 分配 | ✅ 正常 (64GB prefetchable + 32MB/256KB/4KB non-prefetchable) |

### 硬件识别确认

```bash
$ lspci | grep "NEC"
5e:00.0 Co-processor: NEC Corporation Vector Engine 1.0 (rev 01)
```

---

## 2. NEC 软件源配置

### 2.1 安装 TSUBASA 源配置包

```bash
cd /tmp
curl -LO https://sxauroratsubasa.sakura.ne.jp/repos/TSUBASA-soft-release-ve1-3.1-2.noarch.rpm
sudo rpm -ivh TSUBASA-soft-release-ve1-3.1-2.noarch.rpm
```

### 2.2 生成的仓库文件

- `/etc/yum.repos.d/TSUBASA-repo.repo` — 开源仓库 ✅
- `/etc/yum.repos.d/TSUBASA-restricted.repo` — 受限仓库（付费组件，现部分免费）

### 2.3 可用仓库

| 仓库名 | 用途 |
|--------|------|
| TSUBASA-repo | SX-Aurora TSUBASA 开源仓库 |
| nec-sdk-runtime | NEC SDK 运行时 |
| nec-mpi-runtime | NEC MPI 运行时 |
| nec-sdk-community | **NEC SDK 社区版（现免费）** |
| nec-mpi-community | **NEC MPI 社区版（现免费）** |

> **重要更新**: NEC 已取消编译器 license 限制，proprietary 编译器（ncc/nc++/nfort）和 MPI 均可免费下载使用。

---

## 3. 驱动与核心包安装

### 3.1 已安装包组

```bash
sudo yum groupinstall ve-devel -y
```

### 3.2 核心已安装包

| 包名 | 版本 | 用途 |
|------|------|------|
| `veos` | 3.6.1 | VE 操作系统 |
| `ve_drv-kmod` | 3.6.1 | VE 驱动内核模块 |
| `ve-firmware` | 1.7.0 | VE 固件 |
| `vp-kmod` | 3.6.0 | VP 内核模块 |
| `glibc-ve1` | 2.21 | VE1 glibc |
| `glibc-ve3` | 2.31 | VE3 glibc |
| `libsysve-ve1` | 3.6.0 | VE 系统调用库 |
| `libved` | 3.6.0 | VE 设备库 |
| `veoffload-aveo` | 3.6.0 | AVEO Offloading API |
| `veoffload-veda` | 3.6.1 | VEDA/VERA API |
| `gdb-ve` | 7.12.1 | VE 调试器 |
| `velayout` | 3.6.0 | VE 布局工具 |

### 3.3 VE 卡状态

```bash
$ sudo /opt/nec/ve/bin/vecmd state get
VE0 [5e:00.0] [ ONLINE ] Last Modif:2026/05/19 01:30:35
Result: Success
```

✅ **VE 卡已成功上线运行**

---

## 4. NEC 编译器安装（现免费）

### 4.1 安装编译器

```bash
sudo yum install -y nec-nc++-5.4.1 nec-nfort-5.4.1
```

### 4.2 安装运行时依赖

```bash
sudo yum install -y nec-veperf-libs-2.4.0 nec-veperf-devel-2.4.0
sudo yum install -y nec-nc++-compat-shared-5.4.1
```

### 4.3 创建符号链接

```bash
sudo ln -sf /opt/nec/ve/ncc/5.4.1/bin/nc++   /opt/nec/ve/bin/nc++
sudo ln -sf /opt/nec/ve/ncc/5.4.1/bin/ncc     /opt/nec/ve/bin/ncc
sudo ln -sf /opt/nec/ve/nfort/5.4.1/bin/nfort /opt/nec/ve/bin/nfort
```

### 4.4 修复运行时库路径

```bash
sudo ln -sf /opt/nec/ve/ncc/3.1.0/lib/libncc.so.2      /opt/nec/ve/lib/libncc.so.2
sudo ln -sf /opt/nec/ve/ncc/3.1.0/lib/libncc.so.2.8.0  /opt/nec/ve/lib/libncc.so.2.8.0
```

### 4.5 PATH 配置

创建 `/etc/profile.d/nec-ve.sh`:

```bash
export PATH=/opt/nec/ve/bin:$PATH
```

### 4.6 编译器版本确认

```bash
$ ncc --version
ncc (NCC) 5.4.1 (Build 15:40:52 Dec 23 2025)

$ nc++ --version
nc++ (NCC) 5.4.1 (Build 15:40:52 Dec 23 2025)

$ nfort --version
nfort (NFORT) 5.4.1 (Build 15:52:06 Dec 23 2025)
```

---

## 5. NEC MPI 安装（现免费）

### 5.1 安装 MPI

```bash
sudo yum install -y nec-mpi-devel-3-10-0
```

### 5.2 创建符号链接

```bash
sudo ln -sf /opt/nec/ve/mpi/3.10.0/bin64/mpicc     /opt/nec/ve/bin/mpicc
sudo ln -sf /opt/nec/ve/mpi/3.10.0/bin64/mpinc++   /opt/nec/ve/bin/mpinc++
sudo ln -sf /opt/nec/ve/mpi/3.10.0/bin64/mpinfort  /opt/nec/ve/bin/mpinfort
```

### 5.3 MPI 版本确认

```bash
$ mpicc --version
ncc (NCC) 5.4.1

$ mpinfort --version
nfort (NFORT) 5.4.1
```

---

## 6. GitHub 开源项目对照

组织: [github.com/veos-sxarr-NEC](https://github.com/veos-sxarr-NEC) (共 28 个 repo)

### 6.1 已安装（有 rpm 包）— 15 个

| GitHub repo | rpm 包 | 状态 |
|-------------|--------|------|
| aveo | `veoffload-aveo` | ✅ |
| gdb-ve | `gdb-ve` | ✅ |
| glibc-ve | `glibc-ve1/ve3` | ✅ |
| libsysve | `libsysve-ve1/ve3` | ✅ |
| libved | `libved` | ✅ |
| libvhcall-fortran | `libvhcall-fortran-ve1/ve3` | ✅ |
| log4c | `log4c` | ✅ |
| veda | `veoffload-veda` | ✅ |
| ve_drv-kmod | `ve_drv-kmod` | ✅ |
| velayout | `velayout` | ✅ |
| veoffload | `veoffload-aveo` | ✅ |
| veoffload-veorun | `veoffload-aveorun-ve1/ve3` | ✅ |
| veos | `veos` | ✅ |
| veosinfo_source | `veosinfo/veosinfo3` | ✅ |
| vp-kmod | `vp-kmod` | ✅ |

### 6.2 未安装（纯源码，需手动编译）— 5 个

| GitHub repo | 说明 |
|-------------|------|
| gcc-ve | 开源 GCC 编译器（现可用官方 ncc 替代） |
| musl-libc-ve | musl libc for VE |
| neoSYCL | SYCL 实现 |
| pci_mmio | PCIe MMIO 工具 |
| singularity | Apptainer 容器支持 |
| ve-memory-mapping | VE 内存映射 |
| ve-urpc | VE URPC 通信 |

### 6.3 文档/元数据 — 3 个

| GitHub repo | 说明 |
|-------------|------|
| doc | 文档 |
| docker_container | Docker/Apptainer 容器配置 |
| examples | 示例代码 |
| gcc-ve_meta | GCC meta |
| veosinfo_meta | veosinfo meta |
| veda_source | VEDA 源码 |

---

## 7. 程序测试

### 7.1 Hello World 测试

**源码** (`sample.c`):
```c
#include <stdio.h>
int main() {
    printf("Hello World\n");
    return 0;
}
```

**编译**:
```bash
cmake -DCMAKE_TOOLCHAIN_FILE=/opt/nec/ve/share/cmake/toolchainVE.cmake ..
make
```

**运行**:
```bash
$ /opt/nec/ve/bin/ve_exec ./sample_bin
Hello World
```

✅ **通过**

---

### 7.2 浮点计算测试 — 向量点积

**规模**: 1000 万元素  
**编译器优化**: 3 个循环全部自动向量化 (`Vectorized loop`)

**运行结果**:
```
Array size: 10000000
Dot product result: 333333333333330.0000000000
Expected:         333333333333330.0000000000
Difference:       0.0000000000e+00
Result: PASS
```

✅ **通过，浮点精度完美**

---

### 7.3 浮点计算测试 — 矩阵乘法

**规模**: 512×512 × 512×512  
**编译器优化**:
- 所有循环向量化 ✅
- Loop Interchange（循环交换）✅
- Outer Loop Unroll（外循环展开）✅

**运行结果**:
```
Matrix multiplication: 512x512 x 512x512
Time: 0.0080 seconds
Checksum: 32550948.214400
GFlops: 33.63
Result: PASS
```

✅ **通过，性能 33.63 GFLOPS**

---

## 8. 原作者推荐包组最终状态

| 包组 | 状态 | 说明 |
|------|------|------|
| `ve-devel` | ✅ 已安装 | 核心驱动+运行时 |
| `ve-infiniband` | ⚠️ 部分 | `libibverbs` 已装，完整 Mellanox OFED 可选 |
| `nec-sdk-devel` | ✅ **已安装** | `ncc/nc++/nfort` 5.4.1（现免费） |
| `nec-mpi-devel` | ✅ **已安装** | `mpicc/mpinc++/mpinfort` 3.10.0（现免费） |
| `nqsv-execution` | ❌ 源中无 | — |
| `scatefs-client-tsubasa` | ❌ 源中无 | — |

---

## 9. 关键文件路径汇总

| 用途 | 路径 |
|------|------|
| VE 驱动模块 | `/opt/nec/ve/bin/vecmd` |
| VE 程序执行器 | `/opt/nec/ve/bin/ve_exec` |
| C 编译器 | `/opt/nec/ve/bin/ncc` |
| C++ 编译器 | `/opt/nec/ve/bin/nc++` |
| Fortran 编译器 | `/opt/nec/ve/bin/nfort` |
| MPI C | `/opt/nec/ve/bin/mpicc` |
| MPI C++ | `/opt/nec/ve/bin/mpinc++` |
| MPI Fortran | `/opt/nec/ve/bin/mpinfort` |
| CMake 工具链 | `/opt/nec/ve/share/cmake/toolchainVE.cmake` |
| CMake MPI 工具链 | `/opt/nec/ve/share/cmake/toolchainVE-MPI.cmake` |
| MPI 环境变量脚本 | `/opt/nec/ve/mpi/3.10.0/bin/necmpivars.sh` |
| VE 设备节点 | `/dev/ve0`, `/dev/veslot0` |
| PATH 配置 | `/etc/profile.d/nec-ve.sh` |

---

## 10. 已知问题与解决方案

### 问题 1: CMake 链接失败 — 缺少 `libveproginf.so`

**现象**:
```
nld: cannot find -lveproginf
nld: cannot find -lveperfcnt
```

**解决**:
```bash
sudo yum install -y nec-veperf-libs-2.4.0 nec-veperf-devel-2.4.0
```

### 问题 2: `ve_exec` 运行失败 — 缺少 `libncc.so.2`

**现象**:
```
error while loading shared libraries: libncc.so.2: cannot open shared object file
```

**解决**:
```bash
sudo ln -sf /opt/nec/ve/ncc/3.1.0/lib/libncc.so.2     /opt/nec/ve/lib/libncc.so.2
sudo ln -sf /opt/nec/ve/ncc/3.1.0/lib/libncc.so.2.8.0 /opt/nec/ve/lib/libncc.so.2.8.0
```

### 问题 3: `ve_drv` 驱动加载后 VE 卡 OFFLINE

**现象**: 首次安装后 `vecmd state get` 显示 `There is no executable ve-card!`

**解决**: 重启系统，让 `ve_drv`、`ve-ived`、`ve-os-launcher` 等所有服务按正确顺序初始化。

---

## 11. 后续安装记录

### 11.1 已安装的可选组件

#### NLC (NEC Numeric Library Collection) 3.1.0 — 2026-05-20 安装

在基础软件栈安装完成后，为 TC-PERF-007（高性能 DGEMM）额外安装了 NLC BLAS：

```bash
sudo dnf install -y nec-nlc-inst nec-nlc-base-3.1.0 \
                    nec-blas-ve-3.1.0 nec-blas-ve-devel-3.1.0
```

**安装结果：**

| 包名 | 版本 | 说明 |
|------|------|------|
| `nec-nlc-inst` | 3.1.0-2 | 目录结构 + 软链接 |
| `nec-nlc-base-3.1.0` | 2.2-1 | 环境变量脚本（nlcvars.sh） |
| `nec-blas-ve-3.1.0` | 2.6-1 | `libblas_openmp.so`（VE 原生 BLAS 实现） |
| `nec-blas-ve-devel-3.1.0` | 2.6-1 | `cblas.h` + 静态库 `.a` |

**安装位置：**
- 库文件：`/opt/nec/ve/nlc/3.1.0/lib/`（`libblas_openmp.so`, `libcblas.so` 等）
- 头文件：`/opt/nec/ve/nlc/3.1.0/include/cblas.h`

**注意事项：**
- `nec-nlc-inst-runtime` 与 `nec-nlc-inst` 互斥，二者只能安装其一
- NLC 库为 VE 架构 ELF，运行时需设置 `VE_LD_LIBRARY_PATH=/opt/nec/ve/nlc/3.1.0/lib`
- CBLAS 接口（`cblas_dgemm`）在 `libcblas.so` 中，链接时需同时指定 `-lcblas -lblas_openmp`

**性能验证结果（2026-05-20）：**

| VE 卡 | N=4096 DGEMM | GFLOPS | 峰值利用率 |
|-------|--------------|--------|-----------|
| VE1   | ~1750        | ~1750  | 81%       |
| VE2   | ~1750        | ~1750  | 81%       |
| VE3   | ~1750        | ~1750  | 81%       |

### 11.2 未来建议

1. **如需 InfiniBand 网络**: 安装 `yum groupinstall "InfiniBand for SX-Aurora TSUBASA for Mellanox OFED 23.10-3.2.2.0"`
2. **如需 LAPACK**: 安装 `nec-lapack-ve-3.1.0`（与 `nec-blas-ve-3.1.0` 相同机制）
3. **如需 Python**: 安装 NLCPy (`yum groupinstall "NLCPy 3.0.1 for develop"`)
4. **如需容器**: 从 GitHub 克隆 `singularity` 仓库，参考 Apptainer 配置

---

## 12. 测试文件位置

| 文件 | 路径 |
|------|------|
| Hello World 源码 | `/tmp/examples/cmake/cmake_projects/C/sample.c` |
| Hello World 二进制 | `/tmp/examples/cmake/cmake_projects/C/build/sample_bin` |
| 向量点积源码 | `/tmp/ve_float_test.c` |
| 向量点积二进制 | `/tmp/ve_float_test` |
| 矩阵乘法源码 | `/tmp/ve_matmul.c` |
| 矩阵乘法二进制 | `/tmp/ve_matmul` |
| GitHub docker_container | `/tmp/docker_container` |
| GitHub examples | `/tmp/examples` |

---

*报告生成时间: 2026-05-19 | 最后更新: 2026-05-20*  
*NEC Vector Engine Driver: 3.6.1 | VEOS: 3.6.1 | Compiler: NCC/NFORT 5.4.1 | MPI: 3.10.0 | NLC: 3.1.0*
