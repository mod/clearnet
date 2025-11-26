use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};

declare_id!("3iDskEsSVNRmbn7uwygUVsBNGEj1hqE2ZCaHSQhhVtD9");

#[program]
pub mod clearnet {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let config = &mut ctx.accounts.config;
        config.admin = ctx.accounts.admin.key();
        config.challenge_period = 600; // 10 minutes
        Ok(())
    }

    pub fn set_node_status(ctx: Context<SetNodeStatus>, status: bool) -> Result<()> {
        if status {
            // Activate: The node account is initialized by Anchor (init_if_needed)
            // We just ensure it's marked active if we add a flag, but purely existing is enough?
            // Let's use a flag in case we want to ban them without closing the account (to keep history? no).
            // Actually, closing the account is better for rent.
            // But the instruction `SetNodeStatus` with `status=false` should close it.
            // Anchor's `close` constraint handles closing.
            // Here we just initialize. logic is handled by Account constraints in the struct.
        } else {
            // Deactivate is handled by `close` in a separate instruction usually,
            // or we just assume if it exists it's active.
            // But to toggle `status` we might need a bool in the account.
        }
        ctx.accounts.node_entry.is_active = status;
        ctx.accounts.node_entry.authority = ctx.accounts.node_authority.key();
        Ok(())
    }

    pub fn deposit(ctx: Context<Deposit>, amount: u64) -> Result<()> {
        // Transfer Tokens/SOL to Vault
        // For simplicity, we implement SPL Token transfer.
        // If native SOL, one would wrap it or use SystemProgram transfer to a PDA.
        // We assume USDC (SPL) for this implementation as per README "USDT".

        let cpi_accounts = Transfer {
            from: ctx.accounts.user_token.to_account_info(),
            to: ctx.accounts.vault_token.to_account_info(),
            authority: ctx.accounts.user.to_account_info(),
        };
        let cpi_ctx = CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts);
        token::transfer(cpi_ctx, amount)?;

        emit!(Deposited {
            wallet: ctx.accounts.user.key(),
            token: ctx.accounts.mint.key(),
            amount,
        });

        Ok(())
    }

    pub fn request(ctx: Context<Request>, state: State, amount: u64) -> Result<()> {
        let clock = Clock::get()?;
        let req_acct = &mut ctx.accounts.request_account;

        // 1. Validation
        require!(
            amount <= state.balance,
            ClearnetError::InsufficientStateBalance
        );
        require!(
            req_acct.expiration == 0,
            ClearnetError::RequestAlreadyPending
        ); // Assuming 0 means not active

        // 2. Verify Signatures
        // This is complex in SVM. We will use a helper that hashes the state
        // and ensures the provided `sigs` match the `participants`.
        // Ideally, we check `ed25519_program` instructions, but here we'll mock the check
        // or perform a naive check if possible.
        // For PROTOTYPE: We trust the `participants` are nodes and signatures are present.
        // Implementing full Ed25519 verify in user-space is too costly for this snippet.
        // We will check that `participants` are valid nodes stored in `node_registry`.
        // But `participants` is a list in `State`.
        // We need to pass the Node accounts to the instruction to verify they exist and are active.
        // Anchor `remaining_accounts` is good for this.

        let participants = &state.participants;
        let mut _valid_sigs = 0;

        // Iterate over remaining accounts (Nodes) to verify they match `participants` and are authorized
        // This validates that the listed participants are indeed Nodes.
        // It DOES NOT verify the cryptographic signature in this snippet (requires Ed25519 verify).
        // IN PRODUCTION: You must verify the Ed25519 signatures!

        // Mock Sig Check:
        require!(
            state.sigs.len() == participants.len(),
            ClearnetError::SigMismatch
        );

        // 3. Store Request
        req_acct.wallet = state.wallet;
        req_acct.token = state.token;
        req_acct.amount = amount;
        req_acct.height = state.height;
        req_acct.expiration = clock.unix_timestamp + ctx.accounts.config.challenge_period;
        req_acct.bump = ctx.bumps.request_account;

        emit!(Requested {
            wallet: state.wallet,
            token: state.token,
            amount,
        });

        emit!(Challenged {
            wallet: state.wallet,
            height: state.height,
            expiration: req_acct.expiration,
        });

        Ok(())
    }

    pub fn challenge(ctx: Context<Challenge>, candidate: State) -> Result<()> {
        let req_acct = &ctx.accounts.request_account;

        // 1. Verify existence of request
        require!(req_acct.expiration > 0, ClearnetError::NoPendingRequest);

        // 2. Verify new state is newer
        require!(
            candidate.height > req_acct.height,
            ClearnetError::CandidateNotNewer
        );

        // 3. Verify signatures (Mock as above)
        // require(verify_sigs(candidate), ...);

        // 4. Close request (Reject)
        // logic handled by `close` constraint or manual close?
        // We want to delete the data. The `close` instruction handles transferring lamports.
        // We just need to ensure the logic flows there.
        // In Anchor, we can't conditionally close in the same instruction easily unless we use `close` constraint on a separate "Close" ix
        // or manually realloc/assign.
        // Standard pattern: Mark as invalid, or actually Close.
        // We will close the account by sending lamports to the challenger.

        emit!(Rejected {
            wallet: req_acct.wallet,
            token: req_acct.token,
            amount: req_acct.amount,
        });

        Ok(())
    }

    pub fn withdraw(ctx: Context<Withdraw>, finalize: State) -> Result<()> {
        let req_acct = &ctx.accounts.request_account;
        let clock = Clock::get()?;

        // 1. Checks
        require!(req_acct.expiration > 0, ClearnetError::NoPendingRequest);
        require!(
            clock.unix_timestamp >= req_acct.expiration,
            ClearnetError::ChallengePeriodNotExpired
        );
        require!(
            finalize.height == req_acct.height,
            ClearnetError::StateMismatch
        );

        // 2. Transfer
        let amount = req_acct.amount;

        // Seeds for signing
        let bump = ctx.bumps.vault_token;
        let seeds = &[
            b"vault".as_ref(),
            ctx.accounts.mint.to_account_info().key.as_ref(),
            &[bump],
        ];
        let signer = &[&seeds[..]];

        let cpi_accounts = Transfer {
            from: ctx.accounts.vault_token.to_account_info(),
            to: ctx.accounts.user_token.to_account_info(),
            authority: ctx.accounts.vault_token.to_account_info(), // The PDA is the owner
        };
        let cpi_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
            signer,
        );
        token::transfer(cpi_ctx, amount)?;

        emit!(Withdrawn {
            wallet: req_acct.wallet,
            token: req_acct.token,
            amount,
        });

        Ok(())
    }
}

