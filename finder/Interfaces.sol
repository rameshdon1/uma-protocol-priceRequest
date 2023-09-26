import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib, ERC20} from "https://github.com/transmissions11/solmate/src/utils/SafeTransferLib.sol";

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

struct RequestSettings {
    bool eventBased; // True if the request is set to be event-based.
    bool refundOnDispute; // True if the requester should be refunded their reward on dispute.
    bool callbackOnPriceProposed; // True if callbackOnPriceProposed callback is required.
    bool callbackOnPriceDisputed; // True if callbackOnPriceDisputed callback is required.
    bool callbackOnPriceSettled; // True if callbackOnPriceSettled callback is required.
    uint256 bond; // Bond that the proposer and disputer must pay on top of the final fee.
    uint256 customLiveness; // Custom liveness value set by the requester.
}

// Struct representing a price request.
struct Request {
    address proposer; // Address of the proposer.
    address disputer; // Address of the disputer.
    IERC20 currency; // ERC20 token used to pay rewards and fees.
    bool settled; // True if the request is settled.
    RequestSettings requestSettings; // Custom settings associated with a request.
    int256 proposedPrice; // Price that the proposer submitted.
    int256 resolvedPrice; // Price resolved once the request is settled.
    uint256 expirationTime; // Time at which the request auto-settles without a dispute.
    uint256 reward; // Amount of the currency to pay to the proposer on settlement.
    uint256 finalFee; // Final fee to pay to the Store upon request to the DVM.
}

/// @title Optimistic Oracle V2 Interface
interface IOptimisticOracleV2 {
    /// @notice Requests a new price.
    /// @param identifier price identifier being requested.
    /// @param timestamp timestamp of the price being requested.
    /// @param ancillaryData ancillary data representing additional args being passed with the price request.
    /// @param currency ERC20 token used for payment of rewards and fees. Must be approved for use with the DVM.
    /// @param reward reward offered to a successful proposer. Will be pulled from the caller. Note: this can be 0,
    ///               which could make sense if the contract requests and proposes the value in the same call or
    ///               provides its own reward system.
    /// @return totalBond default bond (final fee) + final fee that the proposer and disputer will be required to pay.
    /// This can be changed with a subsequent call to setBond().
    function requestPrice(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        IERC20 currency,
        uint256 reward
    ) external returns (uint256 totalBond);

    /// @notice Proposes a price value for an existing price request.
    /// @param requester sender of the initial price request.
    /// @param identifier price identifier to identify the existing request.
    /// @param timestamp timestamp to identify the existing request.
    /// @param ancillaryData ancillary data of the price being requested.
    /// @param proposedPrice price being proposed.
    /// @return totalBond the amount that's pulled from the proposer's wallet as a bond. The bond will be returned to
    /// the proposer once settled if the proposal is correct.
    function proposePrice(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        int256 proposedPrice
    ) external returns (uint256 totalBond);

