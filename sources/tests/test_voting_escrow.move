module movegpt::test_voting_escrow {
    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_framework::coin;
    #[test_only]
    use aptos_framework::object;
    #[test_only]
    use movegpt::movegpt_token;
    #[test_only]
    use movegpt::test_helper;
    #[test_only]
    use movegpt::voting_escrow;
    #[test_only]
    use movegpt::epoch;
    #[test_only]
    use movegpt::movegpt_token::MovegptCoin;

    #[test(user = @0xcafe1, deployer = @0xcafe)]
    public entry fun test_e2e(user: &signer, deployer: &signer) {
        test_helper::setup(deployer);
        let lock_amount = 1000;
        let mgpt_coin = movegpt_token::mint(lock_amount);
        let nft = voting_escrow::create_lock(signer::address_of(user), mgpt_coin, 2);
        let nft_address = object::object_address(&nft);
        assert!(voting_escrow::get_ve_token_lock_amount(nft) == lock_amount, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft) == epoch::now() + 2, 1);
        
        // increase amount
        let increase_amount = 500;
        let increase_coin = movegpt_token::mint(increase_amount);
        voting_escrow::increase_amount(user, nft, increase_coin);
        assert!(voting_escrow::get_ve_token_lock_amount(nft) == lock_amount + increase_amount, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft) == epoch::now() + 2, 1);
        
        // extend lock
        voting_escrow::extend_lockup(user, nft, 4);
        assert!(voting_escrow::get_ve_token_lock_amount(nft) == lock_amount + increase_amount, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft) == epoch::now() + 4, 1);

        let is_frozen = coin::is_coin_store_frozen<MovegptCoin>(nft_address);
        assert!(is_frozen, 1);
        epoch::fast_forward(4);
        voting_escrow::withdraw(user, nft);
        let balance = movegpt_token::balance(signer::address_of(user));
        assert!(balance == lock_amount + increase_amount, 1);
    }
}