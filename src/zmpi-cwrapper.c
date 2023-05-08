#include <mpi.h>

int init(int* argc, char*** argv) {
  return MPI_Init(argc, argv);
}

int finalize() {
  return MPI_Finalize();
}

MPI_Comm commWorld() {
  return MPI_COMM_WORLD;
}

int commSize(MPI_Comm comm, int* result) {
  return MPI_Comm_size(comm, result);
}

int commRank(MPI_Comm comm, int* result) {
  return MPI_Comm_rank(comm, result);
}

int maxProcessorName() {
  return MPI_MAX_PROCESSOR_NAME;
}

int getProcessorName(char* name, int* result_len) {
  return MPI_Get_processor_name(name, result_len);
}