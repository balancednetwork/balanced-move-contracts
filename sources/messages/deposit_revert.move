#[allow(unused_field,unused_use,unused_const,unused_mut_parameter,unused_variable,unused_assignment)]
module balanced::deposit_revert {
    use std::string::{Self, String};
    use std::option::{some, none};
    use sui_rlp::encoder;
    use sui_rlp::decoder;

    public struct DepositRevert has drop {
        token_address: String,
        to: String,
        amount: u64
    }

    public fun encode(req:&DepositRevert):vector<u8>{
        let mut list=vector::empty<vector<u8>>();
        vector::push_back(&mut list,encoder::encode_string(&req.token_address));
        vector::push_back(&mut list,encoder::encode_string(&req.to));
        vector::push_back(&mut list,encoder::encode_u64(req.amount));

        let encoded=encoder::encode_list(&list,false);
        encoded
    }

    public fun decode(bytes:&vector<u8>): DepositRevert {
        let decoded=decoder::decode_list(bytes);
        let token_address = decoder::decode_string(vector::borrow(&decoded,0));
        let to = decoder::decode_string(vector::borrow(&decoded,1));
        let amount = decoder::decode_u64(vector::borrow(&decoded,2));
        let req= DepositRevert {
            token_address,
            to,
            amount
        };
        req
    }

     public fun wrap_deposit_revert(token_address: String, to: String, amount: u64): DepositRevert {
        let deposit_revert = DepositRevert {
            token_address: token_address,
            to: to,
            amount:amount
        };
        deposit_revert
    }

}