module balanced_token::balanced_token {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::url;

    public struct BALANCED_TOKEN has drop {}


    fun init(witness: BALANCED_TOKEN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<BALANCED_TOKEN>(
            witness, 
            9, 
            b"BALN", 
            b"Balance Token", 
            b"A governance coin of Balanced", 
            option::some(url::new_unsafe_from_bytes(b"https://raw.githubusercontent.com/balancednetwork/icons/refs/heads/main/tokens/baln.png")),
            ctx
        );

        transfer::public_transfer(treasury_cap, ctx.sender());
        
        transfer::public_freeze_object(metadata);
    }

    public fun mint(treasury_cap: &mut TreasuryCap<BALANCED_TOKEN>, to: address, amount: u64,  ctx: &mut TxContext){
        coin::mint_and_transfer(treasury_cap,  amount, to, ctx);
    }

    public fun burn(treasury_cap: &mut TreasuryCap<BALANCED_TOKEN>, token: Coin<BALANCED_TOKEN>){
        coin::burn(treasury_cap, token);
    }


    #[test_only]
    /// Wrapper of module initializer for testing
    public fun init_test(ctx: &mut TxContext) {
        init(BALANCED_TOKEN {}, ctx)
    }

}
