#[test_only]
module movegpt::test_helper {
    use std::features;
    use aptos_framework::account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::Coin;
    use aptos_framework::delegation_pool;
    use aptos_framework::stake;
    use aptos_framework::timestamp;
    use movegpt::claim_sale;
    use movegpt::airdrop;
    use movegpt::voting_escrow;
    use movegpt::package_manager;
    use movegpt::vesting;
    use movegpt::movegpt_token;

    const MIN_APT_STAKE: u64 = 1000;
    const INITIAL_TIME: u64 = 1691370815;
    const ONE_APT: u64 = 100000000;

    public fun setup(deployer: &signer, operator: address) {
        timestamp::set_time_has_started_for_testing(&account::create_signer_for_test(@0x1));
        timestamp::fast_forward_seconds(INITIAL_TIME);
        let framework_signer = &account::create_signer_for_test(@0x1);
        features::change_feature_flags(framework_signer, vector[features::get_auids()], vector[]);
        delegation_pool::initialize_for_test_custom(
            framework_signer,
            MIN_APT_STAKE * ONE_APT,
            1000000000 * ONE_APT,
            3600,
            true,
            1,
            100,
            10000,
        );
        package_manager::initialize_for_test(deployer());
        movegpt_token::initialize(operator);
        voting_escrow::initialize(deployer);
        airdrop::initialize(deployer, operator);
        vesting::initialize(deployer, operator);
        claim_sale::initialize(deployer, operator);
    }

    public fun mint_apt(apt_amount: u64): Coin<AptosCoin> {
        stake::mint_coins(apt_amount * ONE_APT)
    }

    public inline fun deployer(): &signer {
        &account::create_signer_for_test(@0xcafe)
    }
}