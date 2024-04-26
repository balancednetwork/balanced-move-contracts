#[allow(unused_field,unused_use,unused_const,unused_mut_parameter,unused_variable,unused_assignment)]
module balanced::deposit {
    use std::string::{Self, String};
    use std::option::{some, none};
    use sui_rlp::encoder;
    use sui_rlp::decoder;

    public struct Deposit has drop {
        token_address: String,
        from: String,
        to: String,
        amount: u64,
        data: vector<u8>
    }

    public fun encode(req:&Deposit):vector<u8>{
        let mut list=vector::empty<vector<u8>>();
        vector::push_back(&mut list,encoder::encode_string(&req.token_address));
        vector::push_back(&mut list,encoder::encode_string(&req.from));
        vector::push_back(&mut list,encoder::encode_string(&req.to));
        vector::push_back(&mut list,encoder::encode_u64(req.amount));
        vector::push_back(&mut list,encoder::encode(&req.data));

        let encoded=encoder::encode_list(&list,false);
        encoded
    }

    public fun decode(bytes:&vector<u8>): Deposit {
        let decoded=decoder::decode_list(bytes);
        let token_address = decoder::decode_string(vector::borrow(&decoded,0));
        let from = decoder::decode_string(vector::borrow(&decoded,1));
        let to = decoder::decode_string(vector::borrow(&decoded,2));
        let amount = decoder::decode_u64(vector::borrow(&decoded,3));
        let data = decoder::decode(vector::borrow(&decoded,4));
        let req= Deposit {
            token_address,
            from,
            to,
            amount,
            data
        };
        req
    }

     public fun wrap_deposit(token_address: String, from: String, to: String, amount: u64, data: vector<u8>): Deposit {
        let deposit = Deposit {
            token_address: token_address,
            from: from,
            to: to,
            amount: amount,
            data: data

        };
        deposit
    }

}