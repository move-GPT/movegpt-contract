module movegpt::test_token {
    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_framework::aptos_account;
    #[test_only]
    use aptos_framework::coin;
    #[test_only]
    use movegpt::movegpt_token;
    #[test_only]
    use movegpt::movegpt_token::MovegptCoin;
    #[test_only]
    use movegpt::package_manager;
    #[test_only]
    use movegpt::test_helper;

    const INIT_MINT_AMOUNT: u64 = 100000000000000000;

    #[test(deployer = @0xcafe,sender = @0x123, recipient = @0xdead)]
    fun test_e2e(deployer: &signer, sender: &signer, recipient: &signer) {
        test_helper::setup(deployer);
        let tokens = movegpt_token::mint(1000);
        assert!((movegpt_token::total_supply() as u64) == (INIT_MINT_AMOUNT + 1000), 0);
        let sender_addr = signer::address_of(sender);
        aptos_account::deposit_coins<MovegptCoin>(sender_addr, tokens);
        assert!(coin::balance<MovegptCoin>(sender_addr) == 1000, 0);
        let recipient_addr = signer::address_of(recipient);
        aptos_account::transfer_coins<MovegptCoin>(sender, recipient_addr, 500);
        assert!(coin::balance<MovegptCoin>(sender_addr) == 500, 0);
        assert!(coin::balance<MovegptCoin>(recipient_addr) == 500, 0);
        let tokens = coin::withdraw<MovegptCoin>(recipient, 500);
        movegpt_token::burn(tokens);
        assert!(coin::balance<MovegptCoin>(recipient_addr) == 0, 0);
        movegpt_token::freeze_token(deployer, recipient_addr);
        assert!(coin::is_coin_store_frozen<MovegptCoin>(recipient_addr), 0);
        movegpt_token::unfreeze_token(deployer, recipient_addr);
        assert!(!coin::is_coin_store_frozen<MovegptCoin>(recipient_addr), 0);

        package_manager::update_operator(deployer, sender_addr);
        movegpt_token::freeze_token(sender, recipient_addr);
        assert!(coin::is_coin_store_frozen<MovegptCoin>(recipient_addr), 0);
    }

    #[test(deployer=@0xcafe, fake_operator=@0xcafe2)]
    #[expected_failure(abort_code = 1,location=movegpt_token)]
    public entry fun test_token_freeze_fail_by_auth(deployer: &signer, fake_operator: &signer) {
        test_helper::setup(deployer);
        movegpt_token::freeze_token(fake_operator, signer::address_of(deployer));
    }
}