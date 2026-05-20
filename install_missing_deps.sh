#!/bin/bash
# 安装 NEC MPI runtime 和 nfort shared 库，以解锁 5 项跳过的测试用例
# 需要 sudo 权限执行

set -e

MPI_ROOT=/opt/nec/ve/mpi/3.10.0
NFORT_LIB=/opt/nec/ve/nfort/5.4.1/lib
LDCONF=/etc/ld.so.conf.d/nec-nfort.conf

echo "=== 安装 NEC MPI runtime (提供 mpirun) ==="
if [ ! -f "$MPI_ROOT/bin64/runtime/mpirun" ]; then
    sudo dnf install -y nec-mpi-runtime-3-10-0
else
    echo "  已安装，跳过"
fi

echo ""
echo "=== 安装 nec-nfort-shared (提供 libnfort_m.so.2) ==="
if [ ! -f "$NFORT_LIB/libnfort_m.so.2" ]; then
    sudo dnf install -y nec-nfort-shared-5.4.1
else
    echo "  已安装，跳过"
fi

echo ""
echo "=== 注册 nfort 库路径到 ldconfig ==="
if [ ! -f "$LDCONF" ]; then
    echo "$NFORT_LIB" | sudo tee "$LDCONF" > /dev/null
    echo "  已写入 $LDCONF"
else
    echo "  已存在，跳过"
fi
sudo ldconfig

echo ""
echo "=== 验证安装 ==="

MPI_RUN="$MPI_ROOT/bin64/runtime/mpirun"
if [ -f "$MPI_RUN" ]; then
    echo "  [OK] mpirun: $MPI_RUN"
else
    echo "  [FAIL] mpirun 未找到"
fi

NFORT_LIB_PATH=/opt/nec/ve/nfort/5.4.1/lib/libnfort_m.so.2
if [ -f "$NFORT_LIB_PATH" ]; then
    echo "  [OK] libnfort_m.so.2: $NFORT_LIB_PATH (VE arch library)"
else
    echo "  [FAIL] libnfort_m.so.2 未找到"
fi

echo ""
echo "=== 激活 MPI 环境变量 ==="
# shellcheck disable=SC1091
source "$MPI_ROOT/bin64/necmpivars-runtime.sh"
echo "  PATH 已更新，mpirun=$(command -v mpirun)"

echo ""
echo "  若需永久生效，将以下行添加到 ~/.bashrc："
echo "    source $MPI_ROOT/bin64/necmpivars-runtime.sh"
echo ""
echo "=== 完成！可重新运行测试套件 ==="
echo "  cd /home/joey/Work/nec_ve/PerfTest && bash run_tests.sh all"
