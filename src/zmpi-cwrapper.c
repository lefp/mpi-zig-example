#include <mpi.h>

extern inline int init(int* argc, char*** argv) {
  return MPI_Init(argc, argv);
}

extern inline int finalize() {
  return MPI_Finalize();
}

extern inline MPI_Comm commWorld() {
  return MPI_COMM_WORLD;
}

extern inline int commSize(MPI_Comm comm, int* result) {
  return MPI_Comm_size(comm, result);
}

extern inline int commRank(MPI_Comm comm, int* result) {
  return MPI_Comm_rank(comm, result);
}

extern inline int maxProcessorName() {
  return MPI_MAX_PROCESSOR_NAME;
}

extern inline int getProcessorName(char* name, int* result_len) {
  return MPI_Get_processor_name(name, result_len);
}