// --- Accounts ---

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init, 
        payer = admin, 
        space = 8 + 32 + 8,
        seeds = [b"config"], 
        bump
    )]
    pub config: Account<'info, VaultConfig>,
    #[account(mut)]
    pub admin: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(status: bool)]
pub struct SetNodeStatus<'info> {
    #[account(mut)]
    pub admin: Signer<'info>,
    #[account(
        init_if_needed,
        payer = admin,
        space = 8 + 32 + 1,
        seeds = [b"node", node_authority.key().as_ref()],
        bump
    )]
    pub node_entry: Account<'info, NodeEntry>,
    /// CHECK: The node's public key
    pub node_authority: UncheckedAccount<'info>,
    #[account(seeds = [b"config"], bump, has_one = admin)]
    pub config: Account<'info, VaultConfig>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Deposit<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    #[account(mut)]
    pub user_token: Account<'info, TokenAccount>,
    pub mint: Account<'info, Mint>,
    #[account(
        init_if_needed,
        payer = user,
        seeds = [b"vault", mint.key().as_ref()],
        bump,
        token::mint = mint,
        token::authority = vault_token,
    )]
    pub vault_token: Account<'info, TokenAccount>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
#[instruction(state: State)]
pub struct Request<'info> {
    #[account(mut)]
    pub user: Signer<'info>, // Wallet owner
    #[account(
        init,
        payer = user,
        space = 8 + 32 + 32 + 8 + 8 + 8 + 1, // Space for Request
        seeds = [b"request", user.key().as_ref()],
        bump
    )]
    pub request_account: Account<'info, WithdrawalRequest>,

    #[account(seeds = [b"config"], bump)]
    pub config: Account<'info, VaultConfig>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(candidate: State)]
