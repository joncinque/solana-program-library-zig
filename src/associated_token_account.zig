const std = @import("std");
const bincode = @import("bincode");
const sol = @import("solana_program_sdk");

const Account = sol.account.Account;
const ProgramDerivedAddress = sol.public_key.ProgramDerivedAddress;
const PublicKey = sol.public_key.PublicKey;

const AssociatedTokenAccountProgram = @This();
pub const id = PublicKey.comptimeFromBase58("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL");

pub const Instruction = union(enum(u8)) {
    /// Creates an associated token account for the given wallet address and token mint
    /// Returns an error if the account exists.
    ///
    ///   0. `[writeable,signer]` Funding account (must be a system account)
    ///   1. `[writeable]` Associated token account address to be created
    ///   2. `[]` Wallet address for the new associated token account
    ///   3. `[]` The token mint for the new associated token account
    ///   4. `[]` System program
    ///   5. `[]` SPL Token program
    create: void,
    /// Creates an associated token account for the given wallet address and token mint,
    /// if it doesn't already exist.  Returns an error if the account exists,
    /// but with a different owner.
    ///
    ///   0. `[writeable,signer]` Funding account (must be a system account)
    ///   1. `[writeable]` Associated token account address to be created
    ///   2. `[]` Wallet address for the new associated token account
    ///   3. `[]` The token mint for the new associated token account
    ///   4. `[]` System program
    ///   5. `[]` SPL Token program
    create_idempotent: void,
    /// Transfers from and closes a nested associated token account: an
    /// associated token account owned by an associated token account.
    ///
    /// The tokens are moved from the nested associated token account to the
    /// wallet's associated token account, and the nested account lamports are
    /// moved to the wallet.
    ///
    /// Note: Nested token accounts are an anti-pattern, and almost always
    /// created unintentionally, so this instruction should only be used to
    /// recover from errors.
    ///
    ///   0. `[writeable]` Nested associated token account, must be owned by `3`
    ///   1. `[]` Token mint for the nested associated token account
    ///   2. `[writeable]` Wallet's associated token account
    ///   3. `[]` Owner associated token account address, must be owned by `5`
    ///   4. `[]` Token mint for the owner associated token account
    ///   5. `[writeable, signer]` Wallet address for the owner associated token account
    ///   6. `[]` SPL Token program
    recover_nested: void,
};

pub fn getAssociatedTokenAccountAddressWithProgramId(wallet_address: PublicKey, mint_address: PublicKey, token_program_id: PublicKey) !PublicKey {
    const pda = try getAssociatedTokenAccountAddressAndBumpSeed(wallet_address, mint_address, token_program_id);
    return pda.address;
}

pub fn getAssociatedTokenAccountAddressAndBumpSeed(wallet_address: PublicKey, mint_address: PublicKey, token_program_id: PublicKey) !ProgramDerivedAddress {
    return PublicKey.findProgramAddress(.{ wallet_address, token_program_id, mint_address }, id);
}

pub fn createAccount(params: struct {
    funder: Account.Info,
    account: Account.Info,
    owner: Account.Info,
    mint: Account.Info,
    system_program: Account.Info,
    token_program: Account.Info,
    rent: Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    var data: [1]u8 = undefined;
    _ = try bincode.writeToSlice(&data, AssociatedTokenAccountProgram.Instruction.create, .default);

    const instruction = sol.instruction.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{
            .{ .id = params.funder.id, .is_writable = true, .is_signer = true },
            .{ .id = params.account.id, .is_writable = true, .is_signer = false },
            .{ .id = params.owner.id, .is_writable = false, .is_signer = false },
            .{ .id = params.mint.id, .is_writable = false, .is_signer = false },
            .{ .id = params.system_program.id, .is_writable = false, .is_signer = false },
            .{ .id = params.token_program.id, .is_writable = false, .is_signer = false },
            .{ .id = params.rent.id, .is_writable = false, .is_signer = false },
        },
        .data = &data,
    });

    try instruction.invokeSigned(&.{
        params.funder,
        params.account,
        params.owner,
        params.mint,
        params.system_program,
        params.token_program,
        params.rent,
    }, params.seeds);
}

pub fn createIdempotentAccount(params: struct {
    funder: Account.Info,
    account: Account.Info,
    owner: Account.Info,
    mint: Account.Info,
    system_program: Account.Info,
    token_program: Account.Info,
    associated_token_program: Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    var data: [1]u8 = undefined;
    _ = try bincode.writeToSlice(&data, AssociatedTokenAccountProgram.Instruction.create_idempotent, .default);

    const instruction = sol.instruction.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{
            .{ .id = params.funder.id, .is_writable = true, .is_signer = true },
            .{ .id = params.account.id, .is_writable = true, .is_signer = false },
            .{ .id = params.owner.id, .is_writable = false, .is_signer = false },
            .{ .id = params.mint.id, .is_writable = false, .is_signer = false },
            .{ .id = params.system_program.id, .is_writable = false, .is_signer = false },
            .{ .id = params.token_program.id, .is_writable = false, .is_signer = false },
        },
        .data = &data,
    });

    try instruction.invokeSigned(&.{
        params.funder,
        params.account,
        params.owner,
        params.mint,
        params.system_program,
        params.token_program,
        params.associated_token_program,
    }, params.seeds);
}

pub fn recoverNestedAccount(params: struct {
    account: Account.Info,
    nested_mint: Account.Info,
    destination_associated_account: Account.Info,
    owner_associated_account: Account.Info,
    owner_mint: Account.Info,
    owner: Account.Info,
    token_program: Account.Info,
    associated_token_program: Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    var data: [1]u8 = undefined;
    _ = try bincode.writeToSlice(&data, AssociatedTokenAccountProgram.Instruction.recover_nested, .default);

    const instruction = sol.instruction.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{
            .{ .id = params.account.id, .is_writable = true, .is_signer = false },
            .{ .id = params.nested_mint.id, .is_writable = false, .is_signer = false },
            .{ .id = params.destination_associated_account.id, .is_writable = true, .is_signer = false },
            .{ .id = params.owner_associated_account.id, .is_writable = false, .is_signer = false },
            .{ .id = params.owner_mint.id, .is_writable = false, .is_signer = false },
            .{ .id = params.owner.id, .is_writable = true, .is_signer = true },
            .{ .id = params.token_program.id, .is_writable = false, .is_signer = false },
        },
        .data = &data,
    });

    try instruction.invokeSigned(&.{
        params.account,
        params.nested_mint,
        params.destination_associated_account,
        params.owner_associated_account,
        params.owner_mint,
        params.owner,
        params.token_program,
        params.associated_token_program,
    }, params.seeds);
}
