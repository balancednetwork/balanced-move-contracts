module balanced_dollar::balanced_dollar {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::url;

    public struct BALANCED_DOLLAR has drop {}


    fun init(witness: BALANCED_DOLLAR, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<BALANCED_DOLLAR>(
            witness, 
            9, 
            b"bnUSD", 
            b"Balanced Dollar", 
            b"A stable coin issued by Balanced", 
            option::some(url::new_unsafe_from_bytes(b"https://raw.githubusercontent.com/balancednetwork/assets/master/blockchains/icon/assets/cx88fd7df7ddff82f7cc735c871dc519838cb235bb/logo.png")),
            ctx
        );

        transfer::public_transfer(treasury_cap, ctx.sender());
        
        transfer::public_freeze_object(metadata);
    }

    public fun mint(treasury_cap: &mut TreasuryCap<BALANCED_DOLLAR>, to: address, amount: u64,  ctx: &mut TxContext){
        coin::mint_and_transfer(treasury_cap,  amount, to, ctx);
    }

    public fun burn(treasury_cap: &mut TreasuryCap<BALANCED_DOLLAR>, token: Coin<BALANCED_DOLLAR>){
        coin::burn(treasury_cap, token);
    }


    #[test_only]
    /// Wrapper of module initializer for testing
    public fun init_test(ctx: &mut TxContext) {
        init(BALANCED_DOLLAR {}, ctx)
    }

}
