module movegpt::package_manager {
    use std::signer;
    use std::string;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::code;
    use aptos_framework::resource_account;
    use aptos_std::smart_table::{Self, SmartTable};
    use std::string::String;
    use aptos_framework::object;

    friend movegpt::movegpt_token;
    friend movegpt::buy;
    friend movegpt::vesting;
    friend movegpt::claim_sale;
    friend movegpt::airdrop;
    friend movegpt::voting_escrow;

    /// Caller is not authorized.
    const ENOT_AUTHORIZED: u64 = 2;

    const PACKAGE_MANAGER_OBJECT_NAME: vector<u8> = b"PACKAGE_MANAGER";

    /// Stores permission config such as SignerCapability for controlling the resource account.
    struct PermissionConfig has key {
        /// Required to obtain the resource account signer.
        signer_cap: SignerCapability,
        /// Track the addresses created by the modules in this package.
        addresses: SmartTable<String, address>,
    }

    struct AdministrativeData has key {
        governance: address,
        operator: address,
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

    /// Create a separate vote manager object to store administrative and accounting data.
    public entry fun initialize(admin: &signer) acquires PermissionConfig {
        assert!(signer::address_of(admin) == @deployer, ENOT_AUTHORIZED);
        if (is_initialized()) {
            return
        };
        let pakage_manager_constructor_ref = &object::create_object_from_account(&get_signer());
        let pakage_manager_signer = &object::generate_signer(pakage_manager_constructor_ref);
        add_address(string::utf8(PACKAGE_MANAGER_OBJECT_NAME), signer::address_of(pakage_manager_signer));
        move_to(pakage_manager_signer, AdministrativeData {
            operator: @deployer,
            governance: @deployer,
        });
    }

    #[view]
    public fun is_initialized(): bool acquires PermissionConfig {
        address_exists(string::utf8(PACKAGE_MANAGER_OBJECT_NAME))
    }

    #[view]
    public fun package_manager_address(): address acquires PermissionConfig {
        get_address(string::utf8(PACKAGE_MANAGER_OBJECT_NAME))
    }

    #[view]
    public fun operator(): address acquires AdministrativeData, PermissionConfig {
        safe_admin_data().operator
    }

    #[view]
    public fun governance(): address acquires AdministrativeData, PermissionConfig {
        safe_admin_data().governance
    }

    public entry fun update_operator(governor: &signer, new_operator: address) acquires AdministrativeData, PermissionConfig {
        governance_only_mut_admin_data(governor).operator = new_operator;
    }

    public entry fun update_governance(
        governance: &signer,
        new_governance: address,
    ) acquires AdministrativeData, PermissionConfig {
        governance_only_mut_admin_data(governance).governance = new_governance;
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
    public entry fun upgrade(
        governance: &signer,
        package_metadata: vector<u8>,
        code: vector<vector<u8>>,
    ) acquires AdministrativeData, PermissionConfig {
        validate_governance(governance);
        code::publish_package_txn(&get_signer(), package_metadata, code);
    }

    inline fun operator_only_mut_admin_data(governor: &signer): &mut AdministrativeData acquires AdministrativeData {
        validate_operator(governor);
        unchecked_mut_admin_data()
    }

    inline fun governance_only_mut_admin_data(
        governance: &signer,
    ): &mut AdministrativeData acquires AdministrativeData {
        let administrative_data = unchecked_mut_admin_data();
        assert!(
            administrative_data.governance == signer::address_of(governance),
            ENOT_AUTHORIZED,
        );
        administrative_data
    }

    inline fun validate_operator(operator: &signer) {
        assert!(
            safe_admin_data().operator == signer::address_of(operator),
            ENOT_AUTHORIZED,
        );
    }

    inline fun validate_governance(governance: &signer) {
        assert!(
            safe_admin_data().governance == signer::address_of(governance),
            ENOT_AUTHORIZED,
        );
    }

    inline fun safe_permission_config(): &PermissionConfig acquires PermissionConfig {
        borrow_global<PermissionConfig>(@movegpt)
    }

    inline fun unchecked_mut_permission_config(): &mut PermissionConfig acquires PermissionConfig {
        borrow_global_mut<PermissionConfig>(@movegpt)
    }

    inline fun safe_admin_data(): &AdministrativeData acquires AdministrativeData {
        borrow_global<AdministrativeData>(package_manager_address())
    }

    inline fun unchecked_mut_admin_data(): &mut AdministrativeData acquires AdministrativeData {
        borrow_global_mut<AdministrativeData>(package_manager_address())
    }

    #[test_only]
    friend movegpt::test_helper;
    #[test_only]
    public fun initialize_for_test(deployer: &signer) acquires PermissionConfig {
        let deployer_addr = signer::address_of(deployer);
        if (!exists<PermissionConfig>(deployer_addr)) {
            aptos_framework::timestamp::set_time_has_started_for_testing(&account::create_signer_for_test(@0x1));

            account::create_account_for_test(deployer_addr);
            move_to(deployer, PermissionConfig {
                addresses: smart_table::new<String, address>(),
                signer_cap: account::create_test_signer_cap(deployer_addr),
            });
            // Initialize all other key modules. These calls would not fail if those modules have already been initialized.
            let pakage_manager_constructor_ref = &object::create_object_from_account(&get_signer());
            let pakage_manager_signer = &object::generate_signer(pakage_manager_constructor_ref);
            add_address(string::utf8(PACKAGE_MANAGER_OBJECT_NAME), signer::address_of(pakage_manager_signer));
            move_to(pakage_manager_signer, AdministrativeData {
                operator: @deployer,
                governance: @deployer,
            });
        };
    }
}
