const std = @import("std");
const sol = @import("solana-program-sdk");
const bincode = @import("bincode");

const Account = sol.Account;

const ComputeBudget = @This();

pub const id = sol.PublicKey.comptimeFromBase58("ComputeBudget111111111111111111111111111111");

pub fn requestHeapFrame(allocator: std.mem.Allocator, bytes: u32) !sol.Instruction {
    const data = try bincode.writeAlloc(allocator, ComputeBudget.Instruction{
        .request_heap_frame = .{ .bytes = bytes },
    }, .{});

    return sol.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{},
        .data = data,
    });
}

pub fn setComputeUnitLimit(allocator: std.mem.Allocator, compute_units: u32) !sol.Instruction {
    const data = try bincode.writeAlloc(allocator, ComputeBudget.Instruction{
        .set_compute_unit_limit = .{ .compute_units = compute_units },
    }, .{});

    return sol.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{},
        .data = data,
    });
}

pub fn setComputeUnitPrice(allocator: std.mem.Allocator, micro_lamports: u64) !sol.Instruction {
    const data = try bincode.writeAlloc(allocator, ComputeBudget.Instruction{
        .set_compute_unit_price = .{ .micro_lamports = micro_lamports },
    }, .{});

    return sol.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{},
        .data = data,
    });
}

pub fn setLoadedAccountsDataSizeLimit(allocator: std.mem.Allocator, bytes: u32) !sol.Instruction {
    const data = try bincode.writeAlloc(allocator, ComputeBudget.Instruction{
        .set_loaded_accounts_data_size_limit = .{ .bytes = bytes },
    }, .{});

    return sol.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{},
        .data = data,
    });
}

pub const Instruction = union(enum(u8)) {
    // deprecated variant, reserved value.
    unused,
    /// Request a specific transaction-wide program heap region size in bytes.
    /// The value requested must be a multiple of 1024. This new heap region
    /// size applies to each program executed in the transaction, including all
    /// calls to CPIs.
    request_heap_frame: struct {
        bytes: u32,
    },
    /// Set a specific compute unit limit that the transaction is allowed to consume.
    set_compute_unit_limit: struct {
        compute_units: u32,
    },
    /// Set a compute unit price in "micro-lamports" to pay a higher transaction
    /// fee for higher transaction prioritization.
    set_compute_unit_price: struct {
        micro_lamports: u64,
    },
    /// Set a specific transaction-wide account data size limit, in bytes, is allowed to load.
    set_loaded_accounts_data_size_limit: struct {
        bytes: u32,
    },
};

test "build request heap frame ix" {
    const ix = try requestHeapFrame(std.testing.allocator, 4000);

    defer std.testing.allocator.free(ix.data[0..ix.data_len]);

    try std.testing.expect(ix.program_id.equals(id));
    try std.testing.expectEqual(0, ix.accounts_len);
    try std.testing.expectEqual(5, ix.data_len);

    try std.testing.expect(std.mem.eql(u8, &.{ 0x1, 0xa0, 0xf, 0x0, 0x0 }, ix.data[0..ix.data_len]));
}

test "build set compute limit ix" {
    const ix = try setComputeUnitLimit(std.testing.allocator, 1_400_000);

    defer std.testing.allocator.free(ix.data[0..ix.data_len]);

    try std.testing.expect(ix.program_id.equals(id));
    try std.testing.expectEqual(0, ix.accounts_len);
    try std.testing.expectEqual(5, ix.data_len);

    try std.testing.expect(std.mem.eql(u8, &.{ 0x2, 0xc0, 0x5c, 0x15, 0x0 }, ix.data[0..ix.data_len]));
}

test "build set compute unit price ix" {
    const ix = try setComputeUnitPrice(std.testing.allocator, 1000);

    defer std.testing.allocator.free(ix.data[0..ix.data_len]);

    try std.testing.expect(ix.program_id.equals(id));
    try std.testing.expectEqual(0, ix.accounts_len);
    try std.testing.expectEqual(9, ix.data_len);

    try std.testing.expect(std.mem.eql(u8, &.{ 0x3, 0xe8, 0x3, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 }, ix.data[0..ix.data_len]));
}

test "build set loaded accounts data-size limit ix" {
    const ix = try setLoadedAccountsDataSizeLimit(std.testing.allocator, 1200);

    defer std.testing.allocator.free(ix.data[0..ix.data_len]);

    try std.testing.expect(ix.program_id.equals(id));
    try std.testing.expectEqual(0, ix.accounts_len);
    try std.testing.expectEqual(5, ix.data_len);

    try std.testing.expect(std.mem.eql(u8, &.{ 0x4, 0xb0, 0x4, 0x0, 0x0 }, ix.data[0..ix.data_len]));
}
