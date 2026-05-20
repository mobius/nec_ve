# PerfTest 测试套件实现记录

> 实现时间: 2026-05-19 22:55:57  
> 目标: 创建可运行的三卡 VE 测试套件

---

## 1. 目录结构

```
PerfTest/
├── Makefile                          # 编译管理
├── run_tests.sh                      # 主测试入口
├── sample.c                          # Hello World (VE)
├── ve_float_test.c                   # 向量点积 (VE)
├── ve_matmul.c                       # 矩阵乘法 512x512 (VE)
├── ve_bandwidth.c                    # STREAM-like HBM 带宽 (VE)
├── ve_mem_check.c                    # HBM 容量检测 (VE)
├── ve_segfault.c                     # 故障注入 (VE)
├── mpi_hello.c                       # MPI Hello World
├── mpi_allreduce_test.c              # MPI AllReduce
├── mpi_pingpong.c                    # MPI 延迟
├── aveo_multi_test.c                 # AVEO 多设备 (Host)
├── aveo_bandwidth.c                  # AVEO PCIe 带宽 (Host)
└── scripts/                          # 辅助脚本 (21个)
```

---

## 2. 关键发现

### 2.1 VE 卡编号非标准

系统中 VE 卡编号为 1/2/3，而非标准的 0/1/2。`ve_exec -N 0` 返回 Offline。

解决: `scripts/common.sh` 动态检测可用节点:
```bash
VE_NODES=$(sudo /opt/nec/ve/bin/vecmd state get | grep -oP 'VE\d+' | grep -oP '\d+' | sort -n | tr '\n' ' ')
```

### 2.2 编译器与库问题

| 问题 | 解决 |
|------|------|
| `veo_api.h` 不存在 | 改用 `<ve_offload.h>` |
| `veosinfo.h` 不存在 | 改用 `sysconf(_SC_PHYS_PAGES)` |
| `-lveo` 链接失败 | 改用 `g++` + `-L/opt/nec/ve/veos/lib64` |
| `libnfort_m.so.2` 缺失 | **未解决**，AVEO 测试 SKIP |
| `mpirun` 缺失 | **未解决**，MPI 测试 SKIP |

### 2.3 run_tests.sh 设计演进

- 初始: `eval "$check" "$out_file"` → `test` 命令不接受多余参数
- 改进: `eval "$check" < "$out_file"` → check 从 stdin 读取结果
- 注意: `run_tests.sh` 中的 `$(...)` 在脚本加载时执行，需用 `\$(...)` 延迟到 eval

---

## 3. 编译结果

全部 11 个二进制文件编译成功:
- VE 程序 6 个 (ncc)
- MPI 程序 3 个 (mpicc)
- Host 程序 2 个 (g++)

---

## 4. 运行验证

```bash
$ ve_exec -N 1 ./sample_bin
Hello World

$ bash scripts/multi_independent.sh
VE1: PASS / VE2: PASS / VE3: PASS
```

---

## 5. 已知 TODO

1. `check_link_speed.sh` 需 sudo
2. `libnfort_m.so.2` 缺失 → AVEO 无法运行
3. `mpirun` 缺失 → MPI 测试 SKIP
4. 30 分钟压力测试待完整执行
5. IPMI 温度/功耗监控待验证

---

## 6. 使用方式

```bash
cd PerfTest
make all
./run_tests.sh all        # 全部测试
./run_tests.sh hw         # 仅硬件识别
make clean
```

---

*文档版本: 1.0*
