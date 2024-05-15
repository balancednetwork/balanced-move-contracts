#[allow(unused_field,unused_use,unused_const,unused_mut_parameter,unused_variable,unused_assignment)]
module balanced::withdraw_to {
    use std::string::{Self, String};
    use std::option::{some, none};
    use sui_rlp::encoder;
    use sui_rlp::decoder;

    public struct WithdrawTo has drop {
        token_address: String,
        to: String,
        amount: u64
    }

    public fun encode(req:&WithdrawTo, method: vector<u8>): vector<u8>{
        let mut list=vector::empty<vector<u8>>();
        vector::push_back(&mut list, encoder::encode(&method));
        vector::push_back(&mut list, encoder::encode_string(&req.token_address));
        vector::push_back(&mut list, encoder::encode_string(&req.to));
        vector::push_back(&mut list, encoder::encode_u64(req.amount));

        let encoded=encoder::encode_list(&list,false);
        encoded
    }

    public fun decode(bytes:&vector<u8>): WithdrawTo {
        let decoded=decoder::decode_list(bytes);
        let token_address = decoder::decode_string(vector::borrow(&decoded, 1));
        let to = decoder::decode_string(vector::borrow(&decoded, 2));
        let amount = decoder::decode_u64(vector::borrow(&decoded, 3));
        let req= wrap_withdraw_to (
            token_address,
            to,
            amount
        );
        req
    }

     public fun wrap_withdraw_to(token_address: String, to: String, amount: u64): WithdrawTo {
        let withdraw_to = WithdrawTo {
            token_address: token_address,
            to: to,
            amount:amount,

        };
        withdraw_to
    }

    public fun token_address(deposit_revert: &WithdrawTo): String{
        deposit_revert.token_address
    }

    public fun to(deposit_revert: &WithdrawTo): String{
        deposit_revert.to
    }

    public fun amount(deposit_revert: &WithdrawTo): u64{
        deposit_revert.amount
    }

    #[test]
    fun test_xtransfer_encode_decode(){
        let token_address = string::utf8(b"sui/address");
        let to = string::utf8(b"sui/to");
        let withdraw = wrap_withdraw_to(token_address, to, 90);
        let data: vector<u8> = encode(&withdraw, b"test");
        let result = decode(&data);
        
        assert!(result.token_address == token_address, 0x01);
        assert!(result.to == to, 0x01);
        assert!(result.amount == 90, 0x01);
    }

}