    /// @notice Disputes a price value for an existing price request with an active proposal.
    /// @param requester sender of the initial price request.
    /// @param identifier price identifier to identify the existing request.
    /// @param timestamp timestamp to identify the existing request.
    /// @param ancillaryData ancillary data of the price being requested.
    /// @return totalBond the amount that's pulled from the disputer's wallet as a bond. The bond will be returned to
    /// the disputer once settled if the dispute was valid (the proposal was incorrect).
    function disputePrice(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external returns (uint256 totalBond);

    /// @notice Set the proposal bond associated with a price request.
    /// @param identifier price identifier to identify the existing request.
    /// @param timestamp timestamp to identify the existing request.
    /// @param ancillaryData ancillary data of the price being requested.
    /// @param bond custom bond amount to set.
    /// @return totalBond new bond + final fee that the proposer and disputer will be required to pay. This can be
    /// changed again with a subsequent call to setBond().
    function setBond(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        uint256 bond
    ) external returns (uint256 totalBond);

    /// @notice Sets the request to be an "event-based" request.
    /// @dev Calling this method has a few impacts on the request:
    ///
    /// 1. The timestamp at which the request is evaluated is the time of the proposal, not the timestamp associated
    ///    with the request.
    ///
    /// 2. The proposer cannot propose the "too early" value (TOO_EARLY_RESPONSE). This is to ensure that a proposer who
    ///    prematurely proposes a response loses their bond.
    ///
    /// 3. RefundoOnDispute is automatically set, meaning disputes trigger the reward to be automatically refunded to
    ///    the requesting contract.
    ///
    /// @param identifier price identifier to identify the existing request.
    /// @param timestamp timestamp to identify the existing request.
    /// @param ancillaryData ancillary data of the price being requested.
    function setEventBased(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external;

    /// @notice Sets which callbacks should be enabled for the request.
    /// @param identifier price identifier to identify the existing request.
    /// @param timestamp timestamp to identify the existing request.
    /// @param ancillaryData ancillary data of the price being requested.
    /// @param callbackOnPriceProposed whether to enable the callback onPriceProposed.
    /// @param callbackOnPriceDisputed whether to enable the callback onPriceDisputed.
    /// @param callbackOnPriceSettled whether to enable the callback onPriceSettled.
    function setCallbacks(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        bool callbackOnPriceProposed,
        bool callbackOnPriceDisputed,
        bool callbackOnPriceSettled
    ) external;

    /// @notice Sets a custom liveness value for the request. Liveness is the amount of time a proposal must wait before
    /// being auto-resolved.
    /// @param identifier price identifier to identify the existing request.
    /// @param timestamp timestamp to identify the existing request.
    /// @param ancillaryData ancillary data of the price being requested.
    /// @param customLiveness new custom liveness.
    function setCustomLiveness(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        uint256 customLiveness
    ) external;

    /// @notice Attempts to settle an outstanding price request. Will revert if it isn't settleable.
    /// @param requester sender of the initial price request.
    /// @param identifier price identifier to identify the existing request.
    /// @param timestamp timestamp to identify the existing request.
    /// @param ancillaryData ancillary data of the price being requested.
    /// @return payout the amount that the "winner" (proposer or disputer) receives on settlement. This amount includes
    /// the returned bonds as well as additional rewards.
    function settle(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external returns (uint256 payout);

    /// @notice Retrieves a price that was previously requested by a caller. Reverts if the request is not settled
    /// or settleable. Note: this method is not view so that this call may actually settle the price request if it
    /// hasn't been settled.
    /// @param identifier price identifier to identify the existing request.
    /// @param timestamp timestamp to identify the existing request.
    /// @param ancillaryData ancillary data of the price being requested.
    /// @return resolved price.
    ////
    function settleAndGetPrice(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external returns (int256);

    /// @notice Gets the current data structure containing all information about a price request.
    /// @param requester sender of the initial price request.
    /// @param identifier price identifier to identify the existing request.
    /// @param timestamp timestamp to identify the existing request.
    /// @param ancillaryData ancillary data of the price being requested.
    /// @return the Request data structure.
    ////
    function getRequest(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external view returns (Request memory);

    /// @notice Checks if a given request has resolved or been settled (i.e the optimistic oracle has a price).
    /// @param requester sender of the initial price request.
    /// @param identifier price identifier to identify the existing request.
    /// @param timestamp timestamp to identify the existing request.
    /// @param ancillaryData ancillary data of the price being requested.
    /// @return true if price has resolved or settled, false otherwise.
    function hasPrice(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external view returns (bool);

    function defaultLiveness() external view returns (uint256);
}

interface IFinder {
    function changeImplementationAddress(
        bytes32 interfaceName,
        address implementationAddress
    ) external;

    function getImplementationAddress(bytes32 interfaceName)
        external
        view
        returns (address);
}

interface IAddressWhitelist {
    function addToWhitelist(address) external;

    function removeFromWhitelist(address) external;

    function isOnWhitelist(address) external view returns (bool);

    function getWhitelist() external view returns (address[] memory);
}

library AncillaryDataLib {
    string private constant INITIALIZER_PREFIX = ",initializer:";

    /// @notice Appends the initializer address to the ancillaryData
    /// @param initializer      - The initializer address
    /// @param ancillaryData    - The ancillary data
    function _appendAncillaryData(
        address initializer,
        bytes memory ancillaryData
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                ancillaryData,
                INITIALIZER_PREFIX,
                _toUtf8BytesAddress(initializer)
            );
    }

    /// @notice Returns a UTF8-encoded address
    /// Source: UMA Protocol's AncillaryDataLib
    /// https://github.com/UMAprotocol/protocol/blob/9967e70e7db3f262fde0dc9d89ea04d4cd11ed97/packages/core/contracts/common/implementation/AncillaryData.sol
    /// Will return address in all lower case characters and without the leading 0x.
    /// @param addr - The address to encode.
    function _toUtf8BytesAddress(address addr)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodePacked(
                _toUtf8Bytes32Bottom(bytes32(bytes20(addr)) >> 128),
                bytes8(_toUtf8Bytes32Bottom(bytes20(addr)))
            );
    }

    /// @notice Converts the bottom half of a bytes32 input to hex in a highly gas-optimized way.
    /// Source: the brilliant implementation at https://gitter.im/ethereum/solidity?at=5840d23416207f7b0ed08c9b.
    function _toUtf8Bytes32Bottom(bytes32 bytesIn)
        private
        pure
        returns (bytes32)
    {
        unchecked {
            uint256 x = uint256(bytesIn);

            // Nibble interleave
            x =
                x &
                0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;
            x =
                (x | (x * 2**64)) &
                0x0000000000000000ffffffffffffffff0000000000000000ffffffffffffffff;
            x =
                (x | (x * 2**32)) &
                0x00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff;
            x =
                (x | (x * 2**16)) &
                0x0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff;
            x =
                (x | (x * 2**8)) &
                0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff;
            x =
                (x | (x * 2**4)) &
                0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f;

            // Hex encode
            uint256 h = (x &
                0x0808080808080808080808080808080808080808080808080808080808080808) /
                8;
            uint256 i = (x &
                0x0404040404040404040404040404040404040404040404040404040404040404) /
                4;
            uint256 j = (x &
                0x0202020202020202020202020202020202020202020202020202020202020202) /
                2;
            x =
                x +
                (h & (i | j)) *
                0x27 +
                0x3030303030303030303030303030303030303030303030303030303030303030;

            // Return the result.
            return bytes32(x);
        }
    }
}

struct QuestionData {
    /// @notice Request timestamp, set when a request is made to the Optimistic Oracle
    /// @dev Used to identify the request and NOT used by the DVM to determine validity
    uint256 requestTimestamp;
    /// @notice Reward offered to a successful proposer
    uint256 reward;
    /// @notice Additional bond required by Optimistic oracle proposers/disputers
    uint256 proposalBond;
    /// @notice Custom liveness period
    uint256 liveness;
    /// @notice Emergency resolution timestamp, set when a market is flagged for emergency resolution
    uint256 emergencyResolutionTimestamp;
    /// @notice Flag marking whether a question is resolved
    bool resolved;
    /// @notice Flag marking whether a question is paused
    bool paused;
    /// @notice Flag marking whether a question has been reset. A question can only be reset once
    bool reset;
    /// @notice Flag marking whether a question's reward should be refunded.
    bool refund;
    /// @notice ERC20 token address used for payment of rewards, proposal bonds and fees
    address rewardToken;
    /// @notice The address of the question creator
    address creator;
    /// @notice Data used to resolve a condition
    bytes ancillaryData;
}

interface IConditionalTokens {
    /// Mapping key is an condition ID. Value represents numerators of the payout vector associated with the condition. This array is initialized with a length equal to the outcome slot count. E.g. Condition with 3 outcomes [A, B, C] and two of those correct [0.5, 0.5, 0]. In Ethereum there are no decimal values, so here, 0.5 is represented by fractions like 1/2 == 0.5. That's why we need numerator and denominator values. Payout numerators are also used as a check of initialization. If the numerators array is empty (has length zero), the condition was not created/prepared. See getOutcomeSlotCount.
    function payoutNumerators(bytes32) external returns (uint256[] memory);

    /// Denominator is also used for checking if the condition has been resolved. If the denominator is non-zero, then the condition has been resolved.
    function payoutDenominator(bytes32) external returns (uint256);

    /// @dev This function prepares a condition by initializing a payout vector associated with the condition.
    /// @param oracle The account assigned to report the result for the prepared condition.
    /// @param questionId An identifier for the question to be answered by the oracle.
    /// @param outcomeSlotCount The number of outcome slots which should be used for this condition. Must not exceed 256.
    function prepareCondition(
        address oracle,
        bytes32 questionId,
        uint256 outcomeSlotCount
    ) external;

    /// @dev Called by the oracle for reporting results of conditions. Will set the payout vector for the condition with the ID ``keccak256(abi.encodePacked(oracle, questionId, outcomeSlotCount))``, where oracle is the message sender, questionId is one of the parameters of this function, and outcomeSlotCount is the length of the payouts parameter, which contains the payoutNumerators for each outcome slot of the condition.
    /// @param questionId The question ID the oracle is answering for
    /// @param payouts The oracle's answer
    function reportPayouts(bytes32 questionId, uint256[] calldata payouts)
        external;

    /// @dev This function splits a position. If splitting from the collateral, this contract will attempt to transfer `amount` collateral from the message sender to itself. Otherwise, this contract will burn `amount` stake held by the message sender in the position being split worth of EIP 1155 tokens. Regardless, if successful, `amount` stake will be minted in the split target positions. If any of the transfers, mints, or burns fail, the transaction will revert. The transaction will also revert if the given partition is trivial, invalid, or refers to more slots than the condition is prepared with.
    /// @param collateralToken The address of the positions' backing collateral token.
    /// @param parentCollectionId The ID of the outcome collections common to the position being split and the split target positions. May be null, in which only the collateral is shared.
    /// @param conditionId The ID of the condition to split on.
    /// @param partition An array of disjoint index sets representing a nontrivial partition of the outcome slots of the given condition. E.g. A|B and C but not A|B and B|C (is not disjoint). Each element's a number which, together with the condition, represents the outcome collection. E.g. 0b110 is A|B, 0b010 is B, etc.
    /// @param amount The amount of collateral or stake to split.
    function splitPosition(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external;

    function mergePositions(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external;

    function redeemPositions(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata indexSets
    ) external;

    /// @dev Gets the outcome slot count of a condition.
    /// @param conditionId ID of the condition.
    /// @return Number of outcome slots associated with a condition, or zero if condition has not been prepared yet.
    function getOutcomeSlotCount(bytes32 conditionId)
        external
        view
        returns (uint256);

    /// @dev Constructs a condition ID from an oracle, a question ID, and the outcome slot count for the question.
    /// @param oracle The account assigned to report the result for the prepared condition.
    /// @param questionId An identifier for the question to be answered by the oracle.
    /// @param outcomeSlotCount The number of outcome slots which should be used for this condition. Must not exceed 256.
    function getConditionId(
        address oracle,
        bytes32 questionId,
        uint256 outcomeSlotCount
    ) external pure returns (bytes32);

    /// @dev Constructs an outcome collection ID from a parent collection and an outcome collection.
    /// @param parentCollectionId Collection ID of the parent outcome collection, or bytes32(0) if there's no parent.
    /// @param conditionId Condition ID of the outcome collection to combine with the parent outcome collection.
    /// @param indexSet Index set of the outcome collection to combine with the parent outcome collection.
    function getCollectionId(
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256 indexSet
    ) external view returns (bytes32);

    /// @dev Constructs a position ID from a collateral token and an outcome collection. These IDs are used as the ERC-1155 ID for this contract.
    /// @param collateralToken Collateral token which backs the position.
    /// @param collectionId ID of the outcome collection associated with this position.
    function getPositionId(IERC20 collateralToken, bytes32 collectionId)
        external
        pure
        returns (uint256);
}

library TransferHelper {
    /// @notice Transfers tokens from the targeted address to the given destination
    /// @param token    - The contract address of the token to be transferred
    /// @param from     - The originating address from which the tokens will be transferred
    /// @param to       - The destination address of the transfer
    /// @param amount   - The amount to be transferred
    function _transferFromERC20(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        SafeTransferLib.safeTransferFrom(ERC20(token), from, to, amount);
    }

    /// @notice Transfers tokens from the current address to the given destination
    /// @param token    - The contract address of the token to be transferred
    /// @param to       - The destination address of the transfer
    /// @param amount   - The amount to be transferred
    function _transfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        SafeTransferLib.safeTransfer(ERC20(token), to, amount);
    }
}
