# NEC VE 1.0 Three-Card Performance Test Makefile
# Usage: make all        - build all test programs
#        make clean      - remove all binaries
#        make check      - quick build verification

# Compilers and flags
NCC      = ncc
NCXX     = nc++
MPICC    = mpicc
MPICXX   = mpinc++

CFLAGS   = -O3
CXXFLAGS = -O3
LDFLAGS  =

# AVEO flags (host-side, use g++)
AVEO_CXX     = g++
AVEO_INC     = -I/opt/nec/ve/veos/include
AVEO_LIB     = -L/opt/nec/ve/veos/lib64
AVEO_CFLAGS  = -O3 $(AVEO_INC)
AVEO_LDFLAGS = $(AVEO_LIB) -lveo -Wl,-rpath,/opt/nec/ve/veos/lib64

# VEOS info flags
VEINFO_INC     = -I/opt/nec/ve/veos/include
VEINFO_CFLAGS  = $(CXXFLAGS) $(VEINFO_INC)
VEINFO_LDFLAGS = -lveosinfo

# Binaries
VE_BINS   = sample_bin ve_float_test ve_matmul ve_bandwidth ve_mem_check
MPI_BINS  = mpi_hello mpi_allreduce_test mpi_pingpong
HOST_BINS = aveo_multi_test aveo_bandwidth ve_segfault
ALL_BINS  = $(VE_BINS) $(MPI_BINS) $(HOST_BINS)

.PHONY: all clean check dirs

all: $(ALL_BINS)

dirs:
	@mkdir -p results logs

# VE native binaries (run on VE card)
sample_bin: sample.c
	$(NCC) $(CFLAGS) -o $@ $<

ve_float_test: ve_float_test.c
	$(NCC) $(CFLAGS) -o $@ $<

ve_matmul: ve_matmul.c
	$(NCC) $(CFLAGS) -o $@ $<

ve_bandwidth: ve_bandwidth.c
	$(NCC) $(CFLAGS) -o $@ $<

ve_mem_check: ve_mem_check.c
	$(NCC) $(CFLAGS) -o $@ $<

# MPI binaries
mpi_hello: mpi_hello.c
	$(MPICC) $(CFLAGS) -o $@ $<

mpi_allreduce_test: mpi_allreduce_test.c
	$(MPICC) $(CFLAGS) -o $@ $<

mpi_pingpong: mpi_pingpong.c
	$(MPICC) $(CFLAGS) -o $@ $<

# Host binaries using AVEO
aveo_multi_test: aveo_multi_test.c
	$(AVEO_CXX) $(AVEO_CFLAGS) -o $@ $< $(AVEO_LDFLAGS)

aveo_bandwidth: aveo_bandwidth.c
	$(AVEO_CXX) $(AVEO_CFLAGS) -o $@ $< $(AVEO_LDFLAGS)

# Fault injection
ve_segfault: ve_segfault.c
	$(NCC) $(CFLAGS) -o $@ $<

check: all
	@echo "=== Build Check ==="
	@for bin in $(ALL_BINS); do \
		if [ -f $$bin ]; then \
			echo "  [OK] $$bin"; \
		else \
			echo "  [MISSING] $$bin"; \
		fi \
	done

clean:
	rm -f $(ALL_BINS)
	rm -f *.o
	rm -rf results logs

help:
	@echo "NEC VE Three-Card PerfTest Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Build all test programs"
	@echo "  check    - Verify all binaries exist"
	@echo "  clean    - Remove all build artifacts"
	@echo "  help     - Show this help"
