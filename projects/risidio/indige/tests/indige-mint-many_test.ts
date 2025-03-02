import {
  Clarinet,
  Chain,
  types,
  Account
} from "https://deno.land/x/clarinet@v0.20.0/index.ts";
import { assertEquals, assert } from "https://deno.land/std@0.90.0/testing/asserts.ts";
import { IndigeClient, ErrCode } from "../../../../src/risidio-indige-client.ts";
import { WrappedBitcoin } from "../../../../src/wrapped-bitcoin-client.ts";
import { WrappedDiko } from "../../../../src/wrapped-diko-client.ts";

const mintAddress1 = "SP2M92VAE2YJ1P5VZ1Q4AFKWZFEKDS8CDA1KVFJ21";
const mintAddress2 = "SP132K8CVJ9B2GEDHTQS5MH3N7BR5QDMN1PXVS8MY";

const getWalletsAndClient = (
  chain: Chain,
  accounts: Map<string, Account>
): {
  administrator: Account;
  deployer: Account;
  tokenBitcoin: string;
  tokenDiko: string;
  tokenStacks: string;
  tokenWrappedStacks: string;
  commission1: string;
  wallet1: Account;
  wallet2: Account;
  wallet3: Account;
  wallet4: Account;
  wallet5: Account;
  newAdministrator: Account;
  clientV2: IndigeClient;
  clientWrappedBitcoin: WrappedBitcoin;
  clientWrappedDiko: WrappedDiko;
} => {
  const administrator = accounts.get("deployer")!;
  const deployer = accounts.get("deployer")!;
  const tokenBitcoin = accounts.get("deployer")!.address + '.Wrapped-Bitcoin';
  const tokenDiko = accounts.get("deployer")!.address + '.arkadiko-token';
  const tokenStacks = accounts.get("deployer")!.address + '.stx-token';
  const tokenWrappedStacks = accounts.get("deployer")!.address + '.wrapped-stx-token';
  const commission1 = accounts.get("deployer")!.address + '.commission-indige';
  const wallet1 = accounts.get("wallet_1")!;
  const wallet2 = accounts.get("wallet_2")!;
  const wallet3 = accounts.get("wallet_3")!;
  const wallet4 = accounts.get("wallet_4")!;
  const wallet5 = accounts.get("wallet_5")!;
  const newAdministrator = accounts.get("wallet_6")!;
  const clientV2 = new IndigeClient(chain, deployer);
  const clientWrappedBitcoin = new WrappedBitcoin(chain, deployer);
  const clientWrappedDiko = new WrappedDiko(chain, deployer);
  return {
    administrator,
    deployer,
    tokenBitcoin,
    tokenDiko,
    tokenStacks,
    tokenWrappedStacks,
    commission1,
    wallet1,
    wallet2,
    wallet3,
    wallet4,
    wallet5,
    newAdministrator,
    clientV2,
    clientWrappedBitcoin,
    clientWrappedDiko
  };
};

