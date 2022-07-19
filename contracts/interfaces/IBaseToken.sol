pragma solidity ^0.8.0;

import "./ICombinableTokenBasis.sol";

interface IBaseToken is ICombinableTokenBasis {
    function initialize(address _membershipToken, address _childAddress)
        external;

    function publicSaleMint(
        address _to,
        uint256 _amount,
        bool _mintMembership,
        uint16 _userRandomNumber
    ) external payable;

    function presaleMint(
        address _to,
        uint256 _amount,
        bool _mintMembership,
        uint16 _userRandomNumber
    ) external payable;

    function setPresaleWhitelistAddresses(address[] memory _addresses, bool _whitelisted)
        external;

    function setSaleStartTime(uint256 _saleStartTime) external;

    function setPresaleTime(uint256 _presaleStartTime, uint256 _presaleEndTime) external;

    function baseTokenMainTraits(uint256 _tokenId) external view returns (uint8, uint8, uint8, uint16);
}
