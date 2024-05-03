#[allow(unused_field,unused_use,unused_const,unused_mut_parameter,unused_variable,unused_assignment)]
module balanced::configure_protocol {
    use std::string::{Self, String};
    use std::option::{some, none};
    use sui_rlp::encoder;
    use sui_rlp::decoder;

    public struct ConfigureProtocol has drop{
        sources: vector<String>, 
        destinations: vector<String>
    }

    public fun encode(req:&ConfigureProtocol, method: vector<u8>):vector<u8>{
        let mut list=vector::empty<vector<u8>>();
        vector::push_back(&mut list, encoder::encode(&method));
        // let sources = req.sources;
        // let destinations = req.destinations;
        // let source_length = vector::length(&sources);
        // let mut source_list=vector::empty<vector<u8>>();
        // let mut i = 0;
        // while(i < source_length){
        //     vector::push_back(&mut source_list, encoder::encode_string(vector::borrow(&sources, i)));
        //     i = i+1;
        // };

        // let dest_length = vector::length(&destinations);
        // let mut dest_list=vector::empty<vector<u8>>();
        // i = 0;
        // while(i < dest_length){
        //     vector::push_back(&mut dest_list, encoder::encode_string(vector::borrow(&sources, i)));
        //     i = i+1;
        // };

        let source_encoded = encoder::encode_strings(&req.sources);
        let dest_encoded = encoder::encode_strings(&req.destinations);

        vector::push_back(&mut list, encoder::encode(&source_encoded));
        vector::push_back(&mut list, encoder::encode(&dest_encoded));

        let encoded=encoder::encode_list(&list,false);
        encoded
    }

    public fun decode(bytes:&vector<u8>): ConfigureProtocol {
        let decoded = decoder::decode_list(bytes);
        let sources = decoder::decode_strings(vector::borrow(&decoded, 1));
        let destinations = decoder::decode_strings(vector::borrow(&decoded, 2));

        // let mut sources=vector::empty<vector<String>>();
        // let source_length=vector::length(&sourcesBytes);
        // let mut i: u64 = 0;
        // while(i < source_length){
        //     vector::push_back(&mut sources, decoder::decode_string(vector::borrow(&sourcesBytes, i)));
        //     i = i+1;
        // };

        // let mut destinations = vector::empty<vector<String>>();
        // let dest_length=vector::length(&destinationsBytes);
        // i = 0;
        // while(i < dest_length){
        //     vector::push_back(&mut destinations, decoder::decode_string(vector::borrow(&destinationsBytes, i)));
        // };

        let req = wrap_protocols (
             sources,
             destinations
        );
        req
    }

    public fun wrap_protocols(sources: vector<String>, destinations: vector<String>): ConfigureProtocol {
        let protocols = ConfigureProtocol {
            sources: sources,
            destinations: destinations

        };
        protocols
    }

    public fun get_method(bytes:&vector<u8>): vector<u8> {
        let decoded=decoder::decode_list(bytes);
        let method = decoder::decode(vector::borrow(&decoded, 0));
        method
    }

    public fun sources(protocols: &ConfigureProtocol): vector<String>{
        protocols.sources
    }

    public fun destinations(protocols: &ConfigureProtocol): vector<String>{
        protocols.destinations
    }

}