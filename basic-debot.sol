pragma ton-solidity >= 0.35.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "./Debot.sol";
import "./Terminal.sol";
import "./AddressInput.sol";
import "./Sdk.sol";
import "./Menu.sol";

interface Basic {
    function submitTransaction(
        address  dest,
        uint128 value,
        bool bounce,
        bool allBalance,
        TvmCell payload)
    external returns (uint64 transId);

    function confirmTransaction(uint64 transactionId) external;
}

contract basicDebot is Debot {

    address m_wallet;
    uint128 m_balance;

    bool m_bounce;
    uint128 m_tons;
    address m_dest;

    constructor(string debotAbi) public {
        require(tvm.pubkey() == msg.pubkey(), 100);
        tvm.accept();
        init(DEBOT_ABI, debotAbi, "", address(0));
    }

    function start() public override {
        Menu.select("Main menu", "Hello, i'm a debot. I can help transfer tokens.", [
            MenuItem("Select account", "", tvm.functionId(selectWallet)),
            MenuItem("Exit", "", 0)
        ]);
    }

    function getVersion() public override returns (string name, uint24 semver) {
        (name, semver) = ("Debot", 1 << 16);
    }

    function fetch() public override returns (Context[] contexts) {}

    function quit() public override {}

    function selectWallet(uint32 index) public {
        index = index;
        Terminal.print(0, "Enter wallet address");
        AddressInput.select(tvm.functionId(checkWallet));
	}

    function checkWallet(address value) public {
        Sdk.getBalance(tvm.functionId(setBalance), value);
        Sdk.getAccountType(tvm.functionId(getWalletInfo), value);
        m_wallet = value;
	}

    function setBalance(uint128 nanotokens) public {
        m_balance = nanotokens;
    }

    function getWalletInfo(int8 acc_type) public {
        if (acc_type == -1)  {
            Terminal.print(0, "Wallet doesn't exist");
            return;
        }
        if (acc_type == 0) {
            Terminal.print(0, "Wallet is not initialized");
            return;
        }
        if (acc_type == 2) {
            Terminal.print(0, "Wallet is frozen");
            return;
        }

        (uint64 dec, uint64 float) = tokens(m_balance);
        Terminal.print(tvm.functionId(transferTons), format("Wallet balance is {}.{} tons", dec, float));
    }

    function transferTons() public {
        Terminal.inputTons(tvm.functionId(setTons), "Enter number of tokens to transfer");
        Terminal.print(0, "Select destination account");
        AddressInput.select(tvm.functionId(setDest));
        m_bounce = true;
    }

    function setTons(uint128 value) public {
        m_tons = value;
    }

    function setDest(address value) public {
        m_dest = value;
        (uint64 dec, uint64 float) = tokens(m_tons);
        string fmt = format("Transfer {}.{} tokens to account {} ?", dec, float, m_dest);
        Terminal.inputBoolean(tvm.functionId(submit), fmt);
    }

    function submit(bool value) public {
        if (!value) {
            Terminal.print(0, "Ok, maybe next time. Bye!");
            return;
        }
        TvmCell empty;
        optional(uint256) pubkey = 0;
        Basic(m_wallet).submitTransaction{
                abiVer: 2,
                extMsg: true,
                sign: true,
                pubkey: pubkey,
                time: uint64(now),
                expire: 0,
                callbackId: tvm.functionId(setResult),
                onErrorId: 0
            }(m_dest, m_tons, m_bounce, false, empty);
    }

    function setResult() public {
        Terminal.print(0, "Transfer succeeded. Bye!");
    }

    function tokens(uint128 nanotokens) private pure returns (uint64, uint64) {
        uint64 decimal = uint64(nanotokens / 1e9);
        uint64 float = uint64(nanotokens - (decimal * 1e9));
        return (decimal, float);
    }



}
