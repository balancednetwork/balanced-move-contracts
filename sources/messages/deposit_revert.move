#[allow(unused_field,unused_use,unused_const,unused_mut_parameter,unused_variable,unused_assignment)]
module balanced::deposit_revert {
    use std::string::{Self, String};
    use std::option::{some, none};
    use sui_rlp::encoder;
    use sui_rlp::decoder;

    public struct DepositRevert has drop {
        token_address: String,
        to: address,
        amount: u64
    }

    public fun encode(req:&DepositRevert, method: vector<u8>):vector<u8>{
        let mut list=vector::empty<vector<u8>>();
        vector::push_back(&mut list, encoder::encode(&method));
        vector::push_back(&mut list,encoder::encode_string(&req.token_address));
        vector::push_back(&mut list,encoder::encode_address(&req.to));
        vector::push_back(&mut list,encoder::encode_u64(req.amount));

        let encoded = encoder::encode_list(&list,false);
        encoded
    }

    public fun decode(bytes:&vector<u8>): DepositRevert {
        let decoded=decoder::decode_list(bytes);
        let token_address = decoder::decode_string(vector::borrow(&decoded, 1));
        let to = decoder::decode_address(vector::borrow(&decoded, 2));
        let amount = decoder::decode_u64(vector::borrow(&decoded, 3));
        let req= wrap_deposit_revert (
            token_address,
            to,
            amount
        );
        req
    }

     public fun wrap_deposit_revert(token_address: String, to: address, amount: u64): DepositRevert {
        let deposit_revert = DepositRevert {
            token_address: token_address,
            to: to,
            amount:amount
        };
        deposit_revert
    }

    public fun token_address(deposit_revert: &DepositRevert): String{
        deposit_revert.token_address
    }

    public fun to(deposit_revert: &DepositRevert): address{
        deposit_revert.to
    }

    public fun amount(deposit_revert: &DepositRevert): u64{
        deposit_revert.amount
    }

}