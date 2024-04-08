module movegpt::airdrop {
    use std::signer;
    use std::string;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::coin::{Coin};
    use aptos_framework::event;
    use aptos_framework::object::Object;
    use aptos_framework::timestamp;
    use movegpt::voting_escrow::VeMoveGptToken;
    use movegpt::voting_escrow;
    use movegpt::package_manager;
    use movegpt::movegpt_token::MovegptCoin;
    use movegpt::movegpt_token;

    /// Not authorized to perform this action
    const ENOT_AUTHORIZED: u64 = 1;
    /// Invalid amount
    const EINVALID_AMOUNT: u64 = 2;
    /// Invalid data
    const EINVALID_DATA: u64 = 3;

    const YEAR: u64 = 52; // 1 month 30days

    struct Airdrop has key, store {
        store: Coin<MovegptCoin>,
    }

    #[event]
    struct AirdropEvent has drop, store {
        recipient: address,
        amount: u64,
        time_stamp: u64,
    }

    const INIT_AIRDROP_AMOUNT: u64 = 15000000000000000; // 150m * 1e8

    const AIRDROP: vector<u8> = b"AIRDROP";

    public entry fun initialize(admin: &signer) {
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        if (is_initialized()) {
            return
        };
        init_mint();
    }

    inline fun init_mint() {
        let airdrop_coin = movegpt_token::mint(INIT_AIRDROP_AMOUNT);
        let (airdrop_signer, _) = account::create_resource_account(&package_manager::get_signer(), AIRDROP);
        move_to(&airdrop_signer, Airdrop {
            store: airdrop_coin,
        });
        package_manager::add_address(string::utf8(AIRDROP), signer::address_of(&airdrop_signer));
    }

    #[view]
    public fun is_initialized(): bool {
        package_manager::address_exists(string::utf8(AIRDROP))
    }

    #[view]
    public fun airdrop_address(): address {
        package_manager::get_address(string::utf8(AIRDROP))
    }

    public entry fun airdrop_entry(
        operator: &signer,
        recipients: vector<address>,
        allocates: vector<u64>
    ) acquires Airdrop {
        airdrop(operator, recipients, allocates);
    }

    public fun airdrop(
        operator: &signer,
        recipients: vector<address>,
        allocates: vector<u64>
    ): vector<Object<VeMoveGptToken>> acquires Airdrop {
        let airdrop = get_airdrop_config();
        let operator_address = signer::address_of(operator);
        assert!(operator_address == package_manager::operator(), ENOT_AUTHORIZED);
        assert!(vector::length(&recipients) == vector::length(&allocates), EINVALID_DATA);
        let nfts = vector::empty<Object<VeMoveGptToken>>();
        vector::zip(recipients, allocates, |recipient, allocate|{
            let coins = coin::extract(&mut airdrop.store, allocate);
            let nft = voting_escrow::create_lock(recipient, coins, YEAR);
            vector::push_back(&mut nfts, nft);
            event::emit(AirdropEvent {
                recipient,
                amount: allocate,
                time_stamp: timestamp::now_seconds(),
            });
        });
        nfts
    }

    inline fun get_airdrop_config(): &mut Airdrop {
        borrow_global_mut<Airdrop>(airdrop_address())
    }
}
