const std = @import("std");

const allocator = std.heap.c_allocator;

const mpi = struct {
    const MpiComm = ?*anyopaque;
    extern fn init(argc: ?*c_int, ?*[*][*]u8) c_int;
    extern fn finalize() c_int;
    extern fn commWorld() MpiComm;
    extern fn commSize(comm: MpiComm, result: ?*c_int) c_int;
    extern fn commRank(comm: MpiComm, result: ?*c_int) c_int;
    extern fn maxProcessorName() c_int;
    extern fn getProcessorName(name: [*]u8, result_len: ?*c_int) c_int;
};

pub fn main() !void {
    _ = mpi.init(null, null);
    defer _ = mpi.finalize();

    var world_size: c_int = undefined;
    _ = mpi.commSize(mpi.commWorld(), &world_size);

    var world_rank: c_int = undefined;
    _ = mpi.commRank(mpi.commWorld(), &world_rank);

    var processor_name = try allocator.alloc(u8, @intCast(usize, mpi.maxProcessorName()));
    defer allocator.free(processor_name);
    var name_len: c_int = undefined;
    _ = mpi.getProcessorName(processor_name.ptr, &name_len);

    std.debug.print("Processor {s}, rank {d} out of {d}\n", .{processor_name, world_rank, world_size});
}
