#[test_only]
module movegpt::test_buy {
    use std::signer;
    use std::string;
    use std::string::String;
    use aptos_std::ed25519::{signature_verify_strict, new_signature_from_bytes, new_unvalidated_public_key_from_bytes};
    use aptos_std::string_utils;
    use aptos_std::type_info;
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin::AptosCoin;
    use movegpt::buy;
    use movegpt::test_helper::mint_apt;
    use movegpt::test_helper;
    use movegpt::buy::{regist_campaign_entry, buy, deactive_campaign_entry, set_treasury_entry,
        add_accepted_token
    };
    const ADMIN_PUBKEY: vector<u8> = vector[150,188,131,91,119,99,191,208,28,132,160,207,131,190,133,249,5,78,37,156,113,67,65,28,225,252,177,237,131,239,132,217];
    #[test(deployer=@0xcafe,buyer=@0xcafe, oprater=@0xcafe, treasury=@0xcafe)]
    public entry fun test_e2e(deployer: &signer, oprater: &signer, treasury: &signer, buyer: &signer) {
        // setup_buy init contract
        test_helper::setup(deployer);
        buy::initialize(deployer, signer::address_of(treasury), ADMIN_PUBKEY);
        aptos_account::deposit_coins(signer::address_of(buyer), mint_apt(1000));
        // regis a campaign
        regist_campaign_entry(oprater, 1);
        let type_info = type_info::type_name<AptosCoin>();
        add_accepted_token(oprater, type_info);
        // mess full mess
        let begin_of_mess: String = string::utf8(b"APTOS\\nmessage: ");
        let amount: u64 = 1;
        let order_id: u256 = 1;
        string::append(&mut begin_of_mess, string_utils::to_string(&amount));
        string::append(&mut begin_of_mess, type_info);
        string::append(&mut begin_of_mess, string_utils::to_string(&order_id));
        string::append(&mut begin_of_mess, string_utils::to_string(&signer::address_of(buyer)));
        string::append(&mut begin_of_mess, string::utf8(b"\\nnonce: 0"));
        buy<AptosCoin>(
            buyer,
            amount,
            order_id,
            1,
            x"41f7ec062b227b3482905036cc22007c43283d87599c8d15ff7e4257da470b91291f0deb18eb05525bf439c9020d80796cccb9383a3c781c057bd44151cd5205",
            0
        );
    }

    #[test(_deployer=@0xcafe,buyer_address=@0xcafe)]
    public entry fun test_signature(_deployer: &signer, buyer_address: &signer) {
        // mess full mess
        let upk = new_unvalidated_public_key_from_bytes(ADMIN_PUBKEY);
        let begin_of_mess: String = string::utf8(b"APTOS\\nmessage: ");
        let amount: u64 = 1;
        let order_id: u256 = 1;
        let type_info = type_info::type_name<AptosCoin>();
        string::append(&mut begin_of_mess, string_utils::to_string(&amount));
        string::append(&mut begin_of_mess, type_info);
        string::append(&mut begin_of_mess, string_utils::to_string(&order_id));
        string::append(&mut begin_of_mess, string_utils::to_string(&signer::address_of(buyer_address)));
        string::append(&mut begin_of_mess, string::utf8(b"\\nnonce: 0"));
        let check = signature_verify_strict(
            &new_signature_from_bytes(x"41f7ec062b227b3482905036cc22007c43283d87599c8d15ff7e4257da470b91291f0deb18eb05525bf439c9020d80796cccb9383a3c781c057bd44151cd5205"),
    &upk,
            *string::bytes(&begin_of_mess)
        );
        assert!(check, 1);
    }

    #[test(deployer=@0xcafe, treasury=@0xcafe2)]
    #[expected_failure(abort_code = 1,location=buy)]
    public entry fun test_set_regis_campaign_fail_by_auth(deployer: &signer, treasury: &signer) {
        // setup_buy init contract
        test_helper::setup(deployer);
        buy::initialize(deployer, signer::address_of(treasury), ADMIN_PUBKEY);
        // regis a campaign
        regist_campaign_entry(treasury, 1);
    }

