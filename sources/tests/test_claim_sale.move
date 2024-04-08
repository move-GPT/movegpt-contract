module movegpt::test_claim_sale {
    #[test_only]
    use std::signer;
    #[test_only]
    use std::vector;
    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use movegpt::claim_sale;
    #[test_only]
    use movegpt::epoch;
    #[test_only]
    use movegpt::movegpt_token;
    #[test_only]
    use movegpt::test_helper;
    #[test_only]
    use movegpt::voting_escrow;

    #[test(deployer = @0xcafe,recipient_ido = @0x123, recipient_ido2 = @0x124, recipient_private = @0xdead, recipient_private2 = @0xdeae, operator = @0xcafe)]
    fun test_e2e(recipient_ido: &signer, recipient_ido2: &signer, recipient_private: &signer, recipient_private2: &signer, operator: &signer, deployer: &signer) {
        test_helper::setup(deployer);
        let recipient_ido_address = signer::address_of(recipient_ido);
        let recipient_ido2_address = signer::address_of(recipient_ido2);
        let ido_amount = vector[100, 200];
        let private_amount = vector[150000, 250000];
        let recipient_private_address = signer::address_of(recipient_private);
        let recipient_private2_address = signer::address_of(recipient_private2);
        claim_sale::add_ido_claimers(operator, vector[recipient_ido_address, recipient_ido2_address], ido_amount);
        claim_sale::add_private_claimers(operator, vector[recipient_private_address, recipient_private2_address], private_amount);

        // set ido claime time
        claim_sale::set_ido_start_time(operator, timestamp::now_seconds() - 1);
        let nfts_ido = claim_sale::claim_ido(recipient_ido);
        let nfts_ido2 = claim_sale::claim_ido(recipient_ido2);
        assert!(vector::length(&nfts_ido) == 3, 1);
        assert!(vector::length(&nfts_ido2) == 3, 1);
        assert!(movegpt_token::balance(recipient_ido_address) == 100 / 4, 1);
        assert!(movegpt_token::balance(recipient_ido2_address) == 200 / 4, 1);
        let nft_ido_9m = vector::pop_back(&mut nfts_ido);
        let nft_ido_6m = vector::pop_back(&mut nfts_ido);
        let nft_ido_3m = vector::pop_back(&mut nfts_ido);
        let nft2_ido_9m = vector::pop_back(&mut nfts_ido2);
        let nft2_ido_6m = vector::pop_back(&mut nfts_ido2);
        let nft2_ido_3m = vector::pop_back(&mut nfts_ido2);
        assert!(voting_escrow::get_ve_token_lock_amount(nft_ido_3m) == 100 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_amount(nft_ido_6m) == 100 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_amount(nft_ido_9m) == 100 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_amount(nft2_ido_3m) == 200 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_amount(nft2_ido_6m) == 200 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_amount(nft2_ido_9m) == 200 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft_ido_3m) - epoch::now() == 13, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft_ido_6m) - epoch::now() == 26, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft2_ido_9m) - epoch::now() == 39, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft2_ido_3m) - epoch::now() == 13, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft2_ido_6m) - epoch::now() == 26, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft2_ido_9m) - epoch::now() == 39, 1);
        // set private claime time
        claim_sale::set_private_start_time(operator, timestamp::now_seconds() - 1);
        let nfts_private = claim_sale::claim_private(recipient_private);
        let nfts_private2 = claim_sale::claim_private(recipient_private2);
        assert!(vector::length(&nfts_private) == 4, 1);
        assert!(vector::length(&nfts_private2) == 4, 1);
        assert!(movegpt_token::balance(recipient_private_address) == 150000 / 10, 1);
        assert!(movegpt_token::balance(recipient_private2_address) == 250000 / 10, 1);
        let nft_private_12m = vector::pop_back(&mut nfts_private);
        let nft_private_9m = vector::pop_back(&mut nfts_private);
        let nft_private_6m = vector::pop_back(&mut nfts_private);
        let nft_private_3m = vector::pop_back(&mut nfts_private);
        let nft2_private_12m = vector::pop_back(&mut nfts_private2);
        let nft2_private_9m = vector::pop_back(&mut nfts_private2);
        let nft2_private_6m = vector::pop_back(&mut nfts_private2);
        let nft2_private_3m = vector::pop_back(&mut nfts_private2);
        assert!(voting_escrow::get_ve_token_lock_amount(nft_private_3m) == 150000 * 9 / 10 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_amount(nft_private_6m) == 150000 * 9 / 10 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_amount(nft_private_9m) == 150000 * 9 / 10 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_amount(nft_private_12m) == 150000 * 9 / 10 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_amount(nft2_private_3m) == 250000 * 9 / 10 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_amount(nft2_private_6m) == 250000 * 9 / 10 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_amount(nft2_private_9m) == 250000 * 9 / 10 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_amount(nft2_private_12m) == 250000 * 9 / 10 / 4, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft_private_3m) - epoch::now() == 13, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft_private_6m) - epoch::now() == 26, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft_private_9m) - epoch::now() == 39, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft_private_12m) - epoch::now() == 52, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft2_private_3m) - epoch::now() == 13, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft2_private_6m) - epoch::now() == 26, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft2_private_9m) - epoch::now() == 39, 1);
        assert!(voting_escrow::get_ve_token_lock_end_epoch(nft2_private_12m) - epoch::now() == 52, 1);
    }
}