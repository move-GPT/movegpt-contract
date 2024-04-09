module movegpt::vesting {
    use std::signer;
    use std::string;
    use std::vector;
    use aptos_std::math64;
    use aptos_framework::account;
    use aptos_framework::aptos_account;
    use aptos_framework::coin;
    use aptos_framework::coin::{Coin};
    use aptos_framework::event;
    use aptos_framework::object::Object;
    use aptos_framework::timestamp;
    use movegpt::voting_escrow::VeMoveGptToken;
    use movegpt::voting_escrow;
    use movegpt::package_manager;
    use movegpt::movegpt_token;
    use movegpt::movegpt_token::{MovegptCoin};

    /// Not authorized to perform this action
    const ENOT_AUTHORIZED: u64 = 1;
    /// Not enough claimable
    const ENOT_AMOUNT_CLAIMABLE: u64 = 2;
    /// Not time to claim
    const ENOT_CLAIM_TIME: u64 = 3;
    /// Not vesting again
    const ENOT_VESTING_AGAIN: u64 = 4;

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
    const VESTING: vector<u8> = b"VESTING";
    const DECIMALS: u64 = 100;
    const MONTHS_IN_SECONDS: u64 = 30 * 86400;
    // 1 quarter 13 epch
    const QUARTER_IN_EPOCH: u64 = 13;
    const START: u64 = 1630454400; // 2021-09-01 00:00:00

    struct VestingConfig has key, store {
        coin_store: Coin<MovegptCoin>,
        claimed: u64,
        start: u64,
        tge: u64,
        vesting_duration: u64,
        vesting_periods: u64,
        last_vested_period: u64,
    }

    struct Vesting has key, store {
        team: VestingConfig,
        dev: VestingConfig,
        staking_reward: VestingConfig,
        marketing: VestingConfig,
        initial_liquidity: VestingConfig,
    }

    #[event]
    struct ClaimEvent has drop, store {
        claimer: address,
        amount: u64,
        time_stamp: u64,
    }

    public entry fun initialize(admin: &signer) {
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        if (is_initialized()) {
            return
        };
        init_mint();
    }

    inline fun init_mint() {
        let team_coin = movegpt_token::mint(INIT_TEAM_AMOUNT);
        let dev_coin = movegpt_token::mint(INIT_DEV_AMOUNT);
        let staking_reward_coin = movegpt_token::mint(INIT_STAKING_REWARD_AMOUNT);
        let marketing_coin = movegpt_token::mint(INIT_MARKETING_AMOUNT);
        let initial_liquidity_coin = movegpt_token::mint(INIT_INITIAL_LIQUIDITY_AMOUNT);
        let (vesting_signer, _) =
            account::create_resource_account(&package_manager::get_signer(), VESTING);
        move_to(&vesting_signer, Vesting {
            team: VestingConfig {
                coin_store: team_coin,
                claimed: 0,
                start: START,
                tge: 0,
                vesting_duration: 2 * QUARTER_IN_EPOCH * 4,
                vesting_periods: 2 * QUARTER_IN_EPOCH * 4,
                last_vested_period: 0
            },
            dev: VestingConfig {
                coin_store: dev_coin,
                claimed: 0,
                start: START,
                tge: 0,
                vesting_duration: QUARTER_IN_EPOCH * 4,
                vesting_periods: QUARTER_IN_EPOCH * 4,
                last_vested_period: 0
            },
            staking_reward: VestingConfig {
                coin_store: staking_reward_coin,
                claimed: 0,
                start: START,
                tge: 0,
                vesting_duration: 24 * MONTHS_IN_SECONDS,
                vesting_periods: MONTHS_IN_SECONDS,
                last_vested_period: 0
            },
            marketing: VestingConfig {
                coin_store: marketing_coin,
                claimed: 0,
                start: START,
                tge: 10,
                vesting_duration: 2 * QUARTER_IN_EPOCH,
                vesting_periods: QUARTER_IN_EPOCH,
                last_vested_period: 0
            },
            initial_liquidity: VestingConfig {
                coin_store: initial_liquidity_coin,
                claimed: 0,
                start: START,
                tge: 100,
                vesting_duration: 1,
                vesting_periods: 1,
                last_vested_period: 0
            }
        });
        package_manager::add_address(string::utf8(VESTING), signer::address_of(&vesting_signer));
    }

    #[view]
    public fun is_initialized(): bool {
        package_manager::address_exists(string::utf8(VESTING))
    }

    #[view]
    public fun vesting_address(): address {
        package_manager::get_address(string::utf8(VESTING))
    }

    public entry fun set_vesting_config_start_time_entry(
        admin: &signer,
        vesting_config_id: u8,
        new_start_time: u64,
    ) acquires Vesting {
        let vesting = get_vesting();
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        let vesting_config = &mut vesting.team;
        if (vesting_config_id == 1) {
            vesting_config = &mut vesting.dev;
        };
        if (vesting_config_id == 2) {
            vesting_config = &mut vesting.staking_reward;
        };
        if (vesting_config_id == 3) {
            vesting_config = &mut vesting.marketing;
        };
        if (vesting_config_id == 4) {
            vesting_config = &mut vesting.initial_liquidity;
        };
        vesting_config.start = new_start_time;
    }

    public entry fun set_vesting_config_duration_time_entry(
        admin: &signer,
        vesting_config_id: u8,
        new_duration_time: u64,
    ) acquires Vesting {
        let vesting = get_vesting();
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        if (vesting_config_id == 0) {
            let vesting_config = &mut vesting.team;
            vesting_config.vesting_duration = new_duration_time;
        };
        if (vesting_config_id == 1) {
            let vesting_config = &mut vesting.dev;
            vesting_config.vesting_duration = new_duration_time;
        };
        if (vesting_config_id == 2) {
            let vesting_config = &mut vesting.staking_reward;
            vesting_config.vesting_duration = new_duration_time;
        };
        if (vesting_config_id == 3) {
            let vesting_config = &mut vesting.marketing;
            vesting_config.vesting_duration = new_duration_time;
        };
        if (vesting_config_id == 4) {
            let vesting_config = &mut vesting.initial_liquidity;
            vesting_config.vesting_duration = new_duration_time;
        };
    }

    public entry fun set_vesting_config_periods_entry(
        admin: &signer,
        vesting_config_id: u8,
        new_periods_time: u64,
    ) acquires Vesting {
        let vesting = get_vesting();
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        if (vesting_config_id == 0) {
            let vesting_config = &mut vesting.team;
            vesting_config.vesting_periods = new_periods_time;
        };
        if (vesting_config_id == 1) {
            let vesting_config = &mut vesting.dev;
            vesting_config.vesting_periods = new_periods_time;
        };
        if (vesting_config_id == 2) {
            let vesting_config = &mut vesting.staking_reward;
            vesting_config.vesting_periods = new_periods_time;
        };
        if (vesting_config_id == 3) {
            let vesting_config = &mut vesting.marketing;
            vesting_config.vesting_periods = new_periods_time;
        };
        if (vesting_config_id == 4) {
            let vesting_config = &mut vesting.initial_liquidity;
            vesting_config.vesting_periods = new_periods_time;
        };
    }

    public entry fun set_vesting_config_tge_entry(
        admin: &signer,
        vesting_config_id: u8,
        tge: u64
    ) acquires Vesting {
        let vesting = get_vesting();
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        if (vesting_config_id == 0) {
            let vesting_config = &mut vesting.team;
            vesting_config.tge = tge;
        };
        if (vesting_config_id == 1) {
            let vesting_config = &mut vesting.dev;
            vesting_config.tge = tge;
        };
        if (vesting_config_id == 2) {
            let vesting_config = &mut vesting.staking_reward;
            vesting_config.tge = tge;
        };
        if (vesting_config_id == 3) {
            let vesting_config = &mut vesting.marketing;
            vesting_config.tge = tge;
        };
        if (vesting_config_id == 4) {
            let vesting_config = &mut vesting.initial_liquidity;
            vesting_config.tge = tge;
        };
    }

    public entry fun claim_entry(claimer: &signer) acquires Vesting {
        let vesting_config = get_vesting();
        let claimer_address = signer::address_of(claimer);
        if (claimer_address == @team) {
            claim_with_lock(&mut vesting_config.team, @team);
        } else if (claimer_address == @dev) {
            claim_with_lock(&mut vesting_config.dev, @dev);
        } else if (claimer_address == @staking_rewards) {
            claim(&mut vesting_config.staking_reward, @staking_rewards);
        } else if (claimer_address == @marketing) {
            claim_with_lock(&mut vesting_config.marketing, @marketing);
        } else if (claimer_address == @initial_liquidity) {
            claim(&mut vesting_config.initial_liquidity, @initial_liquidity);
        }else {
            assert!(false, ENOT_AUTHORIZED);
        }
    }

    inline fun claim_with_lock(vesting_config: &mut VestingConfig, recipient: address): vector<Object<VeMoveGptToken>> {
        let current_time = timestamp::now_seconds();
        let claimable = coin::value(&vesting_config.coin_store);
        assert!(current_time > vesting_config.start, ENOT_CLAIM_TIME);
        assert!(vesting_config.claimed == 0, ENOT_VESTING_AGAIN);
        let tge_amount = math64::mul_div(coin::value(&vesting_config.coin_store), vesting_config.tge, DECIMALS);
        let lock_amount = math64::mul_div(
            coin::value(&vesting_config.coin_store) - tge_amount,
            vesting_config.vesting_periods,
            vesting_config.vesting_duration
        );
        let total_nft = vesting_config.vesting_duration / vesting_config.vesting_periods;
        aptos_account::deposit_coins<MovegptCoin>(recipient, coin::extract(&mut vesting_config.coin_store, tge_amount));
        let i = 1;
        let nfts = vector::empty<Object<VeMoveGptToken>>();
        loop {
            if (i > total_nft) {
                break
            };
            let coin_lock = if (i == total_nft) coin::extract_all(&mut vesting_config.coin_store) else coin::extract(
                &mut vesting_config.coin_store,
                lock_amount
            );
            let epoch_duration = i * vesting_config.vesting_periods;
            let nft = voting_escrow::create_lock_with_start_lock_time(recipient, coin_lock, epoch_duration, vesting_config.start);
            vector::push_back(&mut nfts, nft);
            i = i + 1;
        };
        vesting_config.claimed = coin::value(&vesting_config.coin_store);
        event::emit(ClaimEvent {
            claimer: recipient,
            amount: claimable,
            time_stamp: current_time,
        });
        nfts
    }

    inline fun claim(vesting_config: &mut VestingConfig, recipient: address) {
        let current_time = timestamp::now_seconds();
        assert!(current_time > vesting_config.start, ENOT_CLAIM_TIME);
        let tge_amount = math64::mul_div(coin::value(&vesting_config.coin_store), vesting_config.tge, DECIMALS);
        if (vesting_config.tge > 0) {
            let claimable = tge_amount - vesting_config.claimed;
            assert!(claimable > 0, ENOT_AMOUNT_CLAIMABLE);
            vesting_config.claimed = vesting_config.claimed + claimable;
            aptos_account::deposit_coins<MovegptCoin>(
                recipient,
                coin::extract(&mut vesting_config.coin_store, claimable)
            );
            event::emit(ClaimEvent {
                claimer: recipient,
                amount: claimable,
                time_stamp: current_time,
            });
        } else {
            let total_parts = vesting_config.vesting_duration / vesting_config.vesting_periods;
            let parts_cal = (current_time - vesting_config.start) / vesting_config.vesting_periods;
            let parts = math64::min(parts_cal, total_parts);
            let vesting_amount = math64::mul_div(
                coin::value(&vesting_config.coin_store) - tge_amount,
                (parts - vesting_config.last_vested_period),
                (total_parts - vesting_config.last_vested_period)
            );
            let claimable = tge_amount + vesting_amount - math64::min(vesting_config.claimed, tge_amount);
            assert!(claimable > 0, ENOT_AMOUNT_CLAIMABLE);
            vesting_config.last_vested_period = parts;
            vesting_config.claimed = vesting_config.claimed + claimable;
            aptos_account::deposit_coins<MovegptCoin>(
                recipient,
                coin::extract(&mut vesting_config.coin_store, claimable)
            );
            event::emit(ClaimEvent {
                claimer: recipient,
                amount: claimable,
                time_stamp: current_time,
            });
        }
    }

    inline fun get_vesting(): &mut Vesting {
        borrow_global_mut<Vesting>(vesting_address())
    }

    #[test_only]
    public fun test_fun_claim_with_lock(claimer: &signer): vector<Object<VeMoveGptToken>> acquires Vesting {
        let vesting_config = get_vesting();
        let claimer_address = signer::address_of(claimer);
        if (claimer_address == @team) {
            return  claim_with_lock(&mut vesting_config.team, @team)
        } else if (claimer_address == @dev) {
            return claim_with_lock(&mut vesting_config.dev, @dev)
        } else if (claimer_address == @marketing) {
            return claim_with_lock(&mut vesting_config.marketing, @marketing)
        } else {
            assert!(false, ENOT_AUTHORIZED);
            vector::empty<Object<VeMoveGptToken>>()
        }
    }
}