module movegpt::buy {
    use std::signer;
    use std::string;
    use std::string::String;
    use aptos_std::ed25519::{signature_verify_strict, new_signature_from_bytes, new_unvalidated_public_key_from_bytes};
    use aptos_std::smart_table;
    use aptos_std::smart_table::SmartTable;
    use aptos_std::string_utils;
    use aptos_std::type_info;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::timestamp;

    /// Not authorized to perform this action
    const ENOT_AUTHORIZED: u64 = 1;
    /// Not active campaign
    const ENOT_CAMPAIGN_NOT_ACTIVE: u64 = 2;
    /// Not order already exist
    const ENOT_ORDER_ALREADY_EXIT: u64 = 3;
    /// Not vali signature
    const ENOT_INVALI_SIGNATURE: u64 = 4;
    /// Not accepted token
    const ENOT_ACCEPTED_TOKEN: u64 = 5;

    struct BuyOrder has key, store, copy, drop {
        amount: u64,
        payment_token: String,
        buyer: address,
        campaign_id: u256,
    }

    struct BuyOrders has key, store {
        operator: address,
        treasury: address,
        admin_pubkey: vector<u8>,
        orders: SmartTable<u256, BuyOrder>,
        campaigns: SmartTable<u256, bool>,
        usedOrders: SmartTable<u256, bool>,
        accepted_token: SmartTable<String, bool>
    }

    #[event]
    struct BuyEvent has drop, store {
        buyer_address: address,
        token_payment: String,
        order_id: u256,
        campaign_id: u256,
        amount: u64,
        timestamp: u64,
    }


    public entry fun initialize(admin: &signer, operator: address, treasury: address, admin_pubKey: vector<u8>) {
        move_to(admin, BuyOrders {
            operator,
            treasury,
            admin_pubkey: admin_pubKey,
            orders: smart_table::new(),
            campaigns: smart_table::new(),
            usedOrders: smart_table::new(),
            accepted_token: smart_table::new(),
        });
    }

    public entry fun buy_entry<CoinType>(buyer: &signer, amount: u64, order_id: u256,campaign_id: u256, signature: vector<u8>) acquires BuyOrders {
        buy<CoinType>(buyer, amount, order_id, campaign_id, signature);
    }

    public entry fun regist_campaign_entry(operator: &signer, campaign_id: u256) acquires BuyOrders {
        setCampaign(operator, campaign_id, true);
    }

    public entry fun deactive_campaign_entry(operator: &signer, campaign_id: u256) acquires BuyOrders {
        setCampaign(operator, campaign_id, false);
    }

    public entry fun set_treasury_entry(operator: &signer, treasury: address) acquires BuyOrders {
        let buy_orders = get_buy_orders_mut();
        assert!(signer::address_of(operator) == buy_orders.operator, ENOT_AUTHORIZED);
        buy_orders.treasury = treasury;
    }

    public entry fun set_operator_entry(deployer: &signer, new_operator: address) acquires BuyOrders {
        assert!(
            signer::address_of(deployer) == @deployer, ENOT_AUTHORIZED
        );
        get_buy_orders_mut().operator = new_operator;
    }

    public entry fun set_admin_pubkey_entry(operator: &signer, new_admin_pub: vector<u8>) acquires BuyOrders {
        let buy_orders = get_buy_orders_mut();
        assert!(
            signer::address_of(operator) == buy_orders.operator, ENOT_AUTHORIZED
        );
        buy_orders.admin_pubkey = new_admin_pub;
    }

    public entry fun add_accepted_token(operator: &signer, token: String) acquires BuyOrders {
        let buy_orders = get_buy_orders_mut();
        assert!(
            signer::address_of(operator) == buy_orders.operator, ENOT_AUTHORIZED
        );
        smart_table::upsert(
            &mut buy_orders.accepted_token,
            token,
            true
        );
    }

    public entry fun deactive_accepted_token(operator: &signer, token: String) acquires BuyOrders {
        let buy_orders = get_buy_orders_mut();
        assert!(
            signer::address_of(operator) == buy_orders.operator, ENOT_AUTHORIZED
        );
        smart_table::upsert(
            &mut buy_orders.accepted_token,
            token,
            false
        );
    }

    public fun buy<CoinType>(buyer: &signer, amount: u64, order_id: u256, campaign_id: u256, signature: vector<u8>) acquires BuyOrders {
        let buyer_address = signer::address_of(buyer);
        let buy_orders = get_buy_orders_mut();
        assert!(order_is_exist(order_id,buy_orders) == false, ENOT_ORDER_ALREADY_EXIT);
        let coin = coin::withdraw<CoinType>(buyer, amount);
        let type_info = type_info::type_name<CoinType>();
        assert!(buy_token_is_accepted(type_info,buy_orders), ENOT_ACCEPTED_TOKEN);
        coin::deposit( buy_orders.treasury, coin);
        let begin_of_mess: String = string::utf8(b"APTOS\\nmessage: ");
        string::append(&mut begin_of_mess, string_utils::to_string(&amount));
        string::append(&mut begin_of_mess, type_info);
        string::append(&mut begin_of_mess, string_utils::to_string(&order_id));
        string::append(&mut begin_of_mess, string_utils::to_string(&buyer_address));
        string::append(&mut begin_of_mess, string::utf8(b"\\nnonce: 0"));
        let upk = new_unvalidated_public_key_from_bytes(buy_orders.admin_pubkey);
        let check = signature_verify_strict(
            &new_signature_from_bytes(signature),
            &upk,
            *string::bytes(&begin_of_mess)
        );
        assert!(check, ENOT_INVALI_SIGNATURE);
        smart_table::upsert(
            &mut buy_orders.orders,
            order_id,
            BuyOrder {
                amount,
                payment_token: type_info,
                buyer: buyer_address,
                campaign_id
            }
        );
        let current_time: u64 = timestamp::now_seconds();
        event::emit(BuyEvent {
            buyer_address,
            token_payment: type_info,
            order_id,
            campaign_id,
            amount,
            timestamp: current_time,
        })
    }

    fun setCampaign(operator: &signer, campaign_id: u256, is_active: bool) acquires BuyOrders {
        let buy_orders = get_buy_orders_mut();
        assert!(signer::address_of(operator) == buy_orders.operator, ENOT_AUTHORIZED);
        smart_table::upsert(
            &mut buy_orders.campaigns,
            campaign_id,
            is_active
        );
    }

    inline fun get_campaign_status(campaign_id: u256, orders: &mut BuyOrders): bool {
        *smart_table::borrow_with_default(&orders.campaigns, campaign_id, &false)
    }

    inline fun order_is_exist(order_id: u256, orders: &mut BuyOrders): bool {
        smart_table::contains(&orders.orders, order_id)
    }

    inline fun buy_token_is_accepted(token_name: String, orders: &mut BuyOrders): bool {
        *smart_table::borrow_with_default(&orders.accepted_token, token_name, &false)
    }

    inline fun get_buy_orders_mut(): &mut BuyOrders acquires BuyOrders  {
        borrow_global_mut<BuyOrders>(@deployer)
    }

}

