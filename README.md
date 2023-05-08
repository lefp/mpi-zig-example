# mpi-zig-example
Zig's `@cImport` can't handle OpenMPI, because OpenMPI implements a lot of the MPI API via C macros.

This is a *partial* proof-of-concept for getting it to work.
1. I wrapped the API with inline C functions that the Zig code can call.
2. In the build step, I call `mpicc -showme` to get the header and library directories. But I haven't handled any of the other flags `mpicc` normally passes, which probably needs to be resolved for this approach to be portable.

## Running
```
zig build
mpirun -n <number of processes> ./zig-out/bin/zmpi
```
