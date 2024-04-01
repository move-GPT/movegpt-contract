#[test_only]
module movegpt::test_airdrop {
    use std::signer;
    use std::vector;
    use movegpt::epoch;
    use movegpt::movegpt_token;
    use movegpt::voting_escrow;
    use movegpt::airdrop;
    use movegpt::test_helper;
    const YEAR: u64 = 52;

    #[test(deployer=@0xcafe,buyer=@0xcafe,buyer2=@0xcafe2, oprater=@0xcafe)]
    public entry fun test_e2e(deployer: &signer, oprater: &signer, buyer: &signer, buyer2: &signer) {
        test_helper::setup(deployer, signer::address_of(oprater));
        let recipients = vector[signer::address_of(buyer), signer::address_of(buyer2)];
        let amounts = vector[100, 200];
        let nfts = airdrop::airdrop(oprater, recipients, amounts);
        assert!(vector::length(&nfts) == 2, 1);
        // fast forward 1 year
        epoch::fast_forward(YEAR);
        voting_escrow::withdraw(buyer, vector::remove(&mut nfts, 0));
        assert!(movegpt_token::balance(signer::address_of(buyer)) == 100, 2);
        voting_escrow::withdraw(buyer2, vector::remove(&mut nfts, 0));
        assert!(movegpt_token::balance(signer::address_of(buyer2)) == 200, 2);
    }
}