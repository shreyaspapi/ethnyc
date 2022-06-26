// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    ContextDefinitions,
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    CFAv1Library
} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

import {
    IInstantDistributionAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";

import {
    IDAv1Library
} from "@superfluid-finance/ethereum-contracts/contracts/apps/IDAv1Library.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "./aave/IPool.sol";

// import { BurnMintSuperToken } from "./superTokenPure/BurnMintSuperToken.sol";
import { IBurnMintSuperToken } from "./superTokenPure/IBurnMintSuperToken.sol";

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";

contract RedirectTokens is SuperAppBase, Ownable {

    using CFAv1Library for CFAv1Library.InitData;
     using IDAv1Library for IDAv1Library.InitData;

    uint32 public constant INDEX_ID = 0;

    bytes32 internal constant IDAV1_ID = keccak256(
        "org.superfluid-finance.agreements.InstantDistributionAgreement.v1"
    );

    // use callbacks to track approved subscriptions
    mapping (address => bool) public isSubscribing;

    // declare `_idaLib` of type InitData
    IDAv1Library.InitData internal _idaLib;
    AggregatorV3Interface internal priceFeed;
    CFAv1Library.InitData public cfaV1;
    ISuperfluid private _host; // host
    ISuperToken private usdcx; // accepted token
    ISuperToken private eth; // accepted token - should this be an ISuperToken
    // we need to hardcode the address of this token?
    ISuperToken public ownershipToken = ISuperToken(address(0xbfFc2f7Ac0011f65a70DAD01C12C903045eDAa25));
    IConstantFlowAgreementV1 cfa;
    int96 public fees_basis_points;

    struct StreamInfo {
        int96 streamRate;
        uint256 time;
        uint256 amount;
    }

    mapping (address => StreamInfo) public addressToStreamInfo;
    mapping (address => uint256) public addressToIndex1;
    mapping (address => uint256) public addressToIndex2;
    address[] public streamAddressesToken1;
    address[] public streamAddressesToken2;

    uint256 totalSupply = 0;

    IUniswapV2Router02 router = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    
    IPool aave = IPool(address(0xca2413028D0c91f5F88821A13d4A82690945F678));

    address aaveUSDC = address(0xb18d016cDD2d9439A19f15633005A6b2cd6Aa774);

    uint256 public totalPoolValue = 0;

    ISwapRouter02 swapRouter;


    constructor(
        ISuperfluid host,
        IConstantFlowAgreementV1 _cfa,
        IInstantDistributionAgreementV1 ida,
        ISuperToken _token1,
        ISuperToken _token2,
        ISwapRouter02 _swapRouter,
        string memory _registrationKey
    ) {
        require(address(host) != address(0), "host is zero address");
        require(address(_token1) != address(0), "usdcx is zero address");
        require(address(_token2) != address(0), "eth is zero address");

        swapRouter = _swapRouter;

        _host = host;   
        fees_basis_points = 10;
        // initialize InitData struct, and set equal to cfaV1
        cfaV1 = CFAv1Library.InitData(
            host,
            //here, we are deriving the address of the CFA using the host contract
            IConstantFlowAgreementV1(
                address(host.getAgreementClass(
                    keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1")
                ))
            )
        );

        _idaLib = IDAv1Library.InitData(host, ida);

        cfa = _cfa;
        usdcx = _token1;
        eth = _token2;

        _idaLib.createIndex(ownershipToken, INDEX_ID);


        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        if (bytes(_registrationKey).length > 0) {
            _host.registerAppWithKey(configWord, _registrationKey);
        } else {
            _host.registerApp(configWord);
        }

    }

    function _checkSubscription(
        ISuperToken superToken,
        bytes calldata ctx,
        bytes32 agreementId
    )
        private
    {
        ISuperfluid.Context memory context = _idaLib.host.decodeCtx(ctx);
        // only interested in the subscription approval callbacks
        if (context.agreementSelector == IInstantDistributionAgreementV1.approveSubscription.selector) {
            address publisher;
            uint32 indexId;
            bool approved;
            uint128 units;
            uint256 pendingDistribution;
            (publisher, indexId, approved, units, pendingDistribution) =
                _idaLib.ida.getSubscriptionByID(superToken, agreementId);

            // sanity checks for testing purpose
            require(publisher == address(this), "DRT: publisher mismatch");
            require(indexId == INDEX_ID, "DRT: publisher mismatch");

            if (approved) {
                isSubscribing[context.msgSender /* subscriber */] = true;
            }
        }
    }


    modifier onlyHost() {
        require(msg.sender == address(_host), "RedirectAll: support only one host");
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isAcceptedToken(superToken), "RedirectAll: not accepted token");
        require(_isCFAv1(agreementClass), "RedirectAll: only CFAv1 supported");
        _;
    }
    
    function getRatio(uint256 numerator, uint256 denominator) internal pure returns (uint256) {
        uint _quotient = ((((numerator * (10 ** (18 + 1))) / denominator) + 5) / 10);
        return _quotient;
    }

    function safeCastToInt96(uint256 _value) internal pure returns (int96) {
        if (_value > (2 ** 96) - 1) {
            return int96(0);
        }
        return int96(int(_value));
    }

    // /* App Functions */
    function changeFeeBasisPoints(int96 _fees_basis_points) onlyOwner public {
        require(_fees_basis_points > 0, "RedirectAll: fees_basis_points must be greater than 0");
        fees_basis_points = _fees_basis_points;
    }

    function swapToken1(ISuperToken _token1, ISuperToken _token2) internal returns (uint256) {
        // downgrade all of the super token        
        // approve the underlying token
        _token1.approve(address(router), _token1.balanceOf(address(this)));
        
        address[] memory path;

        path = new address[](2);
        path[0] = address(_token1);
        path[1] = address(_token2);

        // here we swap the tokens using uniswap
        router.swapExactTokensForTokens(
             _token1.balanceOf(address(this)),
             0, // minOutput
             path,
             address(this),
             block.timestamp + 3600
          );
          
        uint256 amountOut = IERC20(_token2).balanceOf(address(this));

        return amountOut;
    }

    function swapToken2(ISuperToken _token1, ISuperToken _token2) internal returns (uint256) {
        address token1Underlying = _token1.getUnderlyingToken();
        IERC20(token1Underlying).approve(address(router), IERC20(token1Underlying).balanceOf(address(this)));
        
        address[] memory path;
        
        path = new address[](2);
        path[0] = _token1.getUnderlyingToken();
        path[1] = _token2.getUnderlyingToken();
        
        router.swapExactTokensForTokens(
             IERC20(token1Underlying).balanceOf(address(this)),
             0, // minOutput
             path,
             address(this),
             block.timestamp + 3600
          );
          
        uint256 amountOut = IERC20(_token2.getUnderlyingToken()).balanceOf(address(this));


        address token2Underlying = _token2.getUnderlyingToken();
        IERC20(token2Underlying).approve(address(_token2), IERC20(token2Underlying).balanceOf(address(this)));
        _token2.upgrade(IERC20(token2Underlying).balanceOf(address(this)));

        return amountOut;
    }

    // Create function to percent difference from usdcx to eth to calculate fees
    function calculateFlowToken1(int96 _flowRate) view public returns (int96) {
        uint256 flowRate = uint256(int(_flowRate));

        uint256 token1Balance = usdcx.balanceOf(address(this));
        uint256 token2Balance = eth.balanceOf(address(this));

        if (token1Balance == token2Balance) {
            return _flowRate;
        }

        bool isToken1Greater = usdcx.balanceOf(address(this)) > eth.balanceOf(address(this));
        uint ratio = isToken1Greater ? 
                        getRatio(token2Balance, token1Balance) : 
                        getRatio(token1Balance, token2Balance);

        return isToken1Greater ? 
                safeCastToInt96((ratio * flowRate) / 10 ** 18) :
                safeCastToInt96((2 * flowRate) - (ratio * flowRate) / 10 ** 18);
    }

    function calculateFlowToken2(int96 _flowRate) view public returns (int96) {
        uint256 flowRate = uint256(int(_flowRate));

        uint256 token1Balance = usdcx.balanceOf(address(this));
        uint256 token2Balance = eth.balanceOf(address(this));
 
        if (token1Balance == token2Balance) {
            return _flowRate;
        }

        bool isToken2Greater = usdcx.balanceOf(address(this)) < eth.balanceOf(address(this));
        uint ratio = isToken2Greater ? 
                        getRatio(token1Balance, token2Balance) : 
                        getRatio(token2Balance, token1Balance);

        return isToken2Greater ? 
                safeCastToInt96((2 * flowRate) - (ratio * flowRate) / 10 ** 18) :
                safeCastToInt96((ratio * flowRate) / 10 ** 18);
    }


    function _getShareholderInfo(bytes calldata _agreementData, ISuperToken _superToken)
        internal
        view
        returns (address _shareholder, int96 _flowRate, uint256 _timestamp)
    {
        (_shareholder, ) = abi.decode(_agreementData, (address, address));
        (_timestamp, _flowRate, , ) = cfa.getFlow(
            _superToken,
            _shareholder,
            address(this)
        );
    }

    function _handleUpdateStream(address userAddress, int96 flowrate) internal {
        StreamInfo storage streamInfo = addressToStreamInfo[userAddress];

        if (streamInfo.time == 0) {
            streamInfo.time = block.timestamp;
            streamInfo.streamRate = flowrate;
            streamInfo.amount = 0;
        } else {
            uint256 timeDiff = block.timestamp - streamInfo.time;
            uint256 amount = uint256(int(safeCastToInt96(timeDiff) * streamInfo.streamRate));
            streamInfo.amount += amount;
            streamInfo.time = block.timestamp;
            streamInfo.streamRate = flowrate;
        }

    }   
    
    function addAddressToArray1(address _address) internal {
        // loop array streamAddressesToken1
        for (uint i = 0; i < streamAddressesToken1.length; i++) {
            if (streamAddressesToken1[i] == _address) {
                return;
            }
        }
        streamAddressesToken1.push(_address);
        addressToIndex1[_address] = streamAddressesToken1.length;
    }

    function addAddressToArray2(address _address) internal {
        // loop array streamAddressesToken1
        for (uint i = 0; i < streamAddressesToken2.length; i++) {
            if (streamAddressesToken2[i] == _address) {
                return;
            }
        }
        streamAddressesToken2.push(_address);
        addressToIndex2[_address] = streamAddressesToken2.length;
    }

    /**************************************************************************
     * SuperApp callbacks
     *************************************************************************/

    function afterAgreementCreated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 _agreementId,
        bytes calldata _agreementData,
        bytes calldata ,// _cbdata,
        bytes calldata _ctx
    )
        external override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        // According to the app basic law, we should never revert in a termination callback
        if (!_isAcceptedToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;

        (address _shareholder, ) = abi.decode(_agreementData, (address, address));
        (, int96 _flowRate, , ) = cfa.getFlow(
            _superToken,
            _shareholder,
            address(this)
        );

        _checkSubscription(ownershipToken, _ctx, _agreementId);

        newCtx = _ctx;

    }

    function distributeTokens() external {

        uint256 usdcxBalance = usdcx.balanceOf(address(this)); 
        
        // swap all of the USDC to WETH using uniswap
        uint256 amountSwappedLink = swapToken1(usdcx, eth);
        
        // here we want to approve eth to the aave contract
        eth.approve(address(aave), eth.balanceOf(address(this)));
        // deposit WETH into aave
        aave.supply(address(eth), amountSwappedLink, address(this), 0);

        (uint256 collatUsdValue, uint256 borrowedUSD, , , , uint256 healthFactor) = aave.getUserAccountData(address(this));
        totalPoolValue = collatUsdValue + borrowedUSD;

        if (healthFactor > 33 * (10 ** 17)) {
            uint256 expectedLoanValue = (3*collatUsdValue)/10;
            uint256 amountToIncrease = expectedLoanValue - borrowedUSD;

            aave.borrow(aaveUSDC, amountToIncrease, 1, 0, address(this));
        }

        // mint ownership token
        IBurnMintSuperToken(address(ownershipToken)).mint(address(this), amountSwappedLink, "");

        // distribute using IDA
        _idaLib.distribute(ownershipToken, INDEX_ID, amountSwappedLink);

        // uint256 ownershipTokenBalance = ownershipToken.balanceOf(address(this));

    }

    function getTokensFromContract(address token) onlyOwner external {
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    // function reclaimTokens() external {
    //     // get all of the custom tokens which have been streamed in
    //     uint256 total_in = 100;
    //     // return eth equal to 30% of the custom tokens which have been streamed in
    //     uint256 amountRepaid = aave.repay(address(eth), total_in, 2, address(this));
    //     // get weth and convert to USDC equal to the custom tokens streamed in
    //     swapToken2(eth, usdcx);
    //     // burn the custom tokens
    // }

    function afterAgreementUpdated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 _agreementId,
        bytes calldata _agreementData,
        bytes calldata ,//_cbdata,
        bytes calldata _ctx
    )
        external override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        // According to the app basic law, we should never revert in a termination callback
        if (!_isAcceptedToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;

        (address _shareholder, ) = abi.decode(_agreementData, (address, address));
        (, int96 _flowRate, , ) = cfa.getFlow(
            _superToken,
            _shareholder,
            address(this)
        );

        bool isToken1 = _superToken == usdcx;

        _handleUpdateStream(_shareholder, _flowRate);
        if (isToken1) {
            addAddressToArray1(_shareholder);
        } else {
            addAddressToArray2(_shareholder);
        }
        
        _checkSubscription(ownershipToken, _ctx, _agreementId);


        newCtx = _ctx;

    }

    function afterAgreementTerminated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 ,//_agreementId,
        bytes calldata _agreementData,
        bytes calldata ,//_cbdata,
        bytes calldata _ctx
    )
        external override
        onlyHost
        returns (bytes memory newCtx)
    {
        // According to the app basic law, we should never revert in a termination callback
        if (!_isAcceptedToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;
        
        (address _shareholder,, ) = _getShareholderInfo(
            _agreementData, _superToken
        );

        bool isToken1 = _superToken == usdcx;
        if (isToken1) {
            delete streamAddressesToken1[addressToIndex1[_shareholder]];
        } else {
            delete streamAddressesToken2[addressToIndex2[_shareholder]];
        }

        _handleUpdateStream(_shareholder, 0);
        addressToStreamInfo[_shareholder].time = 0;
        addressToStreamInfo[_shareholder].streamRate = 0;

        newCtx = _ctx;

    }

    function _isAcceptedToken(ISuperToken superToken) private view returns (bool) {
        return (address(superToken) == address(usdcx) || address(superToken) == address(eth));
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType()
            == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }

     /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
    }
}