Clarinet.test({
  name: "Mint Many Test - Ensure mint pass can't be exceeded",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { deployer, wallet1, tokenStacks, clientV2 } = getWalletsAndClient(
      chain,
      accounts
    );
    let block = chain.mineBlock([
      clientV2.setMintCommission(tokenStacks, 0, mintAddress1, mintAddress2, 40, deployer.address),
      clientV2.setMintPass(wallet1.address, 5, deployer.address),
      clientV2.mintWithMany(6, tokenStacks, wallet1.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk();
    block.receipts[2].result.expectErr().expectUint(109); // reached mint pass limit
  }
});

Clarinet.test({
  name: "Mint Many Test - Ensure cant mint more than 20 at a time and batch mint cant exceed max collection",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { deployer, wallet1, tokenStacks, commission1, clientV2 } = getWalletsAndClient(
      chain,
      accounts
    );
    let block = chain.mineBlock([
      clientV2.setMintCommission(tokenStacks, 0, mintAddress1, mintAddress2, 40, deployer.address),
      clientV2.setMintPass(wallet1.address, 50, deployer.address),
      clientV2.mintWithMany(20, tokenStacks, wallet1.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk();
    clientV2.getLastTokenId().result.expectOk().expectUint(20);
    block.receipts[2].result.expectOk().expectBool(true);
    block = chain.mineBlock([
      clientV2.mintWithMany(5, tokenStacks, wallet1.address)
    ]);
    clientV2.getLastTokenId().result.expectOk().expectUint(25);
    block.receipts[0].result.expectOk().expectBool(true);
    block = chain.mineBlock([
      clientV2.mintWithMany(25, tokenStacks, wallet1.address)
    ]);
    clientV2.getLastTokenId().result.expectOk().expectUint(45);
    block.receipts[0].result.expectOk().expectBool(true);

    block = chain.mineBlock([
      clientV2.mintWithMany(0, tokenStacks, wallet1.address)
    ]);
    clientV2.getLastTokenId().result.expectOk().expectUint(45);
    block.receipts[0].result.expectOk().expectBool(true);

    // check max supply cant be exceeded
    block = chain.mineBlock([
      clientV2.mintWithMany(6, tokenStacks, wallet1.address)
    ]);
    clientV2.getLastTokenId().result.expectOk().expectUint(45);
    block.receipts[0].result.expectErr().expectUint(108);
  }
});

Clarinet.test({
  name: "Mint Many Test - Ensure can mint many in Stacks for zero price",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { deployer, wallet1, tokenStacks, commission1, clientV2 } = getWalletsAndClient(
      chain,
      accounts
    );
    let block = chain.mineBlock([
      clientV2.setMintCommission(tokenStacks, 0, mintAddress1, mintAddress2, 40, deployer.address),
      clientV2.setMintPass(wallet1.address, 15, deployer.address),
      clientV2.mintWithMany(10, tokenStacks, wallet1.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk();
    block.receipts[2].result.expectOk().expectBool(true);
    // console.log(block.receipts[2])
    assertEquals(block.receipts[2].events.length, 10);
    block.receipts[2].events.expectNonFungibleTokenMintEvent(
      types.uint(1),
      wallet1.address,
      `${deployer.address}.indige`,
      "indige"
    );
    block.receipts[2].events.expectNonFungibleTokenMintEvent(
      types.uint(10),
      wallet1.address,
      `${deployer.address}.indige`,
      "indige"
    );
  }
});

Clarinet.test({
  name: "Mint Many Test - Ensure can mint many in Stacks for fixed price",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { deployer, wallet1, tokenStacks, clientV2 } = getWalletsAndClient(
      chain,
      accounts
    );
    let block = chain.mineBlock([
      clientV2.setMintCommission(tokenStacks, 100000000, mintAddress1, mintAddress2, 50, deployer.address),
      clientV2.setMintPass(wallet1.address, 20, deployer.address),
      clientV2.mintWithMany(20, tokenStacks, wallet1.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk();
    block.receipts[2].result.expectOk().expectBool(true);
    assertEquals(block.receipts[2].events.length, 100);
    block.receipts[2].events.expectNonFungibleTokenMintEvent(
      types.uint(1),
      wallet1.address,
      `${deployer.address}.indige`,
      "indige"
    );
    block.receipts[2].events.expectSTXTransferEvent(
      99500000,
      wallet1.address,
      mintAddress1
    );
    block.receipts[2].events.expectSTXTransferEvent(
      500000,
      wallet1.address,
      mintAddress2
    );
    block.receipts[2].events.expectNonFungibleTokenMintEvent(
      types.uint(20),
      wallet1.address,
      `${deployer.address}.indige`,
      "indige"
    );
  }
});

Clarinet.test({
  name: "Mint Many Test - Ensure can mint ten in Stacks and ten in wrapped bitcoin for fixed price",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { deployer, wallet1, wallet2, tokenStacks, tokenDiko, clientWrappedBitcoin, clientWrappedDiko, clientV2 } = getWalletsAndClient(
      chain,
      accounts
    );
    clientWrappedBitcoin.getBalance(wallet1.address, wallet1).result.expectOk().expectUint(0);
    clientWrappedDiko.getBalance(wallet2.address, wallet2).result.expectOk().expectUint(0);
    let block = chain.mineBlock([
      clientWrappedBitcoin.mintWrappedBitcoin(1000, wallet1.address, wallet1.address),
      clientWrappedDiko.mintWrappedDiko(200000000, wallet2.address, wallet2.address),
    ]);
    clientWrappedBitcoin.getBalance(wallet1.address, wallet1).result.expectOk().expectUint(1000);
    clientWrappedDiko.getBalance(wallet2.address, wallet2).result.expectOk().expectUint(200000000);

    block = chain.mineBlock([
      clientV2.setMintCommission(tokenStacks, 100000000, mintAddress1, mintAddress2, 50, deployer.address),
      clientV2.setMintCommission(tokenDiko, 100000000, mintAddress1, mintAddress2, 1000, deployer.address),
      clientV2.setMintPass(wallet1.address, 10, deployer.address),
      clientV2.setMintPass(wallet2.address, 10, deployer.address),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk().expectBool(true);
    block.receipts[2].result.expectOk().expectBool(true);
    block.receipts[3].result.expectOk().expectBool(true);

    block = chain.mineBlock([
      clientV2.mintWithMany(10, tokenStacks, wallet1.address),
      clientV2.mintWithMany(2, tokenDiko, wallet2.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk().expectBool(true);
    // console.log(block.receipts[1])
    assertEquals(block.receipts[0].events.length, 50);
    assertEquals(block.receipts[1].events.length, 10);

    block.receipts[0].events.expectNonFungibleTokenMintEvent(
      types.uint(1),
      wallet1.address,
      `${deployer.address}.indige`,
      "indige"
    );
    block.receipts[0].events.expectSTXTransferEvent(
      99500000,
      wallet1.address,
      mintAddress1
    );
    block.receipts[0].events.expectSTXTransferEvent(
      500000,
      wallet1.address,
      mintAddress2
    );
    block.receipts[0].events.expectNonFungibleTokenMintEvent(
      types.uint(10),
      wallet1.address,
      `${deployer.address}.indige`,
      "indige"
    );

    block.receipts[1].events.expectNonFungibleTokenMintEvent(
      types.uint(11),
      wallet2.address,
      `${deployer.address}.indige`,
      "indige"
    );
    block.receipts[1].events.expectFungibleTokenTransferEvent(
      90000000,
      wallet2.address,
      mintAddress1,
      `${deployer.address}.arkadiko-token::diko`
    );
    block.receipts[1].events.expectFungibleTokenTransferEvent(
      10000000,
      wallet2.address,
      mintAddress2,
      `${deployer.address}.arkadiko-token::diko`
    );
    block.receipts[1].events.expectNonFungibleTokenMintEvent(
      types.uint(12),
      wallet2.address,
      `${deployer.address}.indige`,
      "indige"
    );
  }
});


