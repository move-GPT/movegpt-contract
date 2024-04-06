module movegpt::test_vesting {
    #[test_only]
    use std::signer;
    #[test_only]
    use std::vector;
    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use movegpt::movegpt_token;
    #[test_only]
    use movegpt::test_helper;
    #[test_only]
    use movegpt::vesting;
    #[test_only]
    use movegpt::voting_escrow;

    const MONTHS: u64 = 86400 * 30;
    // 1 month 30days
    const INIT_MINT_AMOUNT: u64 = 100000000000000000;
    // 1B * 1e8
    const INIT_PRIVATE_ROUND_AMOUNT: u64 = 4000000000000000;
    // 40m * 1e8
    const INIT_IDO_ROUND_AMOUNT: u64 = 12000000000000000;
    // 120m * 1e8
    const INIT_INITIAL_LIQUIDITY_AMOUNT: u64 = 5000000000000000;
    // 50m * 1e8
    const INIT_TEAM_AMOUNT: u64 = 15000000000000000;
    // 150m * 1e8
    const INIT_DEV_AMOUNT: u64 = 10000000000000000;
    // 100m * 1e8
    const INIT_STAKING_REWARD_AMOUNT: u64 = 24000000000000000;
    // 225m * 1e8
    const INIT_AIRDROP_AMOUNT: u64 = 15000000000000000;
    // 150m * 1e8
    const INIT_MARKETING_AMOUNT: u64 = 15000000000000000; // 150m * 1e8

    #[test(
        deployer = @0xcafe,
        operator = @0xcafe1,
        marketing = @marketing,
        staking_rewards = @staking_rewards,
        dev = @dev,
        team = @team,
        initial_liquidity = @initial_liquidity
    )]
    public entry fun test_e2e(
        deployer: &signer,
        operator: &signer,
        marketing: &signer,
        staking_rewards: &signer,
        dev: &signer,
        team: &signer,
        initial_liquidity: &signer
    ) {
        test_helper::setup(deployer, signer::address_of(operator));
        assert!(
            INIT_MARKETING_AMOUNT + INIT_AIRDROP_AMOUNT + INIT_STAKING_REWARD_AMOUNT + INIT_DEV_AMOUNT + INIT_TEAM_AMOUNT + INIT_INITIAL_LIQUIDITY_AMOUNT + INIT_IDO_ROUND_AMOUNT + INIT_PRIVATE_ROUND_AMOUNT == INIT_MINT_AMOUNT,
            1
        );
        vesting::set_vesting_config_start_time_entry(
            operator,
            0,
            timestamp::now_seconds() - 1,
        );
        vesting::set_vesting_config_start_time_entry(
            operator,
            1,
            timestamp::now_seconds() - 1,
        );
        vesting::set_vesting_config_start_time_entry(
            operator,
            2,
            timestamp::now_seconds() - 1,
        );
        vesting::set_vesting_config_start_time_entry(
            operator,
            3,
            timestamp::now_seconds() - 1,
        );
        vesting::set_vesting_config_start_time_entry(
            operator,
            4,
            timestamp::now_seconds() - 1,
        );
        let nfts_marketing = vesting::test_fun_claim_with_lock(marketing);
        let marketing_balance = movegpt_token::balance(@marketing);
        assert!(marketing_balance == INIT_MARKETING_AMOUNT / 10, 1);
        vesting::claim_entry(initial_liquidity);
        let initial_liquidity_balance = movegpt_token::balance(@initial_liquidity);
        assert!(initial_liquidity_balance == INIT_INITIAL_LIQUIDITY_AMOUNT, 1);
        let nfts_dev = vesting::test_fun_claim_with_lock(dev);
        let dev_balance = movegpt_token::balance(@dev);
        assert!(dev_balance == 0, 1);
        let nfts_team = vesting::test_fun_claim_with_lock(team);
        let team_balance = movegpt_token::balance(@team);
        assert!(team_balance == 0, 1);
        // fast_forward_seconds 1 month
        aptos_framework::timestamp::fast_forward_seconds(MONTHS);
        vesting::claim_entry(staking_rewards);
        let staking_rewards_balance = movegpt_token::balance(@staking_rewards);
        assert!(staking_rewards_balance == INIT_STAKING_REWARD_AMOUNT / 24, 1);
        // fast_forward_seconds 1 month
        aptos_framework::timestamp::fast_forward_seconds(MONTHS);
        vesting::claim_entry(staking_rewards);
        let staking_rewards_balance = movegpt_token::balance(@staking_rewards);
        assert!(staking_rewards_balance == INIT_STAKING_REWARD_AMOUNT / 24 * 2, 1);
        // fast_forward_seconds 1 month
        aptos_framework::timestamp::fast_forward_seconds(MONTHS);
        vesting::claim_entry(staking_rewards);
        let staking_rewards_balance = movegpt_token::balance(@staking_rewards);
        assert!(staking_rewards_balance == INIT_STAKING_REWARD_AMOUNT / 24 * 3, 1);
        voting_escrow::withdraw(marketing, vector::remove(&mut nfts_marketing, 0));
        let marketing_balance = movegpt_token::balance(@marketing);
        assert!(marketing_balance == INIT_MARKETING_AMOUNT / 100 * 55, 1);
        // fast_forward_seconds 3 month
        aptos_framework::timestamp::fast_forward_seconds( 3 * MONTHS);
        vesting::claim_entry(staking_rewards);
        let staking_rewards_balance = movegpt_token::balance(@staking_rewards);
        assert!(staking_rewards_balance == INIT_STAKING_REWARD_AMOUNT / 24 * 6, 1);
        voting_escrow::withdraw(marketing, vector::remove(&mut nfts_marketing, 0));
        let marketing_balance = movegpt_token::balance(@marketing);
        assert!(marketing_balance == INIT_MARKETING_AMOUNT, 1);
        // fast_forward_seconds 6 month
        aptos_framework::timestamp::fast_forward_seconds( 6 * MONTHS);
        vesting::claim_entry(staking_rewards);
        let staking_rewards_balance = movegpt_token::balance(@staking_rewards);
        assert!(staking_rewards_balance == INIT_STAKING_REWARD_AMOUNT / 24 * 12, 1);
        voting_escrow::withdraw(dev, vector::remove(&mut nfts_dev, 0));
        let dev_balance = movegpt_token::balance(@dev);
        assert!(dev_balance == INIT_DEV_AMOUNT, 1);
        // fast_forward_seconds 12 month
        aptos_framework::timestamp::fast_forward_seconds( 12 * MONTHS + 7 * 86400 + 1);
        vesting::claim_entry(staking_rewards);
        let staking_rewards_balance = movegpt_token::balance(@staking_rewards);
        assert!(staking_rewards_balance == INIT_STAKING_REWARD_AMOUNT, 1);
        voting_escrow::withdraw(team, vector::remove(&mut nfts_team, 0));
        let team_balance = movegpt_token::balance(@team);
        assert!(team_balance == INIT_TEAM_AMOUNT, 1);
    }
}