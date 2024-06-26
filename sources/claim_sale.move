module movegpt::claim_sale {
    use std::signer;
    use std::string;
    use std::vector;
    use aptos_std::math64;
    use aptos_std::smart_table;
    use aptos_std::smart_table::SmartTable;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::coin::Coin;
    use aptos_framework::timestamp;
    use movegpt::movegpt_token;
    use movegpt::package_manager;
    use aptos_framework::aptos_account;
    use aptos_framework::event;
    use aptos_framework::object::Object;
    use movegpt::voting_escrow;
    use movegpt::voting_escrow::VeMoveGptToken;
    use movegpt::movegpt_token::{MovegptCoin};

    /// Not authorized to perform this action
    const ENOT_AUTHORIZED: u64 = 1;
    /// Not enough claimable
    const ENOT_AMOUNT_CLAIMABLE: u64 = 2;
    /// Not time to claim
    const ENOT_CLAIM_TIME: u64 = 3;
    /// Not running now
    const ENOT_RUNNING: u64 = 4;
    /// ENOT invalidate input
    const ENOT_VALI_INPUT: u64 = 5;
    /// Already refunded
    const ENOT_EALREADY_REFUNDED: u64 = 6;
    /// Already claimed
    const ENOT_EALREADY_CLAIMED: u64 = 7;
    /// ENOT balance to withdraw
    const ENOT_WITDRAW_BALANCE: u64 = 8;

    // 40m * 1e8
    const INIT_PRIVATE_ROUND_AMOUNT: u64 = 4000000000000000;
    // 150m * 1e8
    const INIT_IDO_ROUND_AMOUNT: u64 = 15000000000000000;
    const TGE_DECIMALS: u64 = 100;
    // 1 quarter 13 epch
    const QUARTER_IN_EPOCH: u64 = 13;

    const CLAIM_SALE: vector<u8> = b"CLAIM_SALE";


    struct Claimer has key, copy, drop, store {
        allocate: u64,
        claimed: u64,
        is_refund: bool
    }

    struct ConfigRoud has key, store {
        claimers: SmartTable<address, Claimer>,
        claimers_spores: SmartTable<address, Claimer>,
        claimers_cell: SmartTable<address, Claimer>,
        balances: Coin<MovegptCoin>,
        tge: u64,
        total_claimed: u64,
        total_bought: u64,
        withdrawed: u64,
        lock_duration: u64,
        periods: u64,
        start_time: u64,
    }

    struct Sales has key, store {
        paused: bool,
        private_round: ConfigRoud,
        ido_round: ConfigRoud,
    }

    #[event]
    struct ClaimEvent has drop, store {
        claimer: address,
        amount: u64,
        time_stamp: u64,
    }

    #[event]
    struct WithdrawEvent has drop, store {
        operator: address,
        amount: u64,
        time_stamp: u64,
    }

    #[event]
    struct AddClaimerEvent has drop, store {
        claimers: vector<address>,
        amount: vector<u64>,
        time_stamp: u64,
    }

    #[event]
    struct AddSporeClaimerEvent has drop, store {
        claimers: vector<address>,
        amount: vector<u64>,
        time_stamp: u64,
    }

    #[event]
    struct AddCellClaimerEvent has drop, store {
        claimers: vector<address>,
        amount: vector<u64>,
        time_stamp: u64,
    }

    #[event]
    struct RefundEvent has drop, store {
        user: address,
        amount: u64,
        round: u8,
        // 0: priavte, 1: ido
        time_stamp: u64,
    }

    #[view]
    public fun ido_start_view(): u64 acquires Sales {
        get_sales_config().ido_round.start_time
    }

    #[view]
    public fun ido_total_claimed_view(): u64 acquires Sales {
        get_sales_config().ido_round.total_claimed
    }

    #[view]
    public fun private_start_view(): u64 acquires Sales {
        get_sales_config().private_round.start_time
    }

    #[view]
    public fun private_total_claimed_view(): u64 acquires Sales {
        get_sales_config().private_round.total_claimed
    }

    #[view]
    public fun claimer_ido_info_view(claimer: address): Claimer acquires Sales {
        *get_claimers_info(claimer, &mut get_sales_config().ido_round)
    }

    #[view]
    public fun claimer_ido_spore_info_view(claimer: address): Claimer acquires Sales {
        *get_claimers_spore_info(claimer, &mut get_sales_config().ido_round)
    }

    #[view]
    public fun claimer_ido_cell_info_view(claimer: address): Claimer acquires Sales {
        *get_claimers_cell_info(claimer, &mut get_sales_config().ido_round)
    }

    #[view]
    public fun claimer_private_info_view(claimer: address): Claimer acquires Sales {
        *get_claimers_info(claimer, &mut get_sales_config().private_round)
    }

    public entry fun initialize(admin: &signer) {
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        if (is_initialized()) {
            return
        };
        init_mint();
    }

    inline fun init_mint() {
        let private_coin = movegpt_token::mint(INIT_PRIVATE_ROUND_AMOUNT);
        let ido_coin = movegpt_token::mint(INIT_IDO_ROUND_AMOUNT);
        let (claim_sale_signer, _) =
            account::create_resource_account(&package_manager::get_signer(), CLAIM_SALE);
        move_to(&claim_sale_signer, Sales {
            paused: false,
            private_round: ConfigRoud {
                claimers: smart_table::new(),
                claimers_cell: smart_table::new(),
                claimers_spores: smart_table::new(),
                balances: private_coin,
                tge: 10,
                lock_duration: 4 * QUARTER_IN_EPOCH,
                periods: QUARTER_IN_EPOCH,
                start_time: 1713164400, // 2024-04-15 07:00:00 UTC
                total_bought: 0,
                total_claimed: 0,
                withdrawed: 0,
            },
            ido_round: ConfigRoud {
                claimers: smart_table::new(),
                claimers_cell: smart_table::new(),
                claimers_spores: smart_table::new(),
                balances: ido_coin,
                tge: 25,
                lock_duration: 3 * QUARTER_IN_EPOCH,
                periods: QUARTER_IN_EPOCH,
                start_time: 1713164400, // 2024-04-15 07:00:00 UTC
                total_bought: 0,
                total_claimed: 0,
                withdrawed: 0,
            }
        });
        package_manager::add_address(string::utf8(CLAIM_SALE), signer::address_of(&claim_sale_signer));
    }

    #[view]
    public fun is_initialized(): bool {
        package_manager::address_exists(string::utf8(CLAIM_SALE))
    }

    #[view]
    public fun claim_sale(): address {
        package_manager::get_address(string::utf8(CLAIM_SALE))
    }

    public entry fun set_salse_status(operator: &signer, is_paused: bool) acquires Sales {
        let sales_config = get_sales_config();
        assert!(signer::address_of(operator) == package_manager::operator(), ENOT_AUTHORIZED);
        sales_config.paused = is_paused;
    }

    public entry fun set_ido_start_time(operator: &signer, new_start_time: u64) acquires Sales {
        let sales_config = get_sales_config();
        assert!(signer::address_of(operator) == package_manager::operator(), ENOT_AUTHORIZED);
        sales_config.ido_round.start_time = new_start_time;
    }

    public entry fun set_private_start_time(operator: &signer, new_start_time: u64) acquires Sales {
        let sales_config = get_sales_config();
        assert!(signer::address_of(operator) == package_manager::operator(), ENOT_AUTHORIZED);
        sales_config.private_round.start_time = new_start_time;
    }

    public entry fun set_vesting_config_total_bought_entry(
        admin: &signer,
        round_id: u8,
        new_total_bought: u64,
    ) acquires Sales {
        let vesting = get_sales_config();
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        if (round_id == 0) {
            let vesting_config = &mut vesting.private_round;
            vesting_config.total_bought = new_total_bought;
        };
        if (round_id == 1) {
            let vesting_config = &mut vesting.ido_round;
            vesting_config.total_bought = new_total_bought;
        };
    }

    public entry fun set_vesting_config_lock_duration_entry(
        admin: &signer,
        round_id: u8,
        new_lock_duration: u64,
    ) acquires Sales {
        let vesting = get_sales_config();
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        if (round_id == 0) {
            let vesting_config = &mut vesting.private_round;
            vesting_config.lock_duration = new_lock_duration;
        };
        if (round_id == 1) {
            let vesting_config = &mut vesting.ido_round;
            vesting_config.lock_duration = new_lock_duration;
        };
    }

    public entry fun set_vesting_config_periods_time_entry(
        admin: &signer,
        round_id: u8,
        new_periods_time: u64,
    ) acquires Sales {
        let vesting = get_sales_config();
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        if (round_id == 0) {
            let vesting_config = &mut vesting.private_round;
            vesting_config.periods = new_periods_time;
        };
        if (round_id == 1) {
            let vesting_config = &mut vesting.ido_round;
            vesting_config.periods = new_periods_time;
        };
    }

    public entry fun set_vesting_config_tge_entry(
        admin: &signer,
        round_id: u8,
        new_periods_time: u64,
    ) acquires Sales {
        let vesting = get_sales_config();
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        if (round_id == 0) {
            let vesting_config = &mut vesting.private_round;
            vesting_config.tge = new_periods_time;
        };
        if (round_id == 1) {
            let vesting_config = &mut vesting.ido_round;
            vesting_config.tge = new_periods_time;
        };
    }

    public entry fun refund_ido_mgpt_entry(claimer: &signer, round_id: u8) acquires Sales {
        let claimer_address = signer::address_of(claimer);
        let sales_config = get_sales_config();
        let round_config = &mut sales_config.ido_round;
        let claimer_info = get_claimers_info(claimer_address, round_config);
        assert!(claimer_info.claimed == 0, ENOT_EALREADY_CLAIMED);
        assert!(!claimer_info.is_refund, ENOT_EALREADY_REFUNDED);
        claimer_info.is_refund = true;
        round_config.total_bought = round_config.total_bought - claimer_info.allocate;
        event::emit(RefundEvent {
            user: signer::address_of(claimer),
            amount: claimer_info.allocate,
            round: round_id,
            time_stamp: timestamp::now_seconds(),
        });
    }

    public entry fun refund_ido_spore_entry(claimer: &signer, round_id: u8) acquires Sales {
        let claimer_address = signer::address_of(claimer);
        let sales_config = get_sales_config();
        let round_config = &mut sales_config.ido_round;
        let claimer_info = get_claimers_spore_info(claimer_address, round_config);
        assert!(claimer_info.claimed == 0, ENOT_EALREADY_CLAIMED);
        assert!(!claimer_info.is_refund, ENOT_EALREADY_REFUNDED);
        claimer_info.is_refund = true;
        round_config.total_bought = round_config.total_bought - claimer_info.allocate;
        event::emit(RefundEvent {
            user: signer::address_of(claimer),
            amount: claimer_info.allocate,
            round: round_id,
            time_stamp: timestamp::now_seconds(),
        });
    }

    public entry fun claim_private_entry(claimer: &signer) acquires Sales {
        claim_private(claimer);
    }

    public entry fun claim_entry(claimer: &signer, claim_id: u64) acquires Sales {
        claim_ido(claimer, claim_id);
    }

    public(friend) fun claim_ido(claimer: &signer, claim_id: u64): vector<Object<VeMoveGptToken>> acquires Sales {
        let sales_config = get_sales_config();
        assert!(!sales_config.paused, ENOT_RUNNING);
        safe_claim_ido(claimer, &mut sales_config.ido_round, claim_id)
    }

    public(friend) fun claim_private(claimer: &signer): vector<Object<VeMoveGptToken>> acquires Sales {
        let sales_config = get_sales_config();
        assert!(!sales_config.paused, ENOT_RUNNING);
        safe_claim_private(claimer, &mut sales_config.private_round)
    }

    inline fun safe_claim_private(claimer: &signer, round_config: &mut ConfigRoud): vector<Object<VeMoveGptToken>> {
        let claimer_address = signer::address_of(claimer);
        let current_time = timestamp::now_seconds();
        assert!(current_time > round_config.start_time, ENOT_CLAIM_TIME);
        let claimer_info = get_claimers_info(claimer_address, round_config);
        assert!(!claimer_info.is_refund, ENOT_EALREADY_REFUNDED);
        assert!(claimer_info.claimed == 0, ENOT_EALREADY_CLAIMED);
        let tge_amount = math64::mul_div(claimer_info.allocate, round_config.tge, TGE_DECIMALS);
        let lock_amount = math64::mul_div(
            claimer_info.allocate - tge_amount,
            round_config.periods,
            round_config.lock_duration
        );
        let total_nft = round_config.lock_duration / round_config.periods;
        aptos_account::deposit_coins<MovegptCoin>(
            claimer_address,
            coin::extract(&mut round_config.balances, tge_amount)
        );
        let i = 1;
        let nfts = vector::empty<Object<VeMoveGptToken>>();
        loop {
            if (i > total_nft) {
                break
            };
            if (lock_amount >= coin::value(&round_config.balances)) {
                i = total_nft
            };
            let coin_lock = if (lock_amount >= coin::value(&round_config.balances)) coin::extract_all(
                &mut round_config.balances
            ) else coin::extract(
                &mut round_config.balances,
                lock_amount
            );
            let epoch_duration = i * round_config.periods;
            let nft = voting_escrow::create_lock_with_start_lock_time(
                claimer_address,
                coin_lock,
                epoch_duration,
                round_config.start_time
            );
            vector::push_back(&mut nfts, nft);
            i = i + 1;
        };
        claimer_info.claimed = claimer_info.allocate;
        event::emit(ClaimEvent {
            claimer: claimer_address,
            amount: claimer_info.allocate,
            time_stamp: current_time,
        });
        nfts
    }

    inline fun safe_claim_ido(
        claimer: &signer,
        round_config: &mut ConfigRoud,
        claim_id: u64
    ): vector<Object<VeMoveGptToken>> {
        let claimer_address = signer::address_of(claimer);
        let current_time = timestamp::now_seconds();
        assert!(current_time > round_config.start_time, ENOT_CLAIM_TIME);
        let claimer_info = if (claim_id == 0) get_claimers_info(
            claimer_address,
            round_config
        ) else if (claim_id == 1) get_claimers_spore_info(claimer_address, round_config) else get_claimers_cell_info(
            claimer_address,
            round_config
        );
        assert!(!claimer_info.is_refund, ENOT_EALREADY_REFUNDED);
        assert!(claimer_info.claimed == 0, ENOT_EALREADY_CLAIMED);
        let tge_amount = math64::mul_div(claimer_info.allocate, round_config.tge, TGE_DECIMALS);
        let lock_amount = math64::mul_div(
            claimer_info.allocate - tge_amount,
            round_config.periods,
            round_config.lock_duration
        );
        let total_nft = round_config.lock_duration / round_config.periods;
        aptos_account::deposit_coins<MovegptCoin>(
            claimer_address,
            coin::extract(&mut round_config.balances, tge_amount)
        );
        let i = 1;
        let nfts = vector::empty<Object<VeMoveGptToken>>();
        loop {
            if (i > total_nft) {
                break
            };
            if (lock_amount >= coin::value(&round_config.balances)) {
                i = total_nft
            };
            let coin_lock = if (lock_amount >= coin::value(&round_config.balances)) coin::extract_all(
                &mut round_config.balances
            ) else coin::extract(
                &mut round_config.balances,
                lock_amount
            );
            let epoch_duration = i * round_config.periods;
            let nft = voting_escrow::create_lock_with_start_lock_time(
                claimer_address,
                coin_lock,
                epoch_duration,
                round_config.start_time
            );
            vector::push_back(&mut nfts, nft);
            i = i + 1;
        };
        claimer_info.claimed = claimer_info.allocate;
        event::emit(ClaimEvent {
            claimer: claimer_address,
            amount: claimer_info.allocate,
            time_stamp: current_time,
        });
        nfts
    }

    public fun withdraw(operator: &signer) acquires Sales {
        let sales_config = get_sales_config();
        let operator_address = signer::address_of(operator);
        assert!(operator_address == package_manager::operator(), ENOT_AUTHORIZED);
        withdraw_round(operator_address, &mut sales_config.ido_round, true);
        withdraw_round(operator_address, &mut sales_config.private_round, false);
    }

    inline fun withdraw_round(operator: address, round_config: &mut ConfigRoud, is_ido: bool): u64 {
        let current_time = timestamp::now_seconds();
        assert!(current_time > round_config.start_time, ENOT_CLAIM_TIME);
        let total_amount_avaiable = &mut (INIT_PRIVATE_ROUND_AMOUNT - round_config.total_bought);
        if (is_ido) {
            total_amount_avaiable = &mut (INIT_IDO_ROUND_AMOUNT - round_config.total_bought);
        };
        assert!(*total_amount_avaiable > round_config.withdrawed, ENOT_WITDRAW_BALANCE);
        aptos_account::deposit_coins<MovegptCoin>(
            operator,
            coin::extract(&mut round_config.balances, *total_amount_avaiable)
        );
        round_config.withdrawed = *total_amount_avaiable;
        event::emit(WithdrawEvent {
            operator,
            amount: *total_amount_avaiable,
            time_stamp: current_time,
        });
        *total_amount_avaiable
    }

    public entry fun add_private_claimers(
        operator: &signer,
        recipients: vector<address>,
        allocates: vector<u64>,
    ) acquires Sales {
        let sales_config = get_sales_config();
        assert!(!sales_config.paused, ENOT_RUNNING);
        assert!(signer::address_of(operator) == package_manager::operator(), ENOT_AUTHORIZED);
        assert!(vector::length(&recipients) == vector::length(&allocates), ENOT_VALI_INPUT);
        add_round_claimers(&mut sales_config.private_round, recipients, allocates);
    }

    public entry fun add_ido_claimers(
        operator: &signer,
        recipients: vector<address>,
        allocates: vector<u64>,
    ) acquires Sales {
        let sales_config = get_sales_config();
        assert!(!sales_config.paused, ENOT_RUNNING);
        assert!(signer::address_of(operator) == package_manager::operator(), ENOT_AUTHORIZED);
        assert!(vector::length(&recipients) == vector::length(&allocates), ENOT_VALI_INPUT);
        add_round_claimers(&mut sales_config.ido_round, recipients, allocates);
    }

    inline fun add_round_claimers(
        round_config: &mut ConfigRoud,
        recipients: vector<address>,
        allocates: vector<u64>,
    ) {
        vector::zip(recipients, allocates, |recipient, allocate|{
            round_config.total_bought = round_config.total_bought + allocate;
            smart_table::upsert(
                &mut round_config.claimers,
                recipient,
                Claimer {
                    allocate,
                    claimed: 0,
                    is_refund: false,
                }
            );
        });
        event::emit(AddClaimerEvent {
            claimers: recipients,
            amount: allocates,
            time_stamp: timestamp::now_seconds(),
        });
    }

    public entry fun add_ido_claimers_spore(
        operator: &signer,
        recipients: vector<address>,
        allocates: vector<u64>,
    ) acquires Sales {
        let sales_config = get_sales_config();
        assert!(!sales_config.paused, ENOT_RUNNING);
        assert!(signer::address_of(operator) == package_manager::operator(), ENOT_AUTHORIZED);
        assert!(vector::length(&recipients) == vector::length(&allocates), ENOT_VALI_INPUT);
        add_ido_round_claimers_spore(&mut sales_config.ido_round, recipients, allocates);
    }

    inline fun add_ido_round_claimers_spore(
        round_config: &mut ConfigRoud,
        recipients: vector<address>,
        allocates: vector<u64>,
    ) {
        vector::zip(recipients, allocates, |recipient, allocate|{
            round_config.total_bought = round_config.total_bought + allocate;
            smart_table::upsert(
                &mut round_config.claimers_spores,
                recipient,
                Claimer {
                    allocate,
                    claimed: 0,
                    is_refund: false,
                }
            );
        });
        event::emit(AddSporeClaimerEvent {
            claimers: recipients,
            amount: allocates,
            time_stamp: timestamp::now_seconds(),
        });
    }

    public entry fun add_ido_claimers_cell(
        operator: &signer,
        recipients: vector<address>,
        allocates: vector<u64>,
    ) acquires Sales {
        let sales_config = get_sales_config();
        assert!(!sales_config.paused, ENOT_RUNNING);
        assert!(signer::address_of(operator) == package_manager::operator(), ENOT_AUTHORIZED);
        assert!(vector::length(&recipients) == vector::length(&allocates), ENOT_VALI_INPUT);
        add_ido_round_claimers_cell(&mut sales_config.ido_round, recipients, allocates);
    }

    inline fun add_ido_round_claimers_cell(
        round_config: &mut ConfigRoud,
        recipients: vector<address>,
        allocates: vector<u64>,
    ) {
        vector::zip(recipients, allocates, |recipient, allocate|{
            round_config.total_bought = round_config.total_bought + allocate;
            smart_table::upsert(
                &mut round_config.claimers_cell,
                recipient,
                Claimer {
                    allocate,
                    claimed: 0,
                    is_refund: false,
                }
            );
        });
        event::emit(AddCellClaimerEvent {
            claimers: recipients,
            amount: allocates,
            time_stamp: timestamp::now_seconds(),
        });
    }

    inline fun get_claimers_info(claimer: address, round_config: &mut ConfigRoud): &mut Claimer {
        smart_table::borrow_mut(&mut round_config.claimers, claimer)
    }

    inline fun get_claimers_spore_info(claimer: address, round_config: &mut ConfigRoud): &mut Claimer {
        smart_table::borrow_mut(&mut round_config.claimers_spores, claimer)
    }

    inline fun get_claimers_cell_info(claimer: address, round_config: &mut ConfigRoud): &mut Claimer {
        smart_table::borrow_mut(&mut round_config.claimers_cell, claimer)
    }

    inline fun get_sales_config(): &mut Sales {
        borrow_global_mut<Sales>(claim_sale())
    }

    #[test_only]
    friend movegpt::test_claim_sale;
}