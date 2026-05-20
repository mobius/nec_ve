# NEC VE 1.0 三卡系统测试案例

> 服务器: 华硕 ESC4000 G4 / Z11PG-D16  
> 配置: 2x Intel Xeon Gold 6252 + 3x NEC VE 1.0 (10B-P/10BE-P 混装)  
> OS: Rocky Linux 8.10 (4.18.0-553.124.1.el8_10.x86_64)  
> 驱动: ve_drv 3.6.1 / VEOS 3.6.1 / 编译器 NCC 5.4.1 / MPI 3.10.0  
> 测试时间: 2026-05-19

---

## 目录

1. [测试环境确认](#1-测试环境确认)
2. [硬件识别测试 (TC-HW-001 ~ TC-HW-004)](#2-硬件识别测试)
3. [驱动与VEOS状态测试 (TC-DRV-001 ~ TC-DRV-005)](#3-驱动与veos状态测试)
4. [单卡功能测试 (TC-FUNC-001 ~ TC-FUNC-006)](#4-单卡功能测试)
5. [多卡并行功能测试 (TC-MULT-001 ~ TC-MULT-005)](#5-多卡并行功能测试)
6. [性能基准测试 (TC-PERF-001 ~ TC-PERF-006)](#6-性能基准测试)
7. [稳定性与压力测试 (TC-STRS-001 ~ TC-STRS-003)](#7-稳定性与压力测试)
8. [NUMA亲和性测试 (TC-NUMA-001 ~ TC-NUMA-003)](#8-numa亲和性测试)
9. [故障恢复测试 (TC-FAIL-001 ~ TC-FAIL-002)](#9-故障恢复测试)
10. [测试汇总与通过标准](#10-测试汇总与通过标准)

---

## 1. 测试环境确认

### 前置条件

| 项目 | 要求 | 检查命令 |
|------|------|---------|
| OS 版本 | Rocky Linux 8.10 | `cat /etc/rocky-release` |
| 内核版本 | 4.18.0-553.124.1.el8_10.x86_64 | `uname -r` |
| 内存容量 | ≥128GB (推荐 256GB) | `free -h` |
| 电源功率 | ≥2000W | `ipmitool sdr type "Power Supply"` |
| BIOS 设置 | Above 4G Decoding=Enabled, SR-IOV=Enabled | 进入 BIOS 确认 |
| 软件包 | ve-devel, nec-sdk-devel, nec-mpi-devel 已安装 | `yum grouplist \| grep ve` |
| PATH | `/opt/nec/ve/bin` 在 PATH 中 | `which ve_exec` |

---

## 2. 硬件识别测试

### TC-HW-001: PCIe 设备识别

| 属性 | 内容 |
|------|------|
| **目的** | 确认系统通过 PCIe 正确识别 3 张 VE 卡 |
| **前置条件** | 系统已开机，驱动已加载 |
| **测试步骤** | 1. 执行 `lspci \| grep "NEC"` <br> 2. 记录每张卡的 PCIe 地址 <br> 3. 确认 Device ID 为 `1bcf:001c` |
| **预期结果** | 输出包含 3 行 NEC Vector Engine 1.0，分别对应不同 PCIe 地址 |
| **通过标准** | `lspci` 识别到 3 张 `NEC Corporation Vector Engine 1.0` |

```bash
# 执行命令
lspci | grep "NEC"

# 预期输出示例
17:00.0 Co-processor: NEC Corporation Vector Engine 1.0 (rev 01)
ae:00.0 Co-processor: NEC Corporation Vector Engine 1.0 (rev 01)
d7:00.0 Co-processor: NEC Corporation Vector Engine 1.0 (rev 01)
```

---

### TC-HW-002: PCIe 链路速度与宽度验证

| 属性 | 内容 |
|------|------|
| **目的** | 确认每张卡都运行在 Gen3 x16 全速模式 |
| **前置条件** | TC-HW-001 通过 |
| **测试步骤** | 对每张卡的 PCIe 地址执行 `lspci -vv -s <BDF> \| grep -E "LnkCap:\|LnkSta:"` |
| **预期结果** | 所有卡的 `LnkSta` 显示 `Speed 8GT/s, Width x16` |
| **通过标准** | 3 张卡链路状态均为 `Speed 8GT/s (ok), Width x16 (ok)` |

```bash
# 对每张卡执行（替换为实际 PCIe 地址）
for dev in 17:00.0 ae:00.0 d7:00.0; do
    echo "=== $dev ==="
    lspci -vv -s $dev | grep -E "LnkCap:|LnkSta:"
done

# 预期输出
=== 17:00.0 ===
        LnkCap: Port #0, Speed 8GT/s, Width x16
        LnkSta: Speed 8GT/s (ok), Width x16 (ok)
=== ae:00.0 ===
        LnkCap: Port #0, Speed 8GT/s, Width x16
        LnkSta: Speed 8GT/s (ok), Width x16 (ok)
=== d7:00.0 ===
        LnkCap: Port #0, Speed 8GT/s, Width x16
        LnkSta: Speed 8GT/s (ok), Width x16 (ok)
```

---

### TC-HW-003: NUMA 节点分配验证

| 属性 | 内容 |
|------|------|
| **目的** | 确认每张卡所属的 NUMA 节点，为后续亲和性优化提供依据 |
| **前置条件** | TC-HW-001 通过 |
| **测试步骤** | 对每张卡执行 `lspci -vv -s <BDF> \| grep "NUMA"` |
| **预期结果** | 记录每张卡的 NUMA 分配（建议 CPU0 2张，CPU1 1张） |
| **通过标准** | 所有卡均有明确的 NUMA node 绑定 |

```bash
# 查看 NUMA 分配
for dev in 17:00.0 ae:00.0 d7:00.0; do
    echo -n "$dev: "
    lspci -vv -s $dev | grep "NUMA" || echo "NUMA node: (check manually)"
done

# 同时查看 numactl 的硬件拓扑
numactl --hardware
```

---

### TC-HW-004: 设备节点存在性检查

| 属性 | 内容 |
|------|------|
| **目的** | 确认 VEOS 为每张卡创建了对应的设备节点 |
| **前置条件** | VEOS 服务已启动 |
| **测试步骤** | 1. 执行 `ls -la /dev/ve*` <br> 2. 执行 `ls -la /dev/veslot*` |
| **预期结果** | 存在 `/dev/ve0`, `/dev/ve1`, `/dev/ve2` 和对应的 `veslot*` |
| **通过标准** | 恰好 3 个 VE 设备节点和 3 个 veslot 节点 |

```bash
ls -la /dev/ve* /dev/veslot*

# 预期输出
lrwxrwxrwx 1 root root ... /dev/ve0 -> veslot0
crw-rw---- 1 root root ... /dev/veslot0
lrwxrwxrwx 1 root root ... /dev/ve1 -> veslot1
crw-rw---- 1 root root ... /dev/veslot1
lrwxrwxrwx 1 root root ... /dev/ve2 -> veslot2
crw-rw---- 1 root root ... /dev/veslot2
```

---

## 3. 驱动与VEOS状态测试

### TC-DRV-001: VEOS 服务状态检查

| 属性 | 内容 |
|------|------|
| **目的** | 确认每张卡对应的 VEOS 服务已启动 |
| **前置条件** | 系统已重启，驱动自动加载 |
| **测试步骤** | `systemctl status ve-os-launcher@{0,1,2}.service` |
| **预期结果** | 3 个服务均显示 `active (running)` |
| **通过标准** | 所有 ve-os-launcher 实例均为 active 状态 |

```bash
for i in 0 1 2; do
    echo "=== ve-os-launcher@$i ==="
    systemctl is-active ve-os-launcher@$i.service
done
```

---

### TC-DRV-002: VE 卡状态查询

| 属性 | 内容 |
|------|------|
| **目的** | 确认每张 VE 卡处于 ONLINE 状态 |
| **前置条件** | TC-DRV-001 通过 |
| **测试步骤** | `sudo /opt/nec/ve/bin/vecmd state get` |
| **预期结果** | 3 张卡均显示 `[ ONLINE ]` |
| **通过标准** | 所有卡状态为 ONLINE，无 OFFLINE/DEGRADED |

```bash
sudo /opt/nec/ve/bin/vecmd state get

# 预期输出
VE0 [xx:00.0] [ ONLINE ] Last Modif:2026/05/19 xx:xx:xx
VE1 [xx:00.0] [ ONLINE ] Last Modif:2026/05/19 xx:xx:xx
VE2 [xx:00.0] [ ONLINE ] Last Modif:2026/05/19 xx:xx:xx
Result: Success
```

---

### TC-DRV-003: 固件版本一致性检查

| 属性 | 内容 |
|------|------|
| **目的** | 确认 3 张卡固件版本一致，避免混装带来的兼容性问题 |
| **前置条件** | TC-DRV-002 通过 |
| **测试步骤** | 对每张卡执行 `sudo /opt/nec/ve/bin/vecmd fwup -N <N> check` |
| **预期结果** | 3 张卡固件版本号相同 |
| **通过标准** | 所有卡固件版本一致；如不一致需统一升级 |

```bash
for i in 0 1 2; do
    echo "=== VE$i ==="
    sudo /opt/nec/ve/bin/vecmd fwup -N $i check 2>&1
done
```

---

### TC-DRV-004: 内核模块加载检查

| 属性 | 内容 |
|------|------|
| **目的** | 确认 VE 相关内核模块已正确加载 |
| **前置条件** | 系统已启动 |
| **测试步骤** | `lsmod \| grep -E "ve_drv\|vp"` |
| **预期结果** | `ve_drv` 和 `vp` 模块已加载 |
| **通过标准** | `ve_drv` 和 `vp` 均出现在 lsmod 输出中 |

```bash
lsmod | grep -E "ve_drv|vp"

# 预期输出
ve_drv                ...  0
vp                    ...  0
```

---

### TC-DRV-005: 驱动日志无异常

| 属性 | 内容 |
|------|------|
| **目的** | 确认系统日志中无 VE 驱动相关错误 |
| **前置条件** | 系统已运行一段时间 |
| **测试步骤** | `dmesg \| grep -i -E "ve_drv\|vecmd\|error\|fail"` |
| **预期结果** | 无 ERROR/FAIL 级别日志 |
| **通过标准** | dmesg 中无 VE 相关错误信息 |

```bash
dmesg | grep -i -E "ve_drv|vecmd" | grep -i -E "error|fail|warn"
# 应无输出或仅有信息性日志
```

---

## 4. 单卡功能测试

### TC-FUNC-001: Hello World 基础运行（逐卡验证）

| 属性 | 内容 |
|------|------|
| **目的** | 确认每张卡都能独立执行最基本的 VE 程序 |
| **前置条件** | 编译器已安装，示例程序已编译 |
| **测试步骤** | 对每张卡执行 `ve_exec -N <N> ./sample_bin` |
| **预期结果** | 每张卡均输出 `Hello World` |
| **通过标准** | 3 张卡全部正确输出 |

```bash
# 编译
source /etc/profile.d/nec-ve.sh
cd /tmp/examples/cmake/cmake_projects/C/build

# 逐卡测试
for i in 0 1 2; do
    echo "=== VE$i ==="
    ve_exec -N $i ./sample_bin
done

# 预期输出
=== VE0 ===
Hello World
=== VE1 ===
Hello World
=== VE2 ===
Hello World
```

---

### TC-FUNC-002: 浮点向量点积（逐卡验证）

| 属性 | 内容 |
|------|------|
| **目的** | 确认每张卡的向量浮点单元和精度正常 |
| **前置条件** | `ve_float_test` 已编译 |
| **测试步骤** | 对每张卡执行 `ve_exec -N <N> /tmp/ve_float_test` |
| **预期结果** | 结果精度误差为 0，显示 PASS |
| **通过标准** | 3 张卡均输出 PASS，精度误差 `0.0000000000e+00` |

```bash
for i in 0 1 2; do
    echo "=== VE$i ==="
    ve_exec -N $i /tmp/ve_float_test 2>&1 | tail -5
done
```

---

### TC-FUNC-003: 矩阵乘法（逐卡验证）

| 属性 | 内容 |
|------|------|
| **目的** | 确认每张卡的缓存、寄存器和内存子系统正常 |
| **前置条件** | `ve_matmul` 已编译 |
| **测试步骤** | 对每张卡执行 `ve_exec -N <N> /tmp/ve_matmul` |
| **预期结果** | 每张卡输出 PASS，性能在 30-40 GFLOPS 范围 |
| **通过标准** | 3 张卡均 PASS，单卡性能 ≥30 GFLOPS |

```bash
for i in 0 1 2; do
    echo "=== VE$i ==="
    ve_exec -N $i /tmp/ve_matmul 2>&1 | tail -5
done
```

---

### TC-FUNC-004: HBM 内存容量检测

| 属性 | 内容 |
|------|------|
| **目的** | 确认每张卡都能访问完整的 48GB HBM2 |
| **前置条件** | 已编写内存检测程序 |
| **测试步骤** | 编译并运行 HBM 容量检测程序 |
| **预期结果** | 每张卡报告可用内存约 48GB |
| **通过标准** | 单卡可用内存 ≥47GB |

```bash
# 使用 veosinfo 查询
cat << 'EOF' > /tmp/ve_mem_check.c
#include <stdio.h>
#include <stdlib.h>
#include <veosinfo.h>

int main(int argc, char *argv[]) {
    int node = atoi(argv[1]);
    struct ve_nodeinfo info;
    
    if (ve_node_info(&info) != 0) {
        perror("ve_node_info");
        return 1;
    }
    
    if (node >= info.total_node_count) {
        printf("Invalid node %d, only %d nodes\n", node, info.total_node_count);
        return 1;
    }
    
    printf("VE%d: Total Memory = %lu MB (%.1f GB)\n",
           node,
           info.node_info[node].total_mem,
           info.node_info[node].total_mem / 1024.0);
    printf("VE%d: Free Memory = %lu MB (%.1f GB)\n",
           node,
           info.node_info[node].free_mem,
           info.node_info[node].free_mem / 1024.0);
    return 0;
}
EOF

nc++ -o /tmp/ve_mem_check /tmp/ve_mem_check.c -lveosinfo

for i in 0 1 2; do
    echo "=== VE$i ==="
    /tmp/ve_mem_check $i
done
```

---

### TC-FUNC-005: 编译器优化报告验证

| 属性 | 内容 |
|------|------|
| **目的** | 确认编译器对测试代码的向量化优化正常 |
| **前置条件** | 测试源码可用 |
| **测试步骤** | 使用 `-report-all` 编译，检查优化报告 |
| **预期结果** | 关键循环显示 `Vectorized loop` |
| **通过标准** | 无 `Vectorization obstructive` 严重阻碍 |

```bash
nc++ -O3 -report-all -o /tmp/ve_matmul_test /tmp/ve_matmul.c 2>&1 | grep -E "Vectorized|Obstructive"
```

---

### TC-FUNC-006: VE 程序加载与卸载稳定性

| 属性 | 内容 |
|------|------|
| **目的** | 验证单卡重复加载程序无内存泄漏或状态异常 |
| **前置条件** | TC-FUNC-001 通过 |
| **测试步骤** | 对每张卡连续运行 10 次 Hello World |
| **预期结果** | 10 次全部成功，无崩溃 |
| **通过标准** | 成功率 100%，`vecmd state get` 仍为 ONLINE |

```bash
for card in 0 1 2; do
    echo "=== VE$card 重复测试 ==="
    for run in $(seq 1 10); do
        ve_exec -N $card ./sample_bin > /dev/null || echo "FAIL on run $run"
    done
    echo "VE$card 完成"
done
```

---

## 5. 多卡并行功能测试

### TC-MULT-001: 多卡独立任务并行（Embarrassingly Parallel）

| 属性 | 内容 |
|------|------|
| **目的** | 验证 3 张卡可同时运行独立任务 |
| **前置条件** | TC-FUNC-001 通过 |
| **测试步骤** | 后台同时启动 3 个任务，分别绑定到 3 张卡 |
| **预期结果** | 3 个任务同时完成，输出正确 |
| **通过标准** | 总耗时 ≈ 单卡耗时，证明真正并行 |

```bash
cat << 'EOF' > /tmp/multi_independent_test.sh
#!/bin/bash
set -e

BINARY="/tmp/examples/cmake/cmake_projects/C/build/sample_bin"

echo "开始多卡独立并行测试..."
START=$(date +%s.%N)

# 同时启动 3 个任务
ve_exec -N 0 $BINARY > /tmp/ve0_out.txt &
PID0=$!
ve_exec -N 1 $BINARY > /tmp/ve1_out.txt &
PID1=$!
ve_exec -N 2 $BINARY > /tmp/ve2_out.txt &
PID2=$!

wait $PID0
wait $PID1
wait $PID2

END=$(date +%s.%N)
ELAPSED=$(echo "$END - $START" | bc)

echo "总耗时: ${ELAPSED}s"

# 验证输出
for i in 0 1 2; do
    OUT=$(cat /tmp/ve${i}_out.txt)
    if [ "$OUT" = "Hello World" ]; then
        echo "VE$i: PASS"
    else
        echo "VE$i: FAIL - 输出='$OUT'"
    fi
done
EOF
chmod +x /tmp/multi_independent_test.sh
/tmp/multi_independent_test.sh
```

---

### TC-MULT-002: 多卡运行不同任务负载

| 属性 | 内容 |
|------|------|
| **目的** | 验证不同计算密度的任务可在不同卡上混合运行 |
| **前置条件** | 浮点测试和矩阵乘法均已编译 |
| **测试步骤** | VE0 运行点积，VE1 运行矩阵乘法，VE2 运行 Hello World |
| **预期结果** | 3 个任务均正确完成 |
| **通过标准** | 所有任务输出正确，无交叉干扰 |

```bash
ve_exec -N 0 /tmp/ve_float_test > /tmp/ve0_load.txt &
ve_exec -N 1 /tmp/ve_matmul > /tmp/ve1_load.txt &
ve_exec -N 2 ./sample_bin > /tmp/ve2_load.txt &
wait

# 检查结果
grep "PASS" /tmp/ve0_load.txt && echo "VE0: PASS" || echo "VE0: FAIL"
grep "PASS" /tmp/ve1_load.txt && echo "VE1: PASS" || echo "VE1: FAIL"
grep "Hello World" /tmp/ve2_load.txt && echo "VE2: PASS" || echo "VE2: FAIL"
```

---

### TC-MULT-003: MPI 跨卡通信基础测试

| 属性 | 内容 |
|------|------|
| **目的** | 验证 NEC MPI 可在 3 张卡之间建立通信 |
| **前置条件** | NEC MPI 已安装，MPI Hello World 已编译 |
| **测试步骤** | 使用 `mpirun -ve 0-2 -np 3 ./mpi_hello` |
| **预期结果** | 3 个 rank 分别输出，包含卡号信息 |
| **通过标准** | 3 个 rank 均正常输出，无 MPI 错误 |

```bash
# 编译 MPI Hello World
cat << 'EOF' > /tmp/mpi_hello.c
#include <mpi.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
    int rank, size;
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    printf("Hello from rank %d of %d\n", rank, size);
    MPI_Finalize();
    return 0;
}
EOF

source /opt/nec/ve/mpi/3.10.0/bin/necmpivars.sh
mpicc -o /tmp/mpi_hello /tmp/mpi_hello.c

# 运行（3 个进程分别跑在 3 张卡上）
mpirun -ve 0-2 -np 3 /tmp/mpi_hello

# 预期输出
Hello from rank 0 of 3
Hello from rank 1 of 3
Hello from rank 2 of 3
```

---

### TC-MULT-004: MPI AllReduce 跨卡集合通信

| 属性 | 内容 |
|------|------|
| **目的** | 验证跨卡 MPI 集合通信功能正确 |
| **前置条件** | TC-MULT-003 通过 |
| **测试步骤** | 编译运行 MPI AllReduce 测试 |
| **预期结果** | AllReduce 结果数学正确 |
| **通过标准** | 集合通信结果与理论值一致 |

```bash
cat << 'EOF' > /tmp/mpi_allreduce_test.c
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    int rank, size;
    double local = 1.0;
    double global = 0.0;
    
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    
    MPI_Allreduce(&local, &global, 1, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
    
    if (rank == 0) {
        printf("AllReduce result: %.1f (expected: %d)\n", global, size);
        if (global == size) {
            printf("MPI AllReduce: PASS\n");
        } else {
            printf("MPI AllReduce: FAIL\n");
        }
    }
    
    MPI_Finalize();
    return 0;
}
EOF

mpicc -o /tmp/mpi_allreduce_test /tmp/mpi_allreduce_test.c
mpirun -ve 0-2 -np 3 /tmp/mpi_allreduce_test
```

---

### TC-MULT-005: AVEO 多设备创建与销毁

| 属性 | 内容 |
|------|------|
| **目的** | 验证 AVEO API 可正确同时操作 3 张卡 |
| **前置条件** | AVEO 库已安装 |
| **测试步骤** | 编写程序同时创建 3 个 veo_proc_handle |
| **预期结果** | 3 个 handle 均成功创建和销毁 |
| **通过标准** | 无 API 错误返回 |

```bash
cat << 'EOF' > /tmp/aveo_multi_test.c
#include <stdio.h>
#include <veo_api.h>

int main() {
    struct veo_proc_handle *proc[3];
    int i;
    
    for (i = 0; i < 3; i++) {
        proc[i] = veo_proc_create(i);
        if (proc[i] == NULL) {
            printf("VE%d: proc_create FAILED\n", i);
            return 1;
        }
        printf("VE%d: proc_create OK\n", i);
    }
    
    for (i = 0; i < 3; i++) {
        int ret = veo_proc_destroy(proc[i]);
        printf("VE%d: proc_destroy %s\n", i, ret == 0 ? "OK" : "FAILED");
    }
    
    printf("AVEO Multi-Device: PASS\n");
    return 0;
}
EOF

nc++ -o /tmp/aveo_multi_test /tmp/aveo_multi_test.c -lveo
/tmp/aveo_multi_test
```

---

## 6. 性能基准测试

### TC-PERF-001: 单卡矩阵乘法性能基准

| 属性 | 内容 |
|------|------|
| **目的** | 建立单卡性能基线 |
| **前置条件** | 矩阵乘法程序已编译，系统空载 |
| **测试步骤** | 逐卡运行 512×512 矩阵乘法，记录 GFLOPS |
| **预期结果** | 每张卡 30-40 GFLOPS |
| **通过标准** | 所有卡 ≥30 GFLOPS，卡间差异 <10% |

```bash
echo "=== 单卡矩阵乘法性能基准 ==="
for i in 0 1 2; do
    echo -n "VE$i: "
    ve_exec -N $i /tmp/ve_matmul 2>&1 | grep "GFlops:"
done
```

---

### TC-PERF-002: 内存带宽测试

| 属性 | 内容 |
|------|------|
| **目的** | 测量每张卡 HBM2 实际带宽 |
| **前置条件** | 已准备带宽测试程序 |
| **测试步骤** | 对每张卡运行 STREAM-like 带宽测试 |
| **预期结果** | 单卡带宽 ~800-1000 GB/s |
| **通过标准** | 单卡 ≥600 GB/s |

```bash
cat << 'EOF' > /tmp/ve_bandwidth.c
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <string.h>

#define N (1024 * 1024 * 1024 / 8)  // 1GB of doubles
#define NTIMES 10

static double a[N], b[N], c[N];

double mysecond() {
    struct timeval tp;
    gettimeofday(&tp, NULL);
    return (double)tp.tv_sec + (double)tp.tv_usec / 1e6;
}

int main() {
    double times[NTIMES];
    double avgtime;
    double bytes = 3 * sizeof(double) * N;
    
    for (int i = 0; i < N; i++) {
        a[i] = 1.0;
        b[i] = 2.0;
    }
    
    for (int k = 0; k < NTIMES; k++) {
        times[k] = mysecond();
        for (int i = 0; i < N; i++) {
            c[i] = a[i] + b[i];
        }
        times[k] = mysecond() - times[k];
    }
    
    avgtime = 0;
    for (int k = 1; k < NTIMES; k++) avgtime += times[k];
    avgtime /= (NTIMES - 1);
    
    printf("Avg time: %.6f sec\n", avgtime);
    printf("Bandwidth: %.2f GB/s\n", bytes / avgtime / 1e9);
    return 0;
}
EOF

nc++ -O3 -o /tmp/ve_bandwidth /tmp/ve_bandwidth.c

for i in 0 1 2; do
    echo "=== VE$i 带宽测试 ==="
    ve_exec -N $i /tmp/ve_bandwidth
done
```

---

### TC-PERF-003: 三卡并行总吞吐量

| 属性 | 内容 |
|------|------|
| **目的** | 测量 3 张卡同时工作时的总计算吞吐量 |
| **前置条件** | TC-PERF-001 基线已建立 |
| **测试步骤** | 3 张卡同时运行矩阵乘法，记录总 GFLOPS |
| **预期结果** | 总吞吐量 ≈ 3× 单卡吞吐量 |
| **通过标准** | 并行效率 ≥85% |

```bash
cat << 'EOF' > /tmp/triple_throughput.sh
#!/bin/bash
START=$(date +%s.%N)

ve_exec -N 0 /tmp/ve_matmul > /tmp/perf0.txt &
ve_exec -N 1 /tmp/ve_matmul > /tmp/perf1.txt &
ve_exec -N 2 /tmp/ve_matmul > /tmp/perf2.txt &
wait

END=$(date +%s.%N)
ELAPSED=$(echo "$END - $START" | bc)

GF0=$(grep "GFlops:" /tmp/perf0.txt | awk '{print $2}')
GF1=$(grep "GFlops:" /tmp/perf1.txt | awk '{print $2}')
GF2=$(grep "GFlops:" /tmp/perf2.txt | awk '{print $2}')
TOTAL=$(echo "$GF0 + $GF1 + $GF2" | bc)

echo "VE0: ${GF0} GFLOPS"
echo "VE1: ${GF1} GFLOPS"
echo "VE2: ${GF2} GFLOPS"
echo "Total: ${TOTAL} GFLOPS"
echo "Parallel Time: ${ELAPSED}s"
EOF
chmod +x /tmp/triple_throughput.sh
/tmp/triple_throughput.sh
```

---

### TC-PERF-004: 主机到 VE 数据传输带宽

| 属性 | 内容 |
|------|------|
| **目的** | 测量 PCIe 数据传输瓶颈 |
| **前置条件** | AVEO/VEDA 程序可用 |
| **测试步骤** | 测量 Host→VE 和 VE→Host 的 memcpy 带宽 |
| **预期结果** | 接近 PCIe Gen3 x16 理论值 ~16 GB/s |
| **通过标准** | 双向带宽 ≥12 GB/s |

```bash
cat << 'EOF' > /tmp/aveo_bandwidth.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <veo_api.h>

#define SIZE (1024 * 1024 * 100)  // 100MB
#define ITER 10

double get_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

int main(int argc, char *argv[]) {
    int node = (argc > 1) ? atoi(argv[1]) : 0;
    struct veo_proc_handle *proc = veo_proc_create(node);
    if (!proc) { printf("proc_create failed\n"); return 1; }
    
    uint64_t ve_ptr = veo_alloc_mem(proc, SIZE);
    char *host_buf = (char*)malloc(SIZE);
    memset(host_buf, 0xAB, SIZE);
    
    // H2D
    double start = get_time();
    for (int i = 0; i < ITER; i++) {
        veo_write_mem(proc, ve_ptr, host_buf, SIZE);
    }
    double h2d_time = (get_time() - start) / ITER;
    
    // D2H
    start = get_time();
    for (int i = 0; i < ITER; i++) {
        veo_read_mem(proc, host_buf, ve_ptr, SIZE);
    }
    double d2h_time = (get_time() - start) / ITER;
    
    double bw_h2d = (SIZE / h2d_time) / 1e9;
    double bw_d2h = (SIZE / d2h_time) / 1e9;
    
    printf("VE%d H2D: %.2f GB/s\n", node, bw_h2d);
    printf("VE%d D2H: %.2f GB/s\n", node, bw_d2h);
    
    veo_free_mem(proc, ve_ptr);
    veo_proc_destroy(proc);
    free(host_buf);
    return 0;
}
EOF

nc++ -o /tmp/aveo_bandwidth /tmp/aveo_bandwidth.c -lveo

for i in 0 1 2; do
    echo "=== VE$i PCIe 带宽 ==="
    /tmp/aveo_bandwidth $i
done
```

---

### TC-PERF-005: MPI Ping-Pong 延迟测试

| 属性 | 内容 |
|------|------|
| **目的** | 测量跨卡 MPI 通信延迟 |
| **前置条件** | MPI 已配置 |
| **测试步骤** | 运行标准 Ping-Pong 测试 |
| **预期结果** | 延迟在几十微秒级别 |
| **通过标准** | 小消息延迟 <100μs |

```bash
cat << 'EOF' > /tmp/mpi_pingpong.c
#include <mpi.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
    int rank, size;
    char msg[1];
    MPI_Status status;
    double t1, t2;
    
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    
    if (size != 2) {
        if (rank == 0) printf("Run with exactly 2 ranks\n");
        MPI_Finalize();
        return 1;
    }
    
    if (rank == 0) {
        t1 = MPI_Wtime();
        for (int i = 0; i < 1000; i++) {
            MPI_Send(msg, 1, MPI_CHAR, 1, 0, MPI_COMM_WORLD);
            MPI_Recv(msg, 1, MPI_CHAR, 1, 0, MPI_COMM_WORLD, &status);
        }
        t2 = MPI_Wtime();
        double latency = (t2 - t1) / 1000.0 * 1e6 / 2.0;
        printf("Ping-pong latency: %.2f us\n", latency);
    } else {
        for (int i = 0; i < 1000; i++) {
            MPI_Recv(msg, 1, MPI_CHAR, 0, 0, MPI_COMM_WORLD, &status);
            MPI_Send(msg, 1, MPI_CHAR, 0, 0, MPI_COMM_WORLD);
        }
    }
    
    MPI_Finalize();
    return 0;
}
EOF

mpicc -o /tmp/mpi_pingpong /tmp/mpi_pingpong.c

# 测试跨卡组合
for pair in "0,1" "0,2" "1,2"; do
    IFS=',' read -r a b <<< "$pair"
    echo "=== VE$a <-> VE$b ==="
    mpirun -ve $a,$b -np 2 /tmp/mpi_pingpong
done
```

---

### TC-PERF-006: 整机功耗与温度监控

| 属性 | 内容 |
|------|------|
| **目的** | 测量三卡满载时的系统功耗和温度 |
| **前置条件** | IPMI/BMC 可访问，或系统有功耗传感器 |
| **测试步骤** | 三卡满载运行矩阵乘法，同时监控功耗 |
| **预期结果** | 功耗在 1000-1300W 范围，温度在安全范围 |
| **通过标准** | 无 thermal throttle，功耗在 PSU 额定范围内 |

```bash
cat << 'EOF' > /tmp/power_monitor.sh
#!/bin/bash
# 在三卡满载时运行此脚本

echo "时间,功耗(W),温度(C)" > /tmp/power_log.csv

for i in $(seq 1 30); do
    TIME=$(date '+%H:%M:%S')
    # 通过 IPMI 读取（如可用）
    POWER=$(ipmitool sdr get "PSU1 Power" 2>/dev/null | grep "Sensor Reading" | awk '{print $4}' || echo "N/A")
    TEMP=$(ipmitool sdr get "System Temp" 2>/dev/null | grep "Sensor Reading" | awk '{print $4}' || echo "N/A")
    echo "$TIME,$POWER,$TEMP" >> /tmp/power_log.csv
    sleep 10
done
EOF
chmod +x /tmp/power_monitor.sh

# 先启动监控，然后启动负载
/tmp/power_monitor.sh &
MON_PID=$!

# 三卡满载 5 分钟
for i in 0 1 2; do
    ve_exec -N $i /tmp/ve_matmul > /dev/null &
done
wait

kill $MON_PID 2>/dev/null
cat /tmp/power_log.csv
```

---

## 7. 稳定性与压力测试

### TC-STRS-001: 三卡连续计算压力测试（30分钟）

| 属性 | 内容 |
|------|------|
| **目的** | 验证三卡长时间高负载下的稳定性 |
| **前置条件** | TC-PERF-003 通过 |
| **测试步骤** | 循环运行矩阵乘法 30 分钟 |
| **预期结果** | 无崩溃、无 OFFLINE、无 ECC 错误 |
| **通过标准** | 30 分钟内 100% 成功率 |

```bash
cat << 'EOF' > /tmp/stress_loop.sh
#!/bin/bash
DURATION=1800  # 30 minutes
START=$(date +%s)
ITER=0
FAIL=0

echo "开始 30 分钟压力测试..."
while [ $(($(date +%s) - START)) -lt $DURATION ]; do
    ITER=$((ITER + 1))
    
    for i in 0 1 2; do
        ve_exec -N $i /tmp/ve_matmul > /tmp/stress_${i}_last.txt 2>&1 || FAIL=$((FAIL + 1)) &
    done
    wait
    
    if [ $((ITER % 10)) -eq 0 ]; then
        ELAPSED=$(($(date +%s) - START))
        echo "[$ELAPSED s] 完成 $ITER 轮，失败 $FAIL 次"
    fi
done

echo "测试完成: 总轮数=$ITER, 失败=$FAIL"
echo "最终状态:"
sudo /opt/nec/ve/bin/vecmd state get
EOF
chmod +x /tmp/stress_loop.sh
/tmp/stress_loop.sh
```

---

### TC-STRS-002: 频繁创建/销毁 VEOS 进程

| 属性 | 内容 |
|------|------|
| **目的** | 验证 VEOS 进程管理的稳定性 |
| **前置条件** | 系统正常运行 |
| **测试步骤** | 重复 50 次：启动程序→完成→退出 |
| **预期结果** | 无内存泄漏，无进程残留 |
| **通过标准** | 50 次全部成功，无僵尸进程 |

```bash
cat << 'EOF' > /tmp/ve_fork_bomb.sh
#!/bin/bash
FAIL=0
for i in $(seq 1 50); do
    for card in 0 1 2; do
        ve_exec -N $card ./sample_bin > /dev/null || FAIL=$((FAIL + 1)) &
    done
    wait
done
echo "失败次数: $FAIL"
ps aux | grep "ve_exec" | grep -v grep | wc -l
echo "残留 ve_exec 进程数（应为 0）"
EOF
chmod +x /tmp/ve_fork_bomb.sh
/tmp/ve_fork_bomb.sh
```

---

### TC-STRS-003: 温度监控与降频检测

| 属性 | 内容 |
|------|------|
| **目的** | 确认散热系统足够，无 thermal throttle |
| **前置条件** | 压力测试运行中 |
| **测试步骤** | 通过 `vecmd` 或传感器监控温度，对比性能数据 |
| **预期结果** | 温度稳定，性能不随时间下降 |
| **通过标准** | 无性能衰减 >5% |

```bash
cat << 'EOF' > /tmp/thermal_check.sh
#!/bin/bash
echo "轮次,VE0_GFLOPS,VE1_GFLOPS,VE2_GFLOPS" > /tmp/thermal_perf.csv

for round in $(seq 1 20); do
    for i in 0 1 2; do
        ve_exec -N $i /tmp/ve_matmul > /tmp/therm_${i}.txt 2>&1 &
    done
    wait
    
    GF0=$(grep "GFlops:" /tmp/therm_0.txt | awk '{print $2}')
    GF1=$(grep "GFlops:" /tmp/therm_1.txt | awk '{print $2}')
    GF2=$(grep "GFlops:" /tmp/therm_2.txt | awk '{print $2}')
    echo "$round,$GF0,$GF1,$GF2" >> /tmp/thermal_perf.csv
    
    sleep 5
done

echo "温度-性能数据:"
cat /tmp/thermal_perf.csv
EOF
chmod +x /tmp/thermal_check.sh
/tmp/thermal_check.sh
```

---

## 8. NUMA亲和性测试

### TC-NUMA-001: 同 NUMA 节点绑定测试

| 属性 | 内容 |
|------|------|
| **目的** | 验证 NUMA 亲和性绑定可提升性能 |
| **前置条件** | 已知每张卡的 NUMA 节点 |
| **测试步骤** | 使用 `numactl` 将 Host 进程绑定到卡所在 NUMA |
| **预期结果** | 绑定后 PCIe 带宽和延迟优于跨 NUMA |
| **通过标准** | 同 NUMA 性能 ≥ 跨 NUMA 性能 |

```bash
# 假设 VE0 在 NUMA0，VE1/VE2 在 NUMA1
# 需根据 TC-HW-003 结果调整

echo "=== 同 NUMA 绑定 ==="
numactl --cpunodebind=0 --membind=0 ve_exec -N 0 /tmp/ve_matmul | grep "GFlops:"
numactl --cpunodebind=1 --membind=1 ve_exec -N 1 /tmp/ve_matmul | grep "GFlops:"
numactl --cpunodebind=1 --membind=1 ve_exec -N 2 /tmp/ve_matmul | grep "GFlops:"

echo "=== 跨 NUMA 对比 ==="
numactl --cpunodebind=1 --membind=1 ve_exec -N 0 /tmp/ve_matmul | grep "GFlops:"
numactl --cpunodebind=0 --membind=0 ve_exec -N 1 /tmp/ve_matmul | grep "GFlops:"
```

---

### TC-NUMA-002: 多卡 NUMA 均衡负载

| 属性 | 内容 |
|------|------|
| **目的** | 验证 NUMA 均衡分布下的系统总吞吐量 |
| **前置条件** | TC-NUMA-001 通过 |
| **测试步骤** | 按 NUMA 分布绑定并同时运行 3 张卡 |
| **预期结果** | 均衡分布优于单 NUMA 集中 |
| **通过标准** | 均衡模式下无单 NUMA 瓶颈 |

```bash
cat << 'EOF' > /tmp/numa_balanced.sh
#!/bin/bash
# NUMA 均衡绑定
numactl --cpunodebind=0 --membind=0 ve_exec -N 0 /tmp/ve_matmul > /tmp/numa0.txt &
numactl --cpunodebind=1 --membind=1 ve_exec -N 1 /tmp/ve_matmul > /tmp/numa1.txt &
numactl --cpunodebind=1 --membind=1 ve_exec -N 2 /tmp/ve_matmul > /tmp/numa2.txt &
wait

echo "NUMA 均衡模式结果:"
grep "GFlops:" /tmp/numa0.txt
grep "GFlops:" /tmp/numa1.txt
grep "GFlops:" /tmp/numa2.txt
EOF
chmod +x /tmp/numa_balanced.sh
/tmp/numa_balanced.sh
```

---

### TC-NUMA-003: 主机内存带宽饱和测试

| 属性 | 内容 |
|------|------|
| **目的** | 验证主机内存不会成为三卡并行瓶颈 |
| **前置条件** | 已安装 stream 或类似工具 |
| **测试步骤** | 三卡同时做大数据量 H2D/D2H，监控主机内存带宽 |
| **预期结果** | 主机内存带宽未 100% 饱和 |
| **通过标准** | 主机内存使用率 <90% |

```bash
# 使用 vmstat / sar 监控内存带宽
# 或使用 Intel PCM 工具（如可用）

cat << 'EOF' > /tmp/host_mem_check.sh
#!/bin/bash
echo "监控主机内存带宽（使用 vmstat）..."
vmstat 1 60 > /tmp/vmstat.log &
VMSTAT_PID=$!

# 三卡同时大量数据传输
for i in 0 1 2; do
    /tmp/aveo_bandwidth $i &
done
wait

kill $VMSTAT_PID
echo "vmstat 日志已保存到 /tmp/vmstat.log"
EOF
chmod +x /tmp/host_mem_check.sh
/tmp/host_mem_check.sh
```

---

## 9. 故障恢复测试

### TC-FAIL-001: 单卡程序异常退出恢复

| 属性 | 内容 |
|------|------|
| **目的** | 验证单卡程序崩溃不影响其他卡 |
| **前置条件** | 三卡均 ONLINE |
| **测试步骤** | VE0 运行会导致段错误的程序，VE1/VE2 正常运行 |
| **预期结果** | VE0 程序崩溃，VE1/VE2 不受影响，VE0 可恢复 |
| **通过标准** | 故障隔离成功，VE0 再次运行正常 |

```bash
cat << 'EOF' > /tmp/ve_segfault.c
#include <stdio.h>
int main() {
    int *p = NULL;
    *p = 42;  // 故意段错误
    return 0;
}
EOF
nc++ -o /tmp/ve_segfault /tmp/ve_segfault.c

# VE0 运行故障程序
ve_exec -N 0 /tmp/ve_segfault 2>&1 &
BAD_PID=$!

# VE1/VE2 正常运行
ve_exec -N 1 ./sample_bin > /tmp/fail_test1.txt &
ve_exec -N 2 ./sample_bin > /tmp/fail_test2.txt &
wait

# 验证隔离
echo "VE0 状态:"
sudo /opt/nec/ve/bin/vecmd state get | grep VE0
echo "VE1/VE2 状态:"
sudo /opt/nec/ve/bin/vecmd state get | grep -E "VE1|VE2"

# 再次验证 VE0 可用
ve_exec -N 0 ./sample_bin
```

---

### TC-FAIL-002: VEOS 服务重启恢复

| 属性 | 内容 |
|------|------|
| **目的** | 验证 VEOS 服务重启后系统可恢复 |
| **前置条件** | 系统正常运行 |
| **测试步骤** | 停止并重启单卡 VEOS 服务 |
| **预期结果** | 服务重启后该卡恢复 ONLINE |
| **通过标准** | 重启后 `vecmd state get` 显示 ONLINE |

```bash
# 重启 VE0 的 VEOS
echo "重启 VE0 VEOS..."
sudo systemctl restart ve-os-launcher@0.service
sleep 5

# 检查状态
echo "VE0 状态:"
sudo /opt/nec/ve/bin/vecmd state get | grep VE0

# 功能验证
ve_exec -N 0 ./sample_bin
```

---

## 10. 测试汇总与通过标准

### 测试项汇总表

| 测试编号 | 测试名称 | 类别 | 权重 | 通过标准 |
|---------|---------|------|------|---------|
| TC-HW-001 | PCIe 设备识别 | 硬件 | 必须 | 3 张卡均识别 |
| TC-HW-002 | 链路速度验证 | 硬件 | 必须 | Gen3 x16 |
| TC-HW-003 | NUMA 分配验证 | 硬件 | 必须 | 有明确 NUMA 绑定 |
| TC-HW-004 | 设备节点检查 | 硬件 | 必须 | 3 个设备节点 |
| TC-DRV-001 | VEOS 服务状态 | 驱动 | 必须 | 全部 active |
| TC-DRV-002 | VE 卡状态 | 驱动 | 必须 | 全部 ONLINE |
| TC-DRV-003 | 固件一致性 | 驱动 | 必须 | 版本一致 |
| TC-DRV-004 | 内核模块 | 驱动 | 必须 | ve_drv, vp 已加载 |
| TC-DRV-005 | 驱动日志 | 驱动 | 必须 | 无 ERROR |
| TC-FUNC-001 | Hello World | 功能 | 必须 | 逐卡通过 |
| TC-FUNC-002 | 向量点积 | 功能 | 必须 | 精度 PASS |
| TC-FUNC-003 | 矩阵乘法 | 功能 | 必须 | ≥30 GFLOPS |
| TC-FUNC-004 | HBM 容量 | 功能 | 必须 | ≥47GB |
| TC-FUNC-005 | 编译器优化 | 功能 | 建议 | 向量化正常 |
| TC-FUNC-006 | 重复加载 | 功能 | 建议 | 100% 成功 |
| TC-MULT-001 | 多卡独立并行 | 多卡 | 必须 | 真正并行 |
| TC-MULT-002 | 混合负载 | 多卡 | 必须 | 无交叉干扰 |
| TC-MULT-003 | MPI 基础通信 | 多卡 | 必须 | 3 rank 正常 |
| TC-MULT-004 | MPI AllReduce | 多卡 | 建议 | 结果正确 |
| TC-MULT-005 | AVEO 多设备 | 多卡 | 建议 | 3 handle OK |
| TC-PERF-001 | 单卡性能基线 | 性能 | 必须 | ≥30 GFLOPS |
| TC-PERF-002 | 内存带宽 | 性能 | 必须 | ≥600 GB/s |
| TC-PERF-003 | 三卡总吞吐 | 性能 | 必须 | 效率 ≥85% |
| TC-PERF-004 | PCIe 带宽 | 性能 | 建议 | ≥12 GB/s |
| TC-PERF-005 | MPI 延迟 | 性能 | 建议 | <100μs |
| TC-PERF-006 | 功耗监控 | 性能 | 建议 | 无 throttle |
| TC-STRS-001 | 30分钟压力 | 稳定性 | 必须 | 0 失败 |
| TC-STRS-002 | 频繁创建销毁 | 稳定性 | 建议 | 0 残留 |
| TC-STRS-003 | 温度监控 | 稳定性 | 必须 | 无降频 |
| TC-NUMA-001 | NUMA 绑定 | 优化 | 建议 | 同 NUMA 更优 |
| TC-NUMA-002 | NUMA 均衡 | 优化 | 建议 | 无瓶颈 |
| TC-NUMA-003 | 内存饱和 | 优化 | 建议 | <90% |
| TC-FAIL-001 | 故障隔离 | 可靠性 | 建议 | 隔离成功 |
| TC-FAIL-002 | 服务恢复 | 可靠性 | 建议 | 可恢复 |

### 总体通过标准

| 等级 | 条件 |
|------|------|
| **完全通过** | 所有"必须"项通过 + 所有"建议"项通过 |
| **基本可用** | 所有"必须"项通过，"建议"项失败 ≤3 个 |
| **有条件可用** | "必须"项失败 ≤2 个，且为功能非核心项 |
| **不可用** | 任意核心"必须"项失败（HW/DRV/FUNC/STRS） |

### 测试执行记录模板

| 日期 | 执行人 | 测试项 | 结果 | 备注 |
|------|--------|--------|------|------|
| | | | | |

---

*文档版本: 1.0*  
*创建时间: 2026-05-19*  
*适用系统: ESC4000G4 + 3x NEC VE 1.0 + Rocky Linux 8.10*
