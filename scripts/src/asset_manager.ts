import { TransactionBlock } from '@mysten/sui.js/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execstuff';
import { packageId } from '../utils/packageInfo';
dotenv.config();

async function test(address1: String) {
    const { keypair, client } = getExecStuff();
    const tx = new TransactionBlock();

    tx.moveCall({
        target: `${packageId}::balanced::test`,
        arguments: [
            tx.pure([address1], "vector<address>")
            ,
        ]
    });

    const result = await client.signAndExecuteTransactionBlock({
        signer: keypair,
        transactionBlock: tx,
    });

    console.log({ result });
}

test("0x821febff0631744c231a0f696f62b72576f2634b2ade78c74ff20f1df97fc9bf");
