const std = @import("std");
const sol = @import("solana_program_sdk");

const Account = sol.account.Account;
const PublicKey = sol.public_key.PublicKey;

const SystemProgram = @This();
pub const id = PublicKey.comptimeFromBase58("11111111111111111111111111111111");

pub fn createAccount(params: struct {
    from: Account.Info,
    to: Account.Info,
    lamports: u64,
    space: u64,
    owner_id: PublicKey,
    seeds: []const []const []const u8 = &.{},
}) !void {
    var data: [52]u8 = undefined;
    _ = try bincode.writeToSlice(&data, SystemProgram.Instruction{
        .create_account = .{
            .lamports = params.lamports,
            .space = params.space,
            .owner_id = params.owner_id,
        },
    }, .default);

    const instruction = sol.instruction.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{
            .{ .id = params.from.id, .is_writable = true, .is_signer = true },
            .{ .id = params.to.id, .is_writable = true, .is_signer = true },
        },
        .data = &data,
    });

    try instruction.invokeSigned(&.{ params.from, params.to }, params.seeds);
}

pub fn transfer(params: struct {
    from: Account.Info,
    to: Account.Info,
    lamports: u64,
    seeds: []const []const []const u8 = &.{},
}) !void {
    var data: [12]u8 = undefined;
    _ = try bincode.writeToSlice(&data, SystemProgram.Instruction{
        .transfer = .{ .lamports = params.lamports },
    }, .default);

    const instruction = sol.instruction.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{
            .{ .id = params.from.id, .is_writable = true, .is_signer = true },
            .{ .id = params.to.id, .is_writable = true, .is_signer = false },
        },
        .data = &data,
    });

    try instruction.invokeSigned(&.{ params.from, params.to }, params.seeds);
}

fn InstructionData(comptime Discriminant: type, comptime Data: type) type {
    return packed struct {
        discriminant: Discriminant,
        data: Data,
        const Self = @This();
        fn asBytes(self: *const Self) []const u8 {
            return std.mem.asBytes(self)[0..(@sizeOf(Discriminant) + @sizeOf(Data))];
        }
    };
}

pub fn allocate(params: struct {
    account: Account.Info,
    space: u64,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const InstructionType = InstructionData(InstructionDiscriminant, AllocateData);
    const data = InstructionType { .discriminant = InstructionDiscriminant.allocate, .data = .{ .space = params.space } };

    const instruction = sol.instruction.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{
            .{ .id = params.account.id, .is_writable = true, .is_signer = true },
        },
        .data = data.asBytes(),
    });

    try instruction.invokeSigned(&.{params.account}, params.seeds);
}

pub fn assign(params: struct {
    account: Account.Info,
    owner_id: PublicKey,
    seeds: []const []const []const u8 = &.{},
}) !void {
    var data: [36]u8 = undefined;
    _ = try bincode.writeToSlice(&data, SystemProgram.Instruction{
        .assign = .{ .owner_id = params.owner_id },
    }, .default);

    const instruction = sol.instruction.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{
            .{ .id = params.account.id, .is_writable = true, .is_signer = true },
        },
        .data = &data,
    });

    try instruction.invokeSigned(&.{params.account}, params.seeds);
}

pub const InstructionDiscriminant = enum(u32) {
    create_account,
    assign,
    transfer,
    create_account_with_seed,
    advance_nonce_account,
    withdraw_nonce_account,
    initialize_nonce_account,
    authorize_nonce_account,
    allocate,
    allocate_with_seed,
    assign_with_seed,
    transfer_with_seed,
};

const CreateAccountData = extern struct {
    /// Number of lamports to transfer to the new account
    lamports: u64 align(1),
    /// Number of bytes of memory to allocate
    space: u64 align(1),
    /// Address of program that will own the new account
    owner_id: PublicKey align(1),
};

const AssignData = extern struct {
    /// Owner program account
    owner_id: PublicKey align(1),
};

const AllocateData = packed struct {
    /// Number of bytes of memory to allocate
    space: u64,
};

const TransferData = extern struct {
    /// Number of lamports to transfer
    lamports: u64 align(1),
};

