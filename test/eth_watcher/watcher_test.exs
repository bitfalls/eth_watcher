defmodule EthWatcher.WatcherTest do
  use ExUnit.Case

  alias EthWatcher.Watcher

  describe "ETH watcher" do
    setup do

      with {:ok, eth_fixture } <- File.read("test/fixtures/eth_block.json"),
           {:ok, eth_token_fixture } <- File.read("test/fixtures/eth_block_token.json"),
           {:ok, eth_fixture_below } <- File.read("test/fixtures/eth_block_below_thresh.json"),
           {:ok, eth_fixture_dai } <- File.read("test/fixtures/eth_block_dai.json"),
           {:ok, eth_block } <- Poison.decode(eth_fixture),
           {:ok, eth_block_below } <- Poison.decode(eth_fixture_below),
           {:ok, token_block } <- Poison.decode(eth_token_fixture),
           {:ok, dai_block } <- Poison.decode(eth_fixture_dai)
      do
        token_tx      = token_block["transactions"] |> List.first
        token_dai_tx  = dai_block["transactions"] |> List.first
        eth_tx        = eth_block["transactions"] |> List.first
        kraken_tx     = eth_block["transactions"] |> Enum.at(1)
        eth_tx_below  = eth_block_below["transactions"] |> List.first
        %{
          eth_block: eth_block,
          eth_block_below: eth_block_below,
          eth_tx_below: eth_tx_below,
          token_block: token_block,
          token_tx: token_tx,
          eth_tx: eth_tx,
          kraken_tx: kraken_tx,
          dai_block: dai_block,
          token_dai_tx: token_dai_tx
        }
      end
    end

    test "add_token_details/2 correctly marks token tx", %{token_tx: tx, token_block: block} do
      updated_tx = Watcher.add_token_details(tx, block["timestamp"])
      assert updated_tx["is_token_tx"] == true
    end

    test "add_token_details/2 correctly marks eth tx", %{eth_tx: tx, eth_block: block} do
      updated_tx = Watcher.add_token_details(tx, block["timestamp"])

      assert updated_tx["is_token_tx"] == false
    end

    test "process_tx/1 processes eth tx", %{eth_tx: tx, eth_block: block} do
      processed_tx =
        tx
          |> Map.put("value", "0xA967E1C9C85EB1060000")
          |> Watcher.add_token_details(block["timestamp"])
          |> Watcher.process_tx

      assert processed_tx.symbol == "ETH"
    end

    test "process_tx/1 processes token tx", %{token_tx: tx, token_block: block} do
      processed_tx =
        tx
          |> Map.put("hash", "0x00d22086d8b84764cd9d400bcd3237d92a192d0ea2ae8bb1d9de25628c3a28e6")
          |> Watcher.add_token_details(block["timestamp"])
          |> Watcher.process_tx

      assert processed_tx.hash == "0x00d22086d8b84764cd9d400bcd3237d92a192d0ea2ae8bb1d9de25628c3a28e6"
    end

    test "process_tx/1 processes DAI tx", %{token_tx: tx, token_block: block} do
      processed_tx =
        tx
          |> Map.put("hash", "0x2a02733412a074c1f05e6299755e4e395f7995b3ea45c9b8ab4be1750fae5ee1")
          |> Map.put("to", "0x14fbca95be7e99c15cc2996c6c9d841e54b79425")
          |> Watcher.add_token_details(block["timestamp"])
          |> Watcher.process_tx

      assert processed_tx |> Map.has_key?(:transfer_log) == true
      assert processed_tx.is_token_tx == true
    end

    test "process_eth_tx/2 doesn't process tx if value below threshold", %{eth_tx_below: tx, eth_block: block} do
      processed_tx = tx
        |> Watcher.add_token_details(block["timestamp"])
        |> Watcher.process_eth_tx

      assert is_nil(processed_tx) == true
    end

    test "process_eth_tx/2 processes tx if value above threshold", %{eth_tx: tx, eth_block: block} do
      processed_tx = tx
        |> Map.put("value", "0xA967E1C9C85EB1060000")
        |> Watcher.add_token_details(block["timestamp"])
        |> Watcher.process_eth_tx

      assert processed_tx.value == "0xA967E1C9C85EB1060000"
      assert processed_tx.timestamp == 1538680780
    end

    test "process_token_tx/2 return correct values for txs", %{token_tx: tx, token_block: block} do
      processed_tx =
        tx
        |> Map.put("hash", "0x2ca89c40b72bf8350a5cdec95fe1a41884250614a31bc996c99229a5ab76e8f0")
        |> Map.put("to", "0xb8c77482e45f1f44de1745f52c74426c631bdd52")
        |> Watcher.add_token_details(block["timestamp"])
        |> Watcher.process_token_tx


        assert is_map(processed_tx.transfer_log) == true
        assert processed_tx.from == "0x54da06d9679b2f63b896431ecce99571d976d855"
        assert processed_tx.to == "0x3f5ce5fbfe3e9af3971dd833d26ba9b5c936f0be"
        assert processed_tx.value == "0x000000000000000000000000000000000000000000000ba580739ecf2cfc0000"
        assert processed_tx.is_token_tx == true
        assert processed_tx.hash == "0x2ca89c40b72bf8350a5cdec95fe1a41884250614a31bc996c99229a5ab76e8f0"
    end

    test "process_transactions/1 for token transaction", %{token_block: token_block} do
      txs           = token_block["transactions"]
      processed_tx  = Watcher.process_transactions(txs, token_block["timestamp"]) |> List.first

      assert is_map(processed_tx.transfer_log) == true
      assert processed_tx.from                 == "0xd007058e9b58e74c33c6bf6fbcd38baab813cbb6"
      assert processed_tx.to                   == "0xa04248bbbdae26fadc85e55ef79ec17ace948370"
      assert processed_tx.is_token_tx          == true
      assert processed_tx.value                == "0x0000000000000000000000000000000000000000000069e10de76676d0800000"
      assert processed_tx.hash                 == "0xa86a5857260093e6b262feb450b7ae5a1999cf7d476229ac5992dd4bf7b42553"
    end


    test "process_transactions/1 for dai token transaction", %{dai_block: dai_block} do
      txs           = dai_block["transactions"]
      processed_tx  = Watcher.process_transactions(txs, dai_block["timestamp"]) |> List.first

      assert processed_tx.from              == "0xf3ae3bbdeb2fb7f9c32fbb1f4fbdaf1150a1c5ce"
      assert processed_tx.to                == "0xab8d8b74f202f4cd4a918b65da4bac612e086ee7"
      assert processed_tx.is_token_tx       == true
      assert processed_tx.value             == "0x0000000000000000000000000000000000000000000006e2d8e80f07ebf7621a"
      assert processed_tx.hash              == "0x2fd2befb20960b4a7b50c3e2df1caf69855cdac469ccdce1791269adcac15bc9"
    end

    test "process_transactions/1 for eth transaction", %{eth_block: eth_block} do
      txs           = eth_block["transactions"]
      processed_tx  = Watcher.process_transactions(txs, eth_block["timestamp"]) |> List.first

      assert processed_tx[:from]          ==  "0x3f5ce5fbfe3e9af3971dd833d26ba9b5c936f0be"
      assert processed_tx[:to]            ==  "0x0681d8db095565fe8a346fa0277bffde9c0edbbf"
      assert processed_tx[:is_token_tx]   ==  false
      assert processed_tx[:value]         ==  "0x51bdf8236f942380000"
      assert processed_tx[:token_amount]  ==  24126000000000000000000
      assert processed_tx[:hash]          ==  "0x846c342793f8c7ddb2c2cb13f465cb1d11de12d41735971845b5ab6fc8a91c02"
    end

    test "process_transactions/1 for eth split transaction", %{eth_block: eth_block} do
      txs           = eth_block["transactions"]
      processed_tx  = Watcher.process_transactions(txs, eth_block["timestamp"]) |> Enum.at(1)

      assert processed_tx[:from]          ==  "0xd67f76d78fa3597b019f138f9c6481711d63fd6b"
      assert processed_tx[:to]            ==  "0x267be1c1d684f78cb4f6a176c4911b741e4ffdc0"
      assert processed_tx[:is_token_tx]   ==  true
      assert processed_tx[:value]         ==  "0x00000000000000000000000000000000000000000000054b40b0d8e4ec546500"
      assert processed_tx[:token_amount]  ==  "24999999683968500000000"
      assert processed_tx[:hash]          ==  "0x6b39e7d979f74e16718f5cba3d488720f27c34047c55b6a9ebb4dffa3e6aa714"
    end
  end
end
