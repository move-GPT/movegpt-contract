module movegpt::epoch {
    use aptos_framework::timestamp;

    #[view]
    public fun now(): u64 {
        to_epoch(timestamp::now_seconds())
    }

    public inline fun duration(): u64 {
        604800
    }

    // Convert timestamp to epoch
    public inline fun to_epoch(timestamp_secs: u64): u64 {
        timestamp_secs / duration()
    }

    // Convert epoch to seconds
    public inline fun to_seconds(epoch: u64): u64 {
        epoch * duration()
    }

    #[test_only]
    public fun fast_forward(epochs: u64) {
        aptos_framework::timestamp::fast_forward_seconds(epochs * duration());
    }
}
