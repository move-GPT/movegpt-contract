#[test_only]
module movegpt::test_buy {
    use std::signer;
    use std::string;
    use std::string::String;
    use aptos_std::debug::print;
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
    const ADMIN_PUBKEY: vector<u8> = x"8b7d999c79a6e16c9cece5ac113b37f3cd42b36a7719bf72cbb94698ff07b843";
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
        let amount: u64 = 100000000;
        let order_id: u256 = 189989083012735174466550430892616457032000000000000000000000001712752252840;
        let nonce: u64 =  157;
        string::append(&mut begin_of_mess, string_utils::to_string(&amount));
        string::append(&mut begin_of_mess, string::utf8(b"0x1::aptos_coin::AptosCoin"));
        string::append(&mut begin_of_mess, string_utils::to_string(&order_id));
        string::append(&mut begin_of_mess, string::utf8(b"@0x44e5f4e8e2d3a65f539252ea1be440367d3f17fbccb95bb72803d02fefc534db"));
        string::append(&mut begin_of_mess, string::utf8(b"\\nnonce: "));
        string::append(&mut begin_of_mess, string_utils::to_string(&nonce));
        print(&begin_of_mess);
        buy<AptosCoin>(
            buyer,
            amount,
            order_id,
            00000000000000000000000000,
            x"40e5ff40a8b502202d9a97166ddb6484acebbb0763e83e97647c12f9ccc98130717535b86a4a7e9b5ec9500953c20f00443ef56919365ea83b032463b9c16906",
            0
        );
    }

    #[test(_deployer=@0xcafe,buyer_address=@0xcafe)]
    public entry fun test_signature(_deployer: &signer, buyer_address: &signer) {
        // mess full mess
        let upk = new_unvalidated_public_key_from_bytes(ADMIN_PUBKEY);
        let begin_of_mess: String = string::utf8(b"APTOS\\nmessage: ");
        let order_id: u256 = 189989083012735174466550430892616457032000000000000000000000001712752252840;
        let nonce: u64 = 157;
        string::append(&mut begin_of_mess, string_utils::to_string(&100000000));
        string::append(&mut begin_of_mess, string::utf8(b"0x1::aptos_coin::AptosCoin"));
        string::append(&mut begin_of_mess, string_utils::to_string(&order_id));
        string::append(&mut begin_of_mess, string::utf8(b"@0x44e5f4e8e2d3a65f539252ea1be440367d3f17fbccb95bb72803d02fefc534db"));
        string::append(&mut begin_of_mess, string::utf8(b"\\nnonce: "));
        string::append(&mut begin_of_mess, string_utils::to_string(&nonce));
        let check = signature_verify_strict(
            &new_signature_from_bytes(x"40e5ff40a8b502202d9a97166ddb6484acebbb0763e83e97647c12f9ccc98130717535b86a4a7e9b5ec9500953c20f00443ef56919365ea83b032463b9c16906"),
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