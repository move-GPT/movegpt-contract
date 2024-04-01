module movegpt::package_manager {
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::code;
    use aptos_framework::resource_account;
    use aptos_std::smart_table::{Self, SmartTable};
    use std::string::String;

    friend movegpt::movegpt_token;
    friend movegpt::buy;
    friend movegpt::vesting;
    friend movegpt::claim_sale;
    friend movegpt::airdrop;
    friend movegpt::voting_escrow;


    /// Stores permission config such as SignerCapability for controlling the resource account.
    struct PermissionConfig has key {
        /// Required to obtain the resource account signer.
        signer_cap: SignerCapability,
        /// Track the addresses created by the modules in this package.
        addresses: SmartTable<String, address>,
    }

    /// Initialize PermissionConfig to establish control over the resource account.
    /// This function is invoked only when this package is deployed the first time.
    fun init_module(movegpt_signer: &signer) {
        let signer_cap = resource_account::retrieve_resource_account_cap(movegpt_signer, @deployer);
        move_to(movegpt_signer, PermissionConfig {
            addresses: smart_table::new<String, address>(),
            signer_cap,
        });
    }

    /// Can be called by friended modules to obtain the resource account signer.
    public(friend) fun get_signer(): signer acquires PermissionConfig {
        account::create_signer_with_capability(&safe_permission_config().signer_cap)
    }

    /// Can be called by friended modules to keep track of a system address.
    public(friend) fun add_address(name: String, object: address) acquires PermissionConfig {
        smart_table::add(&mut unchecked_mut_permission_config().addresses, name, object);
    }

    public fun address_exists(name: String): bool acquires PermissionConfig {
        smart_table::contains(&safe_permission_config().addresses, name)
    }

    public fun get_address(name: String): address acquires PermissionConfig {
        *smart_table::borrow(&safe_permission_config().addresses, name)
    }

    /// Can only be called by the governance to publish new modules or upgrade existing modules in this package.
    public(friend) fun upgrade(package_metadata: vector<u8>, code: vector<vector<u8>>) acquires PermissionConfig {
        code::publish_package_txn(&get_signer(), package_metadata, code);
    }

    inline fun safe_permission_config(): &PermissionConfig acquires PermissionConfig {
        borrow_global<PermissionConfig>(@movegpt)
    }

    inline fun unchecked_mut_permission_config(): &mut PermissionConfig acquires PermissionConfig {
        borrow_global_mut<PermissionConfig>(@movegpt)
    }

    #[test_only]
    friend movegpt::test_helper;

    #[test_only]
    use std::signer;

    #[test_only]
    public fun initialize_for_test(deployer: &signer) {
        let deployer_addr = signer::address_of(deployer);
        if (!exists<PermissionConfig>(deployer_addr)) {
            aptos_framework::timestamp::set_time_has_started_for_testing(&account::create_signer_for_test(@0x1));

            account::create_account_for_test(deployer_addr);
            move_to(deployer, PermissionConfig {
                addresses: smart_table::new<String, address>(),
                signer_cap: account::create_test_signer_cap(deployer_addr),
            });
        };
    }
}
