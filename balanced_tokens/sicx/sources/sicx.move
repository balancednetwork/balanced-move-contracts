module sicx::sicx {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::url;

    public struct SICX has drop {}


    fun init(witness: SICX, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<SICX>(
            witness, 
            9, 
            b"sICX", 
            b"Staked ICX", 
            b"Staked ICX tokens", 
            option::some(url::new_unsafe_from_bytes(b"https://raw.githubusercontent.com/balancednetwork/icons/refs/heads/main/tokens/sicx.png")),
            ctx
        );

        transfer::public_transfer(treasury_cap, ctx.sender());
        
        transfer::public_freeze_object(metadata);
    }

    public fun mint(treasury_cap: &mut TreasuryCap<SICX>, to: address, amount: u64,  ctx: &mut TxContext){
        coin::mint_and_transfer(treasury_cap,  amount, to, ctx);
    }

    public fun burn(treasury_cap: &mut TreasuryCap<SICX>, token: Coin<SICX>){
        coin::burn(treasury_cap, token);
    }


    #[test_only]
    /// Wrapper of module initializer for testing
    public fun init_test(ctx: &mut TxContext) {
        init(SICX {}, ctx)
    }

}
