module movegpt::movegpt_token {
    use std::option;
    use std::signer;
    use std::string;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::coin::{Coin, MintCapability, BurnCapability, FreezeCapability};
    use aptos_framework::event;
    use aptos_framework::event::EventHandle;
    use aptos_framework::object;
    use aptos_framework::object::Object;
    use movegpt::package_manager;
    friend movegpt::vesting;
    friend movegpt::claim_sale;
    friend movegpt::airdrop;
    friend movegpt::voting_escrow;

    /// Not authorized to perform this action
    const ENOT_AUTHORIZED: u64 = 1;

    const TOKEN_NAME: vector<u8> = b"MOVEGPT";
    const TOKEN_SYMBOL: vector<u8> = b"MGPT";
    const TOKEN_DECIMALS: u8 = 8;

    struct MovegptCoin has key{}

    struct MoveGPTManagement has key {
        burn_cap: BurnCapability<MovegptCoin>,
        freeze_cap: FreezeCapability<MovegptCoin>,
        mint_cap: MintCapability<MovegptCoin>,
        mint_event: EventHandle<MintEvent>,
        burn_event: EventHandle<BurnEvent>,
    }

    #[event]
    struct MintEvent has drop, store {
        amount: u64,
    }

    #[event]
    struct BurnEvent has drop, store {
        amount: u64,
    }

    public entry fun initialize(admin: &signer) {
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        inititalize_module();
    }
    fun inititalize_module() {
        if (is_initialized()) {
            return
        };
        let movegpt_signer = &package_manager::get_signer();
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<MovegptCoin>(
            movegpt_signer,
            string::utf8(TOKEN_NAME),
            string::utf8(TOKEN_SYMBOL),
            TOKEN_DECIMALS, // decimals
            true, // monitor_supply
        );
        move_to(movegpt_signer, MoveGPTManagement {
            burn_cap,
            freeze_cap,
            mint_cap,
            mint_event: account::new_event_handle<MintEvent>(movegpt_signer),
            burn_event: account::new_event_handle<BurnEvent>(movegpt_signer),
        });
        package_manager::add_address(string::utf8(TOKEN_NAME), signer::address_of(movegpt_signer));
    }

    #[view]
    public fun is_initialized(): bool {
        package_manager::address_exists(string::utf8(TOKEN_NAME))
    }

    #[view]
    /// Return $MGPT token address.
    public fun token_address(): address {
        package_manager::get_address(string::utf8(TOKEN_NAME))
    }

    #[view]
    /// Return the $MGPT token metadata object.
    public fun token(): Object<MovegptCoin> {
        object::address_to_object(token_address())
    }

    #[view]
    /// Return the total supply of $MGPT tokens.
    public fun total_supply(): u128 {
        option::get_with_default(&coin::supply<MovegptCoin>(), 0)
    }

    #[view]
    /// Return the total supply of $MGPT tokens.
    public fun balance(user: address): u64 {
        coin::balance<MovegptCoin>(user)
    }


    /// Called by the minter module to mint weekly emissions.
    public(friend) fun mint(amount: u64): Coin<MovegptCoin> acquires MoveGPTManagement {
        event::emit(MintEvent{
            amount,
        });
        coin::mint(amount, &movegpt_management().mint_cap)
    }

    public(friend) fun burn(mgpt: Coin<MovegptCoin>) acquires MoveGPTManagement {
        event::emit(BurnEvent{
            amount: coin::value(&mgpt),
        });
        coin::burn(mgpt, &movegpt_management().burn_cap);
    }

    public fun freeze_token(admin: &signer, account: address) acquires MoveGPTManagement {
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        coin::freeze_coin_store(account, &movegpt_management().freeze_cap)
    }

    public(friend) fun freeze_coin_store(account: address) acquires MoveGPTManagement {
        coin::freeze_coin_store(account, &movegpt_management().freeze_cap)
    }

    public fun unfreeze_token(admin: &signer, account: address) acquires MoveGPTManagement {
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        coin::unfreeze_coin_store(account, &movegpt_management().freeze_cap)
    }

    public(friend) fun unfreeze_coin_store(account: address) acquires MoveGPTManagement {
        coin::unfreeze_coin_store(account, &movegpt_management().freeze_cap)
    }

    inline fun unchecked_token_refs(): &MovegptCoin {
        borrow_global<MovegptCoin>(token_address())
    }

    inline fun movegpt_management(): &mut MoveGPTManagement{
        borrow_global_mut<MoveGPTManagement>(@movegpt)
    }

    #[test_only]
    friend movegpt::test_token;
    friend movegpt::test_voting_escrow;

    #[test_only]
    public fun test_mint(amount: u64): Coin<MovegptCoin> acquires MoveGPTManagement {
        mint(amount)
    }
}
