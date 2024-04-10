module movegpt::voting_escrow {
    use std::option;
    use std::signer;
    use std::string;
    use aptos_std::string_utils;
    use aptos_framework::aptos_account;
    use aptos_framework::coin;
    use aptos_framework::coin::{Coin};
    use aptos_framework::event;
    use aptos_framework::object;
    use aptos_framework::object::{Object, TransferRef, ExtendRef};
    use aptos_token_objects::collection;
    use aptos_token_objects::token::BurnRef as TokenBurnRef;
    use aptos_token_objects::royalty::Royalty;
    use aptos_token_objects::token;
    use movegpt::movegpt_token;
    use movegpt::movegpt_token::MovegptCoin;
    use movegpt::epoch;
    use movegpt::package_manager;

    friend movegpt::airdrop;
    friend movegpt::vesting;
    friend movegpt::claim_sale;

    const MIN_LOCKUP_EPOCHS: u64 = 2;
    // 2 weeks
    const MAX_LOCKUP_EPOCHS: u64 = 120;
    // 2 years (52 weeks = 1 year)
    const LOCKUP_EPOCHS_FOR_VOTINGPOWER: u64 = 104;
    // 2 year
    const YEAR_LOCKUP_EPOCHS: u64 = 52; // 1 year

    /// ENOT AUTHORIZED
    const ENOT_AUTHORIZED: u64 = 1;
    /// EINVALID_AMOUNT
    const EINVALID_AMOUNT: u64 = 2;
    /// ELOCKUP_TOO_SHORT
    const ELOCKUP_TOO_SHORT: u64 = 3;
    /// ELOCKUP_TOO_LONG
    const ELOCKUP_TOO_LONG: u64 = 4;
    /// ELOCKUP_HAS_NOT_EXPIRED
    const ELOCKUP_HAS_NOT_EXPIRED: u64 = 5;
    /// ENOT_VE_TOKEN_OWNER
    const ENOT_VE_TOKEN_OWNER: u64 = 6;
    /// ELOCKUP_MUST_BE_EXTENDED
    const ELOCKUP_MUST_BE_EXTENDED: u64 = 7;
    /// ELOCKUP_EXPIRED
    const ELOCKUP_EXPIRED: u64 = 8;

    /// COLLECTION_NAME
    const COLLECTION_NAME: vector<u8> = b"MoveGPT veNFT";
    /// COLLECTION_DESC
    const COLLECTION_DESC: vector<u8> = b"MoveGPT veNFT";
    /// COLLECTION_NAME
    const TOKEN_NAME: vector<u8> = b"MoveGPT veNFT";
    /// COLLECTION_DESC
    const TOKEN_DESC: vector<u8> = b"MoveGPT veNFT";
    /// MGPT_URI
    const MOVEGPT_URI: vector<u8> = b"https://api-lp.movegpt.io/api/ve-nft/";

    struct VeMoveGptToken has key {
        extend_ref: ExtendRef,
        locked_amount: u64,
        end_epoch: u64,
    }

    struct VeMoveGptTokenRefs has key {
        burn_ref: TokenBurnRef,
        transfer_ref: TransferRef,
    }

    struct VotingEscrow has key {
        store: Coin<MovegptCoin>,
    }

    #[event]
    struct ExtendLockupEvent has drop, store {
        owner: address,
        old_lockup_end_epoch: u64,
        new_lockup_end_epoch: u64,
        ve_token: Object<VeMoveGptToken>
    }

    #[event]
    struct CreateLockEvent has drop, store {
        owner: address,
        amount: u64,
        lockup_end_epoch: u64,
        ve_token: Object<VeMoveGptToken>
    }

    #[event]
    struct IncreaseAmountEvent has drop, store {
        owner: address,
        old_amount: u64,
        new_amount: u64,
        ve_token: Object<VeMoveGptToken>
    }

    #[event]
    struct WithdrawEvent has drop, store {
        owner: address,
        amount: u64,
        ve_token: Object<VeMoveGptToken>
    }

    #[view]
    public fun get_voting_power_at_epoch(nft: Object<VeMoveGptToken>, epoch: u64): u64 acquires VeMoveGptToken {
        let token_data = safe_ve_token(&nft);
        let (locked_amount, lockup_end_epoch) = (token_data.locked_amount, token_data.end_epoch);
        if (lockup_end_epoch <= epoch) {
            0
        } else {
            locked_amount * (lockup_end_epoch - epoch) / MAX_LOCKUP_EPOCHS
        }
    }

    #[view]
    public fun get_ve_token_lock_amount(nft: Object<VeMoveGptToken>): u64 acquires VeMoveGptToken {
        safe_ve_token(&nft).locked_amount
    }

    #[view]
    public fun get_ve_token_lock_end_epoch(nft: Object<VeMoveGptToken>): u64 acquires VeMoveGptToken {
        safe_ve_token(&nft).end_epoch
    }

    public entry fun initialize(admin: &signer) {
        assert!(signer::address_of(admin) == package_manager::operator(), ENOT_AUTHORIZED);
        if (is_initialized()) {
            return
        };
        create_vemgpt_collection();
    }

    /// create a new VeMGPT Collection
    inline fun create_vemgpt_collection() {
        let ve_movegpt = &collection::create_unlimited_collection(
            &package_manager::get_signer(),
            string::utf8(COLLECTION_DESC),
            string::utf8(COLLECTION_NAME),
            option::none<Royalty>(),
            string::utf8(MOVEGPT_URI),
        );
        let ve_token_signer = &object::generate_signer(ve_movegpt);
        move_to(ve_token_signer, VeMoveGptTokenRefs {
            burn_ref: token::generate_burn_ref(ve_movegpt),
            transfer_ref: object::generate_transfer_ref(ve_movegpt),
        });
        package_manager::add_address(string::utf8(COLLECTION_NAME), signer::address_of(ve_token_signer));
    }

    #[view]
    public fun is_initialized(): bool {
        package_manager::address_exists(string::utf8(COLLECTION_NAME))
    }

    /// create a new VeMGPT NFT
    public(friend) fun create_lock(
        recipient: address,
        coin_lock: Coin<MovegptCoin>,
        end_epoch_duration: u64
    ): Object<VeMoveGptToken> {
        let coin_amount = coin::value(&coin_lock);
        assert!(coin_amount > 0, EINVALID_AMOUNT);
        validate_lockup_epochs(end_epoch_duration);
        let movegpt_signer = &package_manager::get_signer();
        let ve_mgpt_constructor = &token::create_from_account(
            movegpt_signer,
            string::utf8(COLLECTION_NAME),
            string::utf8(COLLECTION_DESC),
            string::utf8(COLLECTION_NAME),
            option::none<Royalty>(),
            string::utf8(MOVEGPT_URI),
        );
        let extern_ref = object::generate_extend_ref(ve_mgpt_constructor);
        let ve_token_signer = &object::generate_signer(ve_mgpt_constructor);
        let token_data = VeMoveGptToken {
            extend_ref: extern_ref,
            locked_amount: coin_amount,
            end_epoch: epoch::now() + end_epoch_duration,
        };
        move_to(ve_token_signer, token_data);
        move_to(ve_token_signer, VeMoveGptTokenRefs {
            burn_ref: token::generate_burn_ref(ve_mgpt_constructor),
            transfer_ref: object::generate_transfer_ref(ve_mgpt_constructor),
        });
        let mutator_ref = token::generate_mutator_ref(ve_mgpt_constructor);
        let nft_object: Object<VeMoveGptToken> = object::object_from_constructor_ref(ve_mgpt_constructor);
        let nft_object_address = object::object_address(&nft_object);
        aptos_account::deposit_coins<MovegptCoin>(nft_object_address, coin_lock);
        movegpt_token::freeze_coin_store(nft_object_address);
        object::transfer(movegpt_signer, nft_object, recipient);
        let base_uri = string::utf8(MOVEGPT_URI);
        string::append(&mut base_uri, string_utils::to_string(&object::object_address(&nft_object)));
        token::set_uri(&mutator_ref, base_uri);
        event::emit(
            CreateLockEvent {
                owner: recipient, amount: coin_amount, lockup_end_epoch: epoch::now(
                ) + end_epoch_duration, ve_token: nft_object
            }
        );

        nft_object
    }

    /// create a new VeMGPT NFT
    public(friend) fun create_lock_with_start_lock_time(
        recipient: address,
        coin_lock: Coin<MovegptCoin>,
        end_epoch_duration: u64,
        start_time: u64
    ): Object<VeMoveGptToken> {
        let coin_amount = coin::value(&coin_lock);
        assert!(coin_amount > 0, EINVALID_AMOUNT);
        validate_lockup_epochs(end_epoch_duration);
        let movegpt_signer = &package_manager::get_signer();
        let ve_mgpt_constructor = &token::create_from_account(
            movegpt_signer,
            string::utf8(COLLECTION_NAME),
            string::utf8(COLLECTION_DESC),
            string::utf8(COLLECTION_NAME),
            option::none<Royalty>(),
            string::utf8(MOVEGPT_URI),
        );
        let extern_ref = object::generate_extend_ref(ve_mgpt_constructor);
        let ve_token_signer = &object::generate_signer(ve_mgpt_constructor);
        let token_data = VeMoveGptToken {
            extend_ref: extern_ref,
            locked_amount: coin_amount,
            end_epoch: epoch::to_epoch(start_time) + end_epoch_duration,
        };
        move_to(ve_token_signer, token_data);
        move_to(ve_token_signer, VeMoveGptTokenRefs {
            burn_ref: token::generate_burn_ref(ve_mgpt_constructor),
            transfer_ref: object::generate_transfer_ref(ve_mgpt_constructor),
        });
        let mutator_ref = token::generate_mutator_ref(ve_mgpt_constructor);
        let nft_object: Object<VeMoveGptToken> = object::object_from_constructor_ref(ve_mgpt_constructor);
        let nft_object_address = object::object_address(&nft_object);
        aptos_account::deposit_coins<MovegptCoin>(nft_object_address, coin_lock);
        movegpt_token::freeze_coin_store(nft_object_address);
        object::transfer(movegpt_signer, nft_object, recipient);
        let base_uri = string::utf8(MOVEGPT_URI);
        string::append(&mut base_uri, string_utils::to_string(&object::object_address(&nft_object)));
        token::set_uri(&mutator_ref, base_uri);
        event::emit(
            CreateLockEvent {
                owner: recipient,
                amount: coin_amount,
                lockup_end_epoch: epoch::to_epoch(start_time) + end_epoch_duration,
                ve_token: nft_object
            }
        );

        nft_object
    }

    /// Can only be called by owner toithdraw $MGPT from an expired veMGPT NFT.
    public fun withdraw(
        owner: &signer,
        ve_token: Object<VeMoveGptToken>,
    ) acquires VeMoveGptToken, VeMoveGptTokenRefs {
        let VeMoveGptToken { extend_ref: _, locked_amount: _, end_epoch } =
            owner_only_destruct_token(owner, ve_token);

        // This would fail if the lockup has not expired yet.
        assert!(end_epoch <= epoch::now(), ELOCKUP_HAS_NOT_EXPIRED);
        // Withdraw doesn't need to update total voting power because this lockup should not have any effect on any
        // epochs, including the current one, as it has already expired.
    }

    /// Merge two veMGPT nfts into one. The `from` token will be burned and the `to` token will be updated with the
    /// combined locked up $MGPT.
    public entry fun merge(
        owner: &signer,
        from: Object<VeMoveGptToken>,
        to: Object<VeMoveGptToken>,
    ) acquires VeMoveGptToken, VeMoveGptTokenRefs {
        // Destroy the `from` veMGPT nft.
        let VeMoveGptToken {
            extend_ref: _,
            locked_amount: from_amount,
            end_epoch: from_end_epoch,
        } = owner_only_destruct_token(owner, from);
        let to_token_data = owner_only_mut_ve_token(owner, to);
        let to_amount = to_token_data.locked_amount;
        let combined_amount = from_amount + to_amount;
        event::emit(
            IncreaseAmountEvent {
                owner: signer::address_of(owner),
                old_amount: to_amount,
                new_amount: combined_amount,
                ve_token: to
            },
        );

        to_token_data.locked_amount = combined_amount;
        // Update `to`'s lockup duration if `from`'s is longer and update manifested total supply accordingly.
        let to_end_epoch = to_token_data.end_epoch;
        if (from_end_epoch > to_end_epoch) {
            to_token_data.end_epoch = from_end_epoch;
        };
    }

    public entry fun increase_amount_entry(
        owner: &signer,
        ve_token: Object<VeMoveGptToken>,
        amount: u64,
    ) acquires VeMoveGptToken {
        let coin = coin::withdraw<MovegptCoin>(owner, amount);
        increase_amount(owner, ve_token, coin);
    }

    public fun increase_amount(
        owner: &signer,
        ve_token: Object<VeMoveGptToken>,
        coin: Coin<MovegptCoin>,
    ) acquires VeMoveGptToken {
        assert!(object::is_owner(ve_token, signer::address_of(owner)), ENOT_VE_TOKEN_OWNER);
        increase_amount_internal(ve_token, coin);
    }

    inline fun increase_amount_internal(
        ve_token: Object<VeMoveGptToken>,
        coin: Coin<MovegptCoin>,
    ) acquires VeMoveGptToken {
        let ve_token_data = unchecked_mut_ve_token(&ve_token);
        assert!(ve_token_data.end_epoch > epoch::now(), ELOCKUP_EXPIRED);
        let amount = coin::value(&coin);
        assert!(amount > 0, EINVALID_AMOUNT);
        let old_amount = ve_token_data.locked_amount;
        let new_amount = old_amount + amount;
        ve_token_data.locked_amount = new_amount;
        let ve_token_address = object::object_address(&ve_token);
        movegpt_token::unfreeze_coin_store(ve_token_address);
        coin::deposit(ve_token_address, coin);
        movegpt_token::freeze_coin_store(ve_token_address);
        event::emit(
            IncreaseAmountEvent { owner: object::owner(ve_token), old_amount, new_amount, ve_token },
        );
    }

    public entry fun extend_lockup(
        owner: &signer,
        ve_token: Object<VeMoveGptToken>,
        lockup_epochs_from_now: u64,
    ) acquires VeMoveGptToken {
        // Validate lockup duration.
        validate_lockup_epochs(lockup_epochs_from_now);
        // Extend lockup duration.
        let ve_token_data = owner_only_mut_ve_token(owner, ve_token);
        let old_lockup_end_epoch = ve_token_data.end_epoch;
        let new_lockup_end_epoch = epoch::now() + lockup_epochs_from_now;
        // New lockup end epoch must be greater than the old one.
        assert!(new_lockup_end_epoch > old_lockup_end_epoch, ELOCKUP_MUST_BE_EXTENDED);
        ve_token_data.end_epoch = new_lockup_end_epoch;
        event::emit(
            ExtendLockupEvent {
                owner: signer::address_of(
                    owner
                ), old_lockup_end_epoch, new_lockup_end_epoch, ve_token
            },
        );
    }

    inline fun owner_only_destruct_token(
        owner: &signer,
        ve_token: Object<VeMoveGptToken>,
    ): VeMoveGptToken acquires VeMoveGptToken {
        assert!(object::is_owner(ve_token, signer::address_of(owner)), ENOT_VE_TOKEN_OWNER);
        let ve_token_addr = object::object_address(&ve_token);
        let token_data = move_from<VeMoveGptToken>(ve_token_addr);
        let nft_signer = object::generate_signer_for_extending(&token_data.extend_ref);
        let nft_address = object::object_address(&ve_token);
        movegpt_token::unfreeze_coin_store(nft_address);
        aptos_account::transfer_coins<MovegptCoin>(
            &nft_signer,
            signer::address_of(owner),
            coin::balance<MovegptCoin>(nft_address)
        );
        let VeMoveGptTokenRefs { burn_ref, transfer_ref: _ } = move_from<VeMoveGptTokenRefs>(ve_token_addr);
        token::burn(burn_ref);
        token_data
    }

    inline fun owner_only_mut_ve_token(
        owner: &signer,
        ve_token: Object<VeMoveGptToken>,
    ): &mut VeMoveGptToken acquires VeMoveGptToken {
        assert!(object::is_owner(ve_token, signer::address_of(owner)), ENOT_VE_TOKEN_OWNER);
        unchecked_mut_ve_token(&ve_token)
    }

    inline fun safe_ve_token(ve_token: &Object<VeMoveGptToken>): &VeMoveGptToken acquires VeMoveGptToken {
        borrow_global<VeMoveGptToken>(object::object_address(ve_token))
    }

    inline fun validate_lockup_epochs(lockup_epochs: u64) {
        assert!(lockup_epochs >= MIN_LOCKUP_EPOCHS, ELOCKUP_TOO_SHORT);
        assert!(lockup_epochs <= MAX_LOCKUP_EPOCHS, ELOCKUP_TOO_LONG);
    }

    inline fun unchecked_mut_ve_token(ve_token: &Object<VeMoveGptToken>): &mut VeMoveGptToken acquires VeMoveGptToken {
        borrow_global_mut<VeMoveGptToken>(object::object_address(ve_token))
    }

    #[test_only]
    friend movegpt::test_voting_escrow;
}