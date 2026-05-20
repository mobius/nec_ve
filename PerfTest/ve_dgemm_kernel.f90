! ve_dgemm_kernel.f90 — nfort-optimised DGEMM kernel for VE 10BE-P
!
! Strategy: column-major (Fortran default) + kk-blocked jki loop order.
!   j-parallel : 8 threads each own N/8 columns of C
!   kk-serial  : persistent OMP team + one barrier per kk-block keeps the
!                A-tile (kk-block × N, 8 MB) hot in the shared 16 MB LLC
!   k-serial   : B(k,j) is a scalar hoisted from the i-loop
!   i-vectorised: stride-1 column access; nfort keeps C(:,j) in vector
!                 registers across the entire k-loop (opt(1800) idiom)
!
! Compiled with: nfort -O3 -fopenmp
! Measured: ~430 GFLOPS (8 cores, N=4096) = 20% of 2160 GFLOPS peak
!
subroutine dgemm_ve(A, B, C, N_in, TILE_K_in) bind(C, name='dgemm_ve')
  use iso_c_binding
  use omp_lib
  implicit none

  integer(c_int), value, intent(in) :: N_in, TILE_K_in
  real(c_double), intent(in)    :: A(N_in, N_in)
  real(c_double), intent(in)    :: B(N_in, N_in)
  real(c_double), intent(inout) :: C(N_in, N_in)

  integer :: N, TILE_K, i, j, k, kk, klim

  N      = N_in
  TILE_K = TILE_K_in

  ! One persistent parallel region — avoids 16 fork/join overheads.
  ! The implicit barrier after each !$omp end do ensures all threads share
  ! the same A-block in the LLC before the next kk iteration.
  !$omp parallel private(kk, klim, j, k, i)
  do kk = 1, N, TILE_K
    klim = min(kk + TILE_K - 1, N)

    !$omp do schedule(static)
    do j = 1, N
      do k = kk, klim
!NEC$ ivdep
!NEC$ loop_count(4096)
        do i = 1, N
          C(i,j) = C(i,j) + B(k,j) * A(i,k)
        end do
      end do
    end do
    !$omp end do
    ! implicit barrier here
  end do
  !$omp end parallel

end subroutine dgemm_ve
