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

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    CFAv1Library
} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

import {
    IDAv1Library
} from "@superfluid-finance/ethereum-contracts/contracts/apps/IDAv1Library.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "./aave/ILendingPool.sol";

contract RedirectTokens is SuperAppBase, Ownable {

    using CFAv1Library for CFAv1Library.InitData;
    
    CFAv1Library.InitData public cfaV1;
    ISuperfluid private _host; // host
    ISuperToken private usdcx; // accepted token
    ISuperToken private eth; // accepted token
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

    IUniswapV2Router02 router = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    
    ILendingPool aave = ILendingPool(address(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf));

    constructor(
        ISuperfluid host,
        IConstantFlowAgreementV1 _cfa,
        ISuperToken _token1,
        address _token2
    ) {
        require(address(host) != address(0), "host is zero address");
        require(address(_token1) != address(0), "usdcx is zero address");
        require(address(_token2) != address(0), "eth is zero address");


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

        cfa = _cfa;
        usdcx = _token1;
        eth = _token2;

        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);
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
        _token1.downgrade(_token1.balanceOf(address(this)));
        
        IERC20 token1Underlying = IERC20(_token1.getUnderlyingToken());
        token1Underlying.approve(address(router), token1Underlying.balanceOf(address(this)));
        
        address[] memory path;

        path = new address[](2);
        path[0] = _token1.getUnderlyingToken();
        path[1] = _token2.getUnderlyingToken();

        router.swapExactTokensForTokens(
             token1Underlying.balanceOf(address(this)),
             0, // minOutput
             path,
             address(this),
             block.timestamp + 3600
          );
          
        uint256 amountOut = IERC20(_token2.getUnderlyingToken()).balanceOf(address(this));

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
        bytes32, // _agreementId,
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

        bool isToken1 = _superToken == usdcx;

        _handleUpdateStream(_shareholder, _flowRate);
        if (isToken1) {
            addAddressToArray1(_shareholder);
        } else {
            addAddressToArray2(_shareholder);
        }

    }

    function distributeTokens() external {
        // swap all of the USDC to WETH
        uint256 amountSwapped = swapToken1(usdcx, eth);
        // deposit WETH into aave
        aave.deposit(eth.getUnderLyingToken(), amount, address(this), 0);
        // borrow MATIC @ 30% of the USDC
        aave.borrow(eth.getUnderlyingToken(), amount, interestRateMode, referralCode, onBehalfOf);
        // Stake all of the MATIC

        // first we want to get all of the usdcx addresses and send 
        
        // loop in streamAddressesToken1
        for (uint i = 0; i < streamAddressesToken1.length; i++) {
            // address _shareholder = streamAddressesToken1[i];
            // uint256 _flowRate = _getFlowRate(_shareholder, usdcx);
            // uint256 _amount = _flowRate * amountSwapped / 10 ** 18;
            // usdcx.transfer(_shareholder, _amount);
        }

    }

    function afterAgreementUpdated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 ,//_agreementId,
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
    }

    function _isAcceptedToken(ISuperToken superToken) private view returns (bool) {
        return (address(superToken) == address(usdcx) || address(superToken) == address(eth));
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType()
            == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }
}

