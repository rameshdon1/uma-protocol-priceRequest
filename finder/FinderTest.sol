// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "finder/Interfaces.sol";

import "hardhat/console.sol";

// Hello Core devs the problem is requestPrice function is not working with my deployed version of oraclev2 and finder contract.
// Read the below comments to understand the scenario
contract FinderTest {
    // 0x2B264Bd755052F9B562935c0F63497a43A2baf23 - My own deployed finder on mumbai testnet
    // 0xb22033fF04AD01fbE8d78ef4622a20626834271B - UMA's Finder on mumbai testnet

    // video Source - https://www.youtube.com/watch?v=1sW8vcqTRCE
    // @reference - https://github.com/UMAprotocol/protocol/blob/master/packages/core/networks/80001.json#L3-L4
    // Check with UMA's deployed Finder on mumbai vs mine on mumbai testnet following latest tutorial from youtube.

    // 🚀 Below are the deployed contracts of oraclev2 following above tutorial.
    //Deployed Finder at 0x2B264Bd755052F9B562935c0F63497a43A2baf23
    //Deployed Store at 0x11742B631052b0d67dEfDB591D8fCb5831D009b2
    // Deployed AddressWhitelist at 0xE05de8ECC3FF7362aeE6E3664235F09801eD7d18
    // Deployed IdentifierWhitelist at 0xe12106099a42bE81aDaC6e98ef9d4f07edd91238
    // Deployed MockOracleAncillary at 0xda4Baf6F447bf77C1E9114E8DF23365fDb3cB1cF
    // Deployed Optimistic Oracle V2 at 0x0e1BCB4Ac5AFC6D4c53D07a91312a9ef68C6980d

    IFinder public finder = IFinder(0x2B264Bd755052F9B562935c0F63497a43A2baf23);
    IOptimisticOracleV2 public optimisticOracle =
        IOptimisticOracleV2(
            finder.getImplementationAddress("OptimisticOracleV2")
        );
    IAddressWhitelist public collateralWhitelist =
        IAddressWhitelist(
            finder.getImplementationAddress("CollateralWhitelist")
        );

    // Just in case you want to change finder on the go.
    function setFinder(address _finder) public {
        finder = IFinder(_finder);
        optimisticOracle = IOptimisticOracleV2(
            finder.getImplementationAddress("OptimisticOracleV2")
        );
        collateralWhitelist = IAddressWhitelist(
            finder.getImplementationAddress("CollateralWhitelist")
        );
    }

    function requestPrice() public {
        address rewardToken;

        // @reference - https://github.com/UMAprotocol/protocol/blob/master/packages/core/networks/80001.json#L3-L4
        // If the finder is uma's deployed Finder, then set rewardToken to the USDC token whitelisted by UMA.

        if (address(finder) == 0x2B264Bd755052F9B562935c0F63497a43A2baf23) {
            rewardToken = 0x52D800ca262522580CeBAD275395ca6e7598C014;
        } else {
            rewardToken = 0xe6b8a5CF854791412c1f6EFC7CAf629f5Df1c747;
        }

        bytes memory ancillaryData = bytes(
            "Q:Will it rain today? A:1 for yes. 0 for no."
        );

        bytes memory data = AncillaryDataLib._appendAncillaryData(
            msg.sender,
            ancillaryData
        );

        uint256 timestamp = block.timestamp;

        // 👇 this function works with UMA's finder but not mine. When called with mine's finder, a error is thrown.
        _requestPrice(msg.sender, timestamp, data, rewardToken, 0, 0, 60);
    }

        function _requestPrice(
        address requestor,
        uint256 requestTimestamp,
        bytes memory ancillaryData,
        address rewardToken,
        uint256 reward,
        uint256 bond,
        uint256 liveness
    ) internal {
        if (reward > 0) {
            // If the requestor is not the Adapter, the requestor pays for the price request
            // If not, the Adapter pays for the price request
            if (requestor != address(this)) {
                TransferHelper._transferFromERC20(
                    rewardToken,
                    requestor,
                    address(this),
                    reward
                );
            }

            // Approve the OO as spender on the reward token from the Adapter
            if (
                IERC20(rewardToken).allowance(
                    address(this),
                    address(optimisticOracle)
                ) < reward
            ) {
                IERC20(rewardToken).approve(
                    address(optimisticOracle),
                    type(uint256).max
                );
            }
        }


//⚡⚡🤔🤔 👇From here the optimisticOracle.requestPrice and all the functions below are not being executed on my sandbox oracle. But working on UMA's oracle contract. 

        // Send a price request to the Optimistic oracle
        optimisticOracle.requestPrice(
            "YES_OR_NO_QUERY",
            requestTimestamp,
            ancillaryData,
            IERC20(rewardToken),
            reward
        );

        // Ensure the price request is event based
        optimisticOracle.setEventBased(
            "YES_OR_NO_QUERY",
            requestTimestamp,
            ancillaryData
        );

        // Ensure that the dispute callback flag is set
        optimisticOracle.setCallbacks(
            "YES_OR_NO_QUERY",
            requestTimestamp,
            ancillaryData,
            false, // DO NOT set callback on priceProposed
            true, // DO set callback on priceDisputed
            false // DO NOT set callback on priceSettled
        );

        // Update the proposal bond on the Optimistic oracle if necessary
        if (bond > 0)
            optimisticOracle.setBond(
                "YES_OR_NO_QUERY",
                requestTimestamp,
                ancillaryData,
                bond
            );
        if (liveness > 0) {
            optimisticOracle.setCustomLiveness(
                "YES_OR_NO_QUERY",
                requestTimestamp,
                ancillaryData,
                liveness
            );
        }
    }
}
