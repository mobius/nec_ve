# gcc-ve 必要性评估报告

> 评估对象: [github.com/veos-sxarr-NEC/gcc-ve](https://github.com/veos-sxarr-NEC/gcc-ve)  
> 评估时间: 2026-05-19  
> 当前系统状态: NEC 官方编译器 ncc/nc++/nfort 5.4.1 已免费安装

---

## 1. gcc-ve 是什么

gcc-ve 是 NEC 开源的、基于 **GCC 7.1.0** 的交叉编译器，目标架构为 Vector Engine (VE)。

| 属性 | 详情 |
|------|------|
| 上游版本 | GCC 7.1.0 (2017年5月发布) |
| 最新 release | gcc-ve-7.1.0-7 (2022年1月) |
| 许可证 | GPLv3 |
| 维护状态 | **基本停滞**（4年无更新） |
| 支持语言 | **仅 C** |
| 官方定位 | 仅用于构建 glibc for VE |

---

## 2. gcc-ve 的自我声明（来自官方 README）

NEC 在 gcc-ve 的 README 中明确作出了以下**自我限制声明**：

> **"This software can't generate vector instructions."**
> 
> **"This software is developed only for the purpose to build glibc for VE."**
> 
> **"Only C compiler is available."**
> 
> **"A binary may malfunction when optimize options are enabled."**
> 
> **"NEC doesn't support this software as the SX-Aurora TSUBASA product software."**

---

## 3. 与已安装官方编译器 ncc 5.4.1 的对比

| 维度 | gcc-ve (GitHub) | ncc/nc++/nfort 5.4.1 (官方) |
|------|-----------------|---------------------------|
| **向量指令生成** | ❌ **完全不支持** | ✅ 自动向量化，已验证 |
| **支持语言** | 仅 C | C / C++ / Fortran |
| **自动优化** | ❌ -O0 都可能有 bug | ✅ Loop Interchange / Unroll / Vectorize |
| **NEC 官方支持** | ❌ 明确声明不支持 | ✅ 官方产品 |
| **License 费用** | 免费 (GPL) | **现免费**（2025年起取消限制） |
| **维护更新** | 2022年停止 | 持续更新 (5.4.1 为当前最新) |
| **与系统 gcc 冲突** | ⚠️ 安装到 `/opt/nec/ve/bin/gcc` | ✅ 无冲突 (`ncc`/`nc++`/`nfort`) |
| **MPI 集成** | ❌ 无 | ✅ `mpicc`/`mpinc++`/`mpinfort` |

### 3.1 向量化能力实测对比

**gcc-ve**: 官方明确声明 *"can't generate vector instructions"*

**ncc 5.4.1** (矩阵乘法编译输出):
```
ncc: vec( 101): ve_matmul.c, line 25: Vectorized loop.
ncc: opt(1589): ve_matmul.c, line 37: Outer loop moved inside inner loop(s).: j
ncc: vec( 101): ve_matmul.c, line 37: Vectorized loop.
ncc: opt(1592): ve_matmul.c, line 39: Outer loop unrolled inside inner loop.: k
ncc: vec( 101): ve_matmul.c, line 39: Vectorized loop.
ncc: vec( 101): ve_matmul.c, line 42: Vectorized loop.
ncc: vec( 101): ve_matmul.c, line 50: Vectorized loop.
```

**5 个循环全部被自动向量化**，这是 VE 卡发挥性能的唯一方式。

---

## 4. 安装 gcc-ve 的风险

### 风险 1: PATH 冲突

gcc-ve 默认安装到 `/opt/nec/ve/bin/gcc`。

当前系统 PATH 配置 (`/etc/profile.d/nec-ve.sh`):
```bash
export PATH=/opt/nec/ve/bin:$PATH
```

如果安装 gcc-ve，`gcc` 命令将指向 VE 交叉编译器而非系统 GCC 8.5.0，导致：
- x86_64 (VH) 端程序编译失败
- NEC MPI setup 脚本 (`necmpivars.sh`) 也会将 `/opt/nec/ve/bin` 加到 PATH 头部，冲突不可避免
- autotools/cmake 检测编译器时可能误识别

### 风险 2: 优化级别限制

README 明确指出：
> *"A binary may malfunction when optimize options are enabled. In such case, use '-O0' option."*

这意味着 gcc-ve 编译的代码：
- **不能使用 -O2 / -O3 优化**
- 性能将极其低下（无向量指令 + 无优化）

### 风险 3: 无向量性能

Vector Engine 的核心价值是 **256 个向量寄存器 + 向量流水线**。gcc-ve 完全无法利用这些硬件特性，编译出的程序在 VE 上跑甚至不如在 x86_64 上跑。

---

## 5. 唯一可能的适用场景

| 场景 | 是否需要 gcc-ve | 说明 |
|------|----------------|------|
| 修改并重新编译 glibc-ve | ⚠️ 理论上需要 | 但 `glibc-ve1/ve3` rpm 已安装，无需自行编译 |
| ncc 无法编译的特定代码 | ⚠️ 可能有用 | 应优先向 NEC 官方报 bug，而非使用无支持的 gcc-ve |
| 学习 VE 汇编/ABI | ✅ 可能有用 | 作为开源参考了解底层调用约定 |
| 移植第三方开源项目 | ❌ 不需要 | ncc 兼容 GNU 风格，可直接使用 |

---

## 6. 结论

### 在当前系统环境下，gcc-ve 完全没有必要安装。

**核心原因：**

1. **官方编译器已完全免费** — ncc/nc++/nfort 5.4.1 和 MPI 均已取消 license 限制，gcc-ve 的"免费"优势已不复存在。

2. **不能生成向量指令** — 这是致命缺陷。没有向量指令的 VE 程序等于白买这张卡。

3. **仅支持 C 语言** — ncc 支持 C/C++/Fortran，gcc-ve 连 C++ 都不支持。

4. **优化选项有 bug** — 连 -O2 都不敢开，性能无从谈起。

5. **与系统 gcc 冲突** — 安装后会破坏 VH 端正常编译环境。

6. **维护停滞** — 4年无更新，基于 2017 年的 GCC 7.1.0。

7. **唯一官方用途不存在** — glibc-ve 已通过 rpm 安装到位，无需自行从源码构建。

---

## 7. 建议

| 建议 | 操作 |
|------|------|
| **不安装 gcc-ve** | 保持当前仅使用 ncc 的干净环境 |
| **如需 glibc-ve 源码** | 可从 GitHub 阅读参考，但使用已安装的 rpm 包 |
| **如遇 ncc 编译问题** | 向 NEC 官方或 Aurora Web Forum 反馈 |
| **如需 GCC 兼容性** | ncc 兼容 GNU 扩展，大部分代码可直接编译 |

---

## 附录: gcc-ve 项目元数据

```
仓库:     https://github.com/veos-sxarr-NEC/gcc-ve
最新 tag: gcc-ve-7.1.0-7 (2022-01-24)
上游:     GCC 7.1.0 (2017-05-02)
许可证:   GPLv3
维护者:   NEC (非产品支持)
```