    #[test(deployer=@0xcafe, treasury=@0xcafe2)]
    #[expected_failure(abort_code = 1,location=buy)]
    public entry fun test_set_deactive_campaign_fail_by_auth(deployer: &signer, treasury: &signer) {
        // setup_buy init contract
        test_helper::setup(deployer);
        buy::initialize(deployer, signer::address_of(treasury), ADMIN_PUBKEY);
        // regis a campaign
        deactive_campaign_entry(treasury, 1);
    }

    #[test(deployer=@0xcafe, treasury=@0xcafe2)]
    #[expected_failure(abort_code = 1,location=buy)]
    public entry fun test_set_treasury_fail_by_auth(deployer: &signer, treasury: &signer) {
        // setup_buy init contract
        test_helper::setup(deployer);
        buy::initialize(deployer, signer::address_of(treasury), ADMIN_PUBKEY);
        // regis a campaign
        set_treasury_entry(treasury, signer::address_of(treasury));
    }

    #[test(deployer=@0xcafe,buyer=@0xcafe, oprater=@0xcafe, treasury=@0xcafe)]
    #[expected_failure(abort_code = 3,location=buy)]
    public entry fun test_buy_with_exist_orderid_fail_by_auth(deployer: &signer, oprater: &signer, treasury: &signer, buyer: &signer) {
        // setup_buy init contract
        test_helper::setup(deployer);
        buy::initialize(deployer, signer::address_of(treasury), ADMIN_PUBKEY);
        aptos_account::deposit_coins(signer::address_of(buyer), mint_apt(1000));
        // regis a campaign
        regist_campaign_entry(oprater, 1);
        let type_info = type_info::type_name<AptosCoin>();
        add_accepted_token(oprater, type_info);
        // mess full mess
        let begin_of_mess: String = string::utf8(b"APTOS\\nmessage: ");
        let amount: u64 = 1;
        let order_id: u256 = 1;
        string::append(&mut begin_of_mess, string_utils::to_string(&amount));
        string::append(&mut begin_of_mess, type_info);
        string::append(&mut begin_of_mess, string_utils::to_string(&order_id));
        string::append(&mut begin_of_mess, string_utils::to_string(&signer::address_of(buyer)));
        string::append(&mut begin_of_mess, string::utf8(b"\\nnonce: 0"));
       buy<AptosCoin>(
            buyer,
            amount,
            order_id,
            1,
            x"41f7ec062b227b3482905036cc22007c43283d87599c8d15ff7e4257da470b91291f0deb18eb05525bf439c9020d80796cccb9383a3c781c057bd44151cd5205",
           0
        );

       buy<AptosCoin>(
            buyer,
            amount,
            order_id,
            1,
            x"41f7ec062b227b3482905036cc22007c43283d87599c8d15ff7e4257da470b91291f0deb18eb05525bf439c9020d80796cccb9383a3c781c057bd44151cd5205",
           0
        );
    }

    #[test(deployer=@0xcafe,buyer=@0xcafe, oprater=@0xcafe, treasury=@0xcafe)]
    #[expected_failure(abort_code = 5,location=buy)]
    public entry fun test_buy_with_not_accepted_token_fail_by_auth(deployer: &signer, oprater: &signer, treasury: &signer, buyer: &signer) {
        // setup_buy init contract
        test_helper::setup(deployer);
        buy::initialize(deployer, signer::address_of(treasury), ADMIN_PUBKEY);
        aptos_account::deposit_coins(signer::address_of(buyer), mint_apt(1000));
        // regis a campaign
        regist_campaign_entry(oprater, 1);
        // mess full mess
        let begin_of_mess: String = string::utf8(b"APTOS\\nmessage: ");
        let amount: u64 = 1;
        let order_id: u256 = 1;
        let type_info = type_info::type_name<AptosCoin>();
        string::append(&mut begin_of_mess, string_utils::to_string(&amount));
        string::append(&mut begin_of_mess, type_info);
        string::append(&mut begin_of_mess, string_utils::to_string(&order_id));
        string::append(&mut begin_of_mess, string_utils::to_string(&signer::address_of(buyer)));
        string::append(&mut begin_of_mess, string::utf8(b"\\nnonce: 0"));
       buy<AptosCoin>(
            buyer,
            amount,
            order_id,
            1,
            x"41f7ec062b227b3482905036cc22007c43283d87599c8d15ff7e4257da470b91291f0deb18eb05525bf439c9020d80796cccb9383a3c781c057bd44151cd5205",
           0
        );
    }
}