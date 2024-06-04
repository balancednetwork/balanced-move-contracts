module balanced::balanced_dollar {
    use sui::coin::{Self, Coin, TreasuryCap};
     use sui::url;

    public struct BALANCED_DOLLAR has drop {}

    public struct AdminCap has key{
        id: UID 
    }
    
    public struct TreasuryCapCarrier<phantom BALANCED_DOLLAR> has key{
        id: UID,
        treasury_cap: TreasuryCap<BALANCED_DOLLAR>
    }


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

        transfer::share_object(TreasuryCapCarrier{
            id: object::new(ctx),
            treasury_cap: treasury_cap
        });
        
        transfer::public_freeze_object(metadata);

        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, ctx.sender());
        
    }

    public fun mint(_: &AdminCap, treasury_cap_carrier: &mut TreasuryCapCarrier<BALANCED_DOLLAR>, to: address, amount: u64,  ctx: &mut TxContext){
        coin::mint_and_transfer(get_treasury_cap_mut(treasury_cap_carrier),  amount, to, ctx);
    }

    public fun burn(treasury_cap_carrier: &mut TreasuryCapCarrier<BALANCED_DOLLAR>, token: Coin<BALANCED_DOLLAR>){
        coin::burn(get_treasury_cap_mut(treasury_cap_carrier), token);
    }

    fun get_treasury_cap_mut(treasury_cap_carrier: &mut TreasuryCapCarrier<BALANCED_DOLLAR>): &mut TreasuryCap<BALANCED_DOLLAR> {
        &mut treasury_cap_carrier.treasury_cap
    }


    #[test_only]
    public fun get_treasury_cap_for_testing<BALANCED_DOLLAR>(treasury_cap_carrier: &mut TreasuryCapCarrier<BALANCED_DOLLAR>): &mut TreasuryCap<BALANCED_DOLLAR> {
        &mut treasury_cap_carrier.treasury_cap
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun init_test(ctx: &mut TxContext) {
        init(BALANCED_DOLLAR {}, ctx)
    }

}