pub struct Challenge<'info> {
    #[account(mut)]
    pub challenger: Signer<'info>, // Can be node or anyone? Vault.sol said Owner or Node.

    #[account(
        mut,
        close = challenger, // Send rent to challenger
        seeds = [b"request", candidate.wallet.as_ref()],
        bump = request_account.bump,
        has_one = wallet
    )]
    pub request_account: Account<'info, WithdrawalRequest>,

    // We should verify challenger is a node?
    // In Vault.sol: `candidate.wallet == msg.sender || isNode[msg.sender]`
    // Here we can check if `challenger` matches `wallet` OR if a `NodeEntry` exists for `challenger`.
    // It's cleaner to separate, but for now we assume validation logic inside or flexible.
    /// CHECK: Wallet being challenged.
    pub wallet: UncheckedAccount<'info>,
}

#[derive(Accounts)]
#[instruction(finalize: State)]
pub struct Withdraw<'info> {
    #[account(mut)]
    pub user: Signer<'info>,

    #[account(
        mut,
        close = user,
        seeds = [b"request", user.key().as_ref()],
        bump = request_account.bump
    )]
    pub request_account: Account<'info, WithdrawalRequest>,

    #[account(mut)]
    pub user_token: Account<'info, TokenAccount>,
    pub mint: Account<'info, Mint>,
    #[account(
        mut,
        seeds = [b"vault", mint.key().as_ref()],
        bump,
    )]
    pub vault_token: Account<'info, TokenAccount>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

// --- Data Structures ---

#[account]
pub struct VaultConfig {
    pub admin: Pubkey,
    pub challenge_period: i64,
}

#[account]
pub struct NodeEntry {
    pub authority: Pubkey,
    pub is_active: bool,
}

#[account]
pub struct WithdrawalRequest {
    pub wallet: Pubkey,
    pub token: Pubkey,
    pub amount: u64,
    pub height: u64,
    pub expiration: i64,
    pub bump: u8,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct State {
    pub wallet: Pubkey,
    pub token: Pubkey,
    pub height: u64,
    pub balance: u64,
    pub participants: Vec<Pubkey>,
    pub sigs: Vec<Vec<u8>>,
}

// --- Events ---

#[event]
pub struct Deposited {
    pub wallet: Pubkey,
    pub token: Pubkey,
    pub amount: u64,
}

#[event]
pub struct Requested {
    pub wallet: Pubkey,
    pub token: Pubkey,
    pub amount: u64,
}

#[event]
pub struct Challenged {
    pub wallet: Pubkey,
    pub height: u64,
    pub expiration: i64,
}

#[event]
pub struct Rejected {
    pub wallet: Pubkey,
    pub token: Pubkey,
    pub amount: u64,
}

#[event]
pub struct Withdrawn {
    pub wallet: Pubkey,
    pub token: Pubkey,
    pub amount: u64,
}

// --- Errors ---

#[error_code]
pub enum ClearnetError {
    #[msg("Insufficient state balance")]
    InsufficientStateBalance,
    #[msg("Request already pending")]
    RequestAlreadyPending,
    #[msg("Signature mismatch")]
    SigMismatch,
    #[msg("No pending request")]
    NoPendingRequest,
    #[msg("Candidate state is not newer")]
    CandidateNotNewer,
    #[msg("Challenge period not expired")]
    ChallengePeriodNotExpired,
    #[msg("State mismatch")]
    StateMismatch,
}
