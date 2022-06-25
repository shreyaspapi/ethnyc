// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.0;

interface IBurnMintSuperToken {


	/// @notice Initializer, used AFTER factory upgrade
	/// @dev We MUST mint here, there is no other way to mint tokens
	/// @param name Name of Super Token
	/// @param symbol Symbol of Super Token
	/// @param factory Super Token factory for initialization
	/// @param initialSupply Initial token supply to pre-mint
	/// @param receiver Receiver of pre-mint
	/// @param userData Arbitrary user data for pre-mint
	function initialize(
		string memory name,
		string memory symbol,
		address factory,
		uint256 initialSupply,
		address receiver,
		bytes memory userData
	) external;

	/// @notice Mints tokens, only the owner may do this
	/// @param receiver Receiver of minted tokens
	/// @param amount Amount to mint
	function mint(
		address receiver,
		uint256 amount,
		bytes memory userData
	) external;

	/// @notice Burns from message sender
	/// @param amount Amount to burn
	function burn(uint256 amount, bytes memory userData)
		external;
}