pub const Instruction = union(InstructionDiscriminant) {
    /// Create a new account
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` Funding account
    ///   1. `[WRITE, SIGNER]` New account
    create_account: CreateAccountData,
    /// Assign account to a program
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` Assigned account public key
    assign: AssignData,
    /// Transfer lamports
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` Funding account
    ///   1. `[WRITE]` Recipient account
    transfer: TransferData,
    /// Create a new account at an address derived from a base public key and a seed
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` Funding account
    ///   1. `[WRITE]` Created account
    ///   2. `[SIGNER]` (optional) Base account; the account matching the base PublicKey below must be
    ///                          provided as a signer, but may be the same as the funding account
    ///                          and provided as account 0
    create_account_with_seed: struct {
        /// Base public key
        base: PublicKey,
        /// String of ASCII chars, no longer than `PublicKey.max_seed_length`
        seed: []const u8,
        /// Number of lamports to transfer to the new account
        lamports: u64,
        /// Number of bytes of memory to allocate
        space: u64,
        /// Owner program account address
        owner_id: PublicKey,
    },
    /// Consumes a stored nonce, replacing it with a successor
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    ///   1. `[]` RecentBlockhashes sysvar
    ///   2. `[SIGNER]` Nonce authority
    advance_nonce_account: void,
    /// Withdraw funds from a nonce account
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    ///   1. `[WRITE]` Recipient account
    ///   2. `[]` RecentBlockhashes sysvar
    ///   3. `[]` Rent sysvar
    ///   4. `[SIGNER]` Nonce authority
    ///
    /// The `u64` parameter is the lamports to withdraw, which must leave the
    /// account balance above the rent exempt reserve or at zero.
    withdraw_nonce_account: u64,
    /// Drive state of Uninitialized nonce account to Initialized, setting the nonce value
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    ///   1. `[]` RecentBlockhashes sysvar
    ///   2. `[]` Rent sysvar
    ///
    /// The `PublicKey` parameter specifies the entity authorized to execute nonce
    /// instruction on the account
    ///
    /// No signatures are required to execute this instruction, enabling derived
    /// nonce account addresses
    initialize_nonce_account: PublicKey,
    /// Change the entity authorized to execute nonce instructions on the account
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    ///   1. `[SIGNER]` Nonce authority
    ///
    /// The `PublicKey` parameter identifies the entity to authorize
    authorize_nonce_account: PublicKey,
    /// Allocate space in a (possibly new) account without funding
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` New account
    allocate: AllocateData,
    /// Allocate space for and assign an account at an address
    ///    derived from a base public key and a seed
    ///
    /// # Account references
    ///   0. `[WRITE]` Allocated account
    ///   1. `[SIGNER]` Base account
    allocate_with_seed: struct {
        /// Base public key
        base: PublicKey,
        /// String of ASCII chars, no longer than `PublicKey.max_seed_len`
        seed: []const u8,
        /// Number of bytes of memory to allocate
        space: u64,
        /// Owner program account
        owner_id: PublicKey,
    },
    /// Assign account to a program based on a seed
    ///
    /// # Account references
    ///   0. `[WRITE]` Assigned account
    ///   1. `[SIGNER]` Base account
    assign_with_seed: struct {
        /// Base public key
        base: PublicKey,
        /// String of ASCII chars, no longer than `PublicKey.max_Seed_len`
        seed: []const u8,
        /// Owner program account
        owner_id: PublicKey,
    },
    /// Transfer lamports from a derived address
    ///
    /// # Account references
    ///   0. `[WRITE]` Funding account
    ///   1. `[SIGNER]` Base for funding account
    ///   2. `[WRITE]` Recipient account
    transfer_with_seed: struct {
        /// Amount to transfer
        lamports: u64,
        /// Seed to use to derive the funding accout address
        from_seed: []const u8,
        /// Owner to use to derive the funding account address
        from_owner: PublicKey,
    },
};

test "SystemProgram.Instruction: serialize and deserialize" {
    var writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer writer.deinit();

    inline for (.{ bincode.Params.default, bincode.Params.legacy, bincode.Params.standard }) |params| {
        inline for (.{
            SystemProgram.Instruction{
                .create_account = .{
                    .lamports = 1586880,
                    .space = 100,
                    .owner_id = id,
                },
            },
        }) |payload| {
            try bincode.write(&writer.writer, payload, params);
            var buffer = writer.toArrayList();
            defer buffer.deinit(std.testing.allocator);
            var reader = std.Io.Reader.fixed(buffer.items);
            try std.testing.expectEqual(payload, try bincode.read(std.testing.allocator, @TypeOf(payload), &reader, params));
            writer.clearRetainingCapacity();
        }
    }
}

test "SystemProgram.Instruction: pointer cast" {
    const InstructionType = InstructionData(InstructionDiscriminant, AllocateData);
    const data = InstructionType { .discriminant = InstructionDiscriminant.allocate, .data = .{ .space = 42 } };
    const buffer = [_]u8{ 8, 0, 0, 0, 42, 0, 0, 0, 0, 0, 0, 0};
    try std.testing.expectEqualSlices(u8, data.asBytes(), &buffer);
}
