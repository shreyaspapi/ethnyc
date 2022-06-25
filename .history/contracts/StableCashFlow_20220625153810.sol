//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./RedirectTokens.sol";

// npx hardhat run --network ropsten scripts/deploy.js
// npx hardhat verify --network ropsten 0x762e4d8b54Dd89206d62C3C4f9EE543D18cB263A "0xF2B4E81ba39F5215Db2e05B2F66f482BB8e87FD2" "0xaD2F1f7cd663f6a15742675f975CcBD42bb23a88" "0xBF6201a6c48B56d8577eDD079b84716BB4918E8A" "0x2dC36872a445adF0bFf63cc0eeee52A2b801625f"
contract StableCashFlow is RedirectTokens {
    using SafeERC20 for IERC20;

    ISuperToken token1;
    ISuperToken token2;

    constructor(
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken _token1, 
        ISuperToken _token2
    ) RedirectTokens(
            host,
            cfa,
            _token1,
            _token2
        ) public {
        token1 = _token1;
        token2 = _token2;
    }

    function addLiquidity(uint256 _amount) public {
        require(token1.balanceOf(msg.sender) > 0, "Not enough balance");
        require(token2.balanceOf(msg.sender) > 0, "Not enough balance");

        token2.transferFrom(msg.sender, address(this), _amount);
        token1.transferFrom(msg.sender, address(this), _amount);

        // TODO: Mint amm tokens to the owner
    }

    function removeLiquidity() public {        
        // TODO: Burn amm tokens and transfer value of token 1 and 2 to the owner        
        token2.transferFrom(address(this), msg.sender, token2.balanceOf(address(this)));
        token1.transferFrom(address(this), msg.sender, token1.balanceOf(address(this)));
    }

}
