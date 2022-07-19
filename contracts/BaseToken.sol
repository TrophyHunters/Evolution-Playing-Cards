pragma solidity ^0.8.6;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IMembershipToken.sol";
import "./interfaces/IBaseToken.sol";
import "./interfaces/ICombinationToken.sol";
import "./library/CombinableTokenBasis.sol";

contract BaseToken is IBaseToken, CombinableTokenBasis, ReentrancyGuard {
    //    using EC
    // <DATA STRUCTS>

    /** @notice A structure to store main token properties used to mint Combination NFT */
    struct BaseTokenMainTraits {
        /** Material values
            | 1 = Classic | 8 = Titan        |
            | 2 = Gold    | 16 = Unicellular  |
            | 4 = Renim   | 32 = Veganleather |
        */
        uint8 Material;

        /** Edging values
            | 1 = Classic | 8 = Ornament  |
            | 2 = DNA     | 16 = Shabby    |
            | 4 = French  | 32 = Textline  |
        */
        uint8 Edging;

        /** Suit values
            | 1 = Clubs    | 4 = Hearts |
            | 2 = Diamonds | 8 = Spades |
        */
        uint8 Suit;

        /** Rank values
            | 1 = A  | 32 = 6   | 1024 = J |
            | 2 = 2  | 64 = 7   | 2048 = Q |
            | 4 = 3  | 128 = 8  | 4096 = K |
            | 8 = 4  | 256 = 9  |          |
            | 16 = 5 | 512 = 10 |          |
        */
        uint16 Rank;
    }
    // < /DATA STRUCTS>

    // <VARIABLES>
    // Base NFT price in Ether during main sale
    uint256 public constant price = 0.09 ether;
    // Base NFT price in Ether during presale
    uint256 public constant presalePrice = 0.055 ether;
    // Contract address where Reward Fund is accumulated during main sale
    address public rewardPool;
    // Part of Base token price to send to Reward Fund during main sale
    uint256 public rewardShare = 0.035 ether;
    // Part of Base token price to send to Reward Fund during presale
    uint256 public rewardSharePresale = 0.035 ether;
    // Max total supply and last token ID
    uint256 public maxTotalSupply = 5_715;

    bool public isInitialized;

    // Membership token contract
    IMembershipToken public membershipToken;

    // An array where are stored main traits for each Base token
    BaseTokenMainTraits[] internal baseTokenMainTraits_;

    uint256 internal randomNonce_;

    /** Timing variables */
    // A variable to store a timestamp when public sale will become available
    uint256 public saleStartTime;
    // Time when presale starts
    uint256 public presaleStartTime;
    // Time when presale ends
    uint256 public presaleEndTime;

    uint256 public constant presaleTokensAmountPerAddress = 1;
    mapping(address => uint256) public presaleTokensAmountByAddress;
    mapping(address => bool) public presaleWhitelist;

    // </ VARIABLES >

    // <EVENTS>
    event PublicSaleMint(address to, uint256 tokenId, uint8 material, uint8 edging, uint8 suit, uint16 rank);
    event PresaleMint(address to, uint256 tokenId, uint8 material, uint8 edging, uint8 suit, uint16 rank);

    // restricted events
    event Initialize(address membershipToken, address childAddress);

    event SetSaleStartTime(uint256 timestamp);
    event SetPresaleStartTime(uint256 timestamp);
    event SetPresaleEndTime(uint256 timestamp);

    event SetMaxTotalSupply(uint256 newMaxTotalSupply);
    event SetPresaleWhitelistAddress(address addr, bool whitelisted);
    event SoldOut();
    // </ EVENTS>

    /**
        @notice A constructor function is executed once when a contract is created and it is used to initialize
                contract state.
        @param _proxyRegistry - wyvern proxy for secondary sales on Opensea (cannot be changed after)
        @param _name - base token name (cannot be changed after)
        @param _symbol - base token symbol (cannot be changed after)
        @param _baseURI - base token address where NFT images are stored
        @param _contractURI - base token contract metadata URI
        @param _paymentToken - Wrapped ETH (WETH) token contract address for secondary sales (cannot be changed after)
    */
    constructor(
        address _proxyRegistry,
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        string memory _contractURI,
        address _paymentToken
    )
    CombinableTokenBasis(
        _proxyRegistry,
        _name,
        _symbol,
        _baseURI,
        _contractURI,
        _paymentToken
    )
    ReentrancyGuard()
    {
    }

    // <INTERNAL FUNCTIONS TO GET CONSTANTS INTERNALLY>

    /**
        @notice A function to serve constant maxTotalSupply
        @dev Function was created for dev purposes, to make proper testing simpler
        @return constant maxTotalSupply variable
    */
    function _maxTotalSupply() internal view virtual returns (uint256) {
        return maxTotalSupply;
    }

    /**
        @notice A function to serve constant price
        @dev Function was created for dev purposes, to make proper testing simpler
        @return constant price variable
    */
    function _price() internal view virtual returns (uint256) {
        return price;
    }

    /**
        @notice A function to serve constant rewardShare
        @dev Function was created for dev purposes, to make proper testing simpler
        @return constant rewardShare variable
    */
    function _rewardShare() internal view virtual returns (uint256) {
        return rewardShare;
    }

    /**
        @notice A function to serve constant presale price
        @dev Function was created for dev purposes, to make proper testing simpler
        @return constant presale price variable
    */
    function _presalePrice() internal view virtual returns (uint256) {
        return presalePrice;
    }

    /**
        @notice A function to serve constant rewardSharePresale
        @dev Function was created for dev purposes, to make proper testing simpler
        @return constant rewardSharePresale variable
    */
    function _rewardSharePresale() internal view virtual returns (uint256) {
        return rewardSharePresale;
    }

    function _presaleTokensAmountPerAddress() internal view virtual returns (uint256) {
        return presaleTokensAmountPerAddress;
    }

    /**
        @notice A function to initialize contract and set Membership and Combination token addresses
        @dev Called only once, an attempt to call it repeatedly will be rejected,
             all variables set in this function cannot be changed after
        @param _membershipToken - Membership token address (cannot be changed after)
        @param _childAddress - Combination token address (cannot be changed after)
    */
    function initialize(address _membershipToken, address _childAddress)
    external
    override
    onlyOwner
    {
        require(!isInitialized, "BaseToken: contract is already initialized!");
        membershipToken = IMembershipToken(_membershipToken);
        child_ = ICombinationToken(_childAddress);
        rewardPool = _childAddress;
        isInitialized = true;

        emit Initialize(_membershipToken, _childAddress);
    }

    // <MODIFIERS>
    /**
        @notice A modifier which is automatically called before publicSaleMint body execution
        @param _amount - amount of tokens to mint
    */
    modifier beforePublicSaleMint(uint256 _amount) {
        address _txSender = msg.sender;
        uint256 _blockTimestamp = block.timestamp;

        require(
            _blockTimestamp > saleStartTime && saleStartTime != 0,
            "BaseToken: Main sale hasn't started yet"
        );
        require(
            lastTokenId_ + _amount <= _maxTotalSupply(),
            "BaseToken: Cannot mint more tokens than the maxTotalSupply"
        );
        _;
    }

    /**
        @notice A modifier which is automatically called before presaleMint body execution
        @param _amount - amount of tokens to mint
    */
    modifier beforePresaleMint(uint256 _amount) {
        address _txSender = msg.sender;
        uint256 _blockTimestamp = block.timestamp;

        require(
            (presaleStartTime < _blockTimestamp &&
        _blockTimestamp < presaleEndTime),
            "BaseToken: Presale is not active"
        );
        require(
            presaleWhitelist[_txSender],
            "BaseToken: You are not whitelisted"
        );
        require(
            presaleTokensAmountByAddress[_txSender] + _amount <=
            _presaleTokensAmountPerAddress(),
            "BaseToken: Amount of tokens exceeds presale limits"
        );
        presaleTokensAmountByAddress[_txSender] =
        presaleTokensAmountByAddress[_txSender] +
        _amount;
        require(
            lastTokenId_ + _amount <= _maxTotalSupply(),
            "BaseToken: Cannot mint more tokens than the maxTotalSupply"
        );
        _;
    }
    // </ MODIFIERS>

    // <PUBLIC FUNCTIONS>
    /**
        @notice A function to buy (mint) base tokens
        @param _to - recipient address (usually the same as the address of transaction sender)
        @param _amount - amount of tokens to mint
        @param _mintMembership - true/false need to mint Membership token or not
        @param _userRandomNumber - random number entered by the buyer, used for main properties generation
    */
    function publicSaleMint(
        address _to,
        uint256 _amount,
        bool _mintMembership,
        uint16 _userRandomNumber
    ) external payable override beforePublicSaleMint(_amount) {
        uint256 _msgValue = msg.value;
        require(
            _msgValue >= _price() * _amount,
            "BaseToken: tx value is too small"
        );
        require(_amount <= 13, "BaseToken: Cannot buy more tokens than 13");
        if (address(membershipToken) != address(0x0) && _mintMembership) {
            membershipToken.mint(_to);
        }

        payable(rewardPool).transfer(_amount * _rewardShare());
        _mintTokens(_to, _amount, _userRandomNumber);
    }

    /**
        @notice A function to buy (mint) base tokens during presale period
        @param _to - recipient address (usually the same as the address of transaction sender)
        @param _amount - amount of tokens to mint
        @param _mintMembership - true/false need to mint Membership token or not
        @param _userRandomNumber - random number entered by the buyer, used for main properties generation
    */
    function presaleMint(
        address _to,
        uint256 _amount,
        bool _mintMembership,
        uint16 _userRandomNumber
    ) external payable override beforePresaleMint(_amount) {
        uint256 _msgValue = msg.value;
        require(
            _msgValue >= _presalePrice() * _amount,
            "BaseToken: tx value is too small"
        );
        if (address(membershipToken) != address(0x0) && _mintMembership) {
            membershipToken.mint(_to);
        }

        payable(rewardPool).transfer(_amount * _rewardSharePresale());
        _mintTokens(_to, _amount, _userRandomNumber);
    }

    /**
        @dev A simple getter for Base token main traits
    */
    function baseTokenMainTraits(uint256 _tokenId) external view override returns (uint8, uint8, uint8, uint16){
        uint256 _index = _tokenId - 1;
        return (baseTokenMainTraits_[_index].Material,
        baseTokenMainTraits_[_index].Edging,
        baseTokenMainTraits_[_index].Suit,
        baseTokenMainTraits_[_index].Rank);
    }
    // </ PUBLIC FUNCTIONS>

    // <PRIVATE FUNCTIONS>
    /**
        @notice Internal function called by _mintTokens to generate token main properties
        @dev For random generation of main properties, function uses data from three sources:
             - from the holder (a random number from 1 to 100)
             - from the blockchain (block.timestamp, block.difficulty, block.number)
             - from the smart contract (randomNonce_)
        @dev Function randomly generates Material, Edging, Suit, Rank and writes them to
             baseTokenMainTraits_ array to store on-chain (these properties can never be changed)
        @param _tokenId - Id of newly minted token
        @param _userRandomNumber - Random number sent by user
    */
    function _generateBaseTokenMainTraits(
        uint256 _tokenId,
        uint16 _userRandomNumber
    ) internal returns (uint8, uint8, uint8, uint16){
        require(
            1 <= _userRandomNumber && _userRandomNumber <= 100,
            "BaseToken: user random number has to be in 1 <= x <= 100"
        );
        uint256 _blockTimestamp = block.timestamp;
        uint256 _blockDifficulty = block.timestamp;
        uint256 _blockNumber = block.number;
        BaseTokenMainTraits memory _baseTokenMainTraits = BaseTokenMainTraits(0, 0, 0, 0);

        // random nonce increased
        randomNonce_ += (_tokenId > 1)
        ? baseTokenMainTraits_[_tokenId - 2].Rank
        : _userRandomNumber;

        _baseTokenMainTraits.Material = uint8(
            2 **
            (uint256(
                keccak256(
                    abi.encodePacked(
                        _blockNumber,
                        _blockTimestamp,
                        _blockDifficulty,
                        msg.sender,
                        randomNonce_,
                        _userRandomNumber
                    )
                )
            ) % 6)
        );

        // random nonce increased
        randomNonce_ += (_tokenId > 1)
        ? baseTokenMainTraits_[_tokenId - 2].Suit
        : _userRandomNumber;

        _baseTokenMainTraits.Edging = uint8(
            2 **
            (uint256(
                keccak256(
                    abi.encodePacked(
                        _blockNumber,
                        _blockTimestamp,
                        _blockDifficulty,
                        msg.sender,
                        randomNonce_,
                        _userRandomNumber
                    )
                )
            ) % 6)
        );

        // random nonce increased
        randomNonce_ += (_tokenId > 1)
        ? baseTokenMainTraits_[_tokenId - 2].Material
        : _userRandomNumber;

        _baseTokenMainTraits.Suit = uint8(
            2 **
            (uint256(
                keccak256(
                    abi.encodePacked(
                        _blockNumber,
                        _blockTimestamp,
                        _blockDifficulty,
                        msg.sender,
                        randomNonce_,
                        _userRandomNumber
                    )
                )
            ) % 4)
        );

        // random nonce increased
        randomNonce_ += (_tokenId > 1)
        ? baseTokenMainTraits_[_tokenId - 2].Edging
        : _userRandomNumber;

        _baseTokenMainTraits.Rank = uint16(
            2 **
            (uint256(
                keccak256(
                    abi.encodePacked(
                        _blockNumber,
                        _blockTimestamp,
                        _blockDifficulty,
                        msg.sender,
                        randomNonce_,
                        _userRandomNumber
                    )
                )
            ) % 13)
        );

        baseTokenMainTraits_.push(_baseTokenMainTraits);

        return (_baseTokenMainTraits.Material, _baseTokenMainTraits.Edging, _baseTokenMainTraits.Suit, _baseTokenMainTraits.Rank);
    }

    /**
        @notice Internal function called by publicSaleMint to mint tokens
        @dev Function calls _generateBaseTokenMainTraits to generate Base token main traits
        @dev When 10k Base NFTs are minted, this funciton will automatically set:
            - startMintTrophyTime (time of the start of the Trophy Combination NFT poll)
            - endMintTrophyTime (time of the completion of the Trophy Combination NFT poll and the start of voting)
            - endVotingTime (time of the end of voting)
        @param _to - recipient address (usually the same as the address of transaction sender)
        @param _amount - amount of tokens to mint
        @param _userRandomNumber - random number entered by the buyer, used for main properties generation
    */
    function _mintTokens(
        address _to,
        uint256 _amount,
        uint16 _userRandomNumber
    ) private {
        uint256 _newLastTokenId = lastTokenId_ + _amount;
        uint256 _blockTimestamp = block.timestamp;

        for (
            uint256 _tokenId = lastTokenId_ + 1;
            _tokenId <= _newLastTokenId;
            _tokenId++
        ) {
            _mint(_to, _tokenId);
            (uint8 _material, uint8 _edging, uint8 _suit, uint16 _rank) = _generateBaseTokenMainTraits(_tokenId, _userRandomNumber);
            if (
                (presaleStartTime < _blockTimestamp &&
            _blockTimestamp < presaleEndTime)
            ) {
                emit PresaleMint(_to, _tokenId, _material, _edging, _suit, _rank);
            } else {
                emit PublicSaleMint(_to, _tokenId, _material, _edging, _suit, _rank);
            }
        }
        lastTokenId_ += _amount;
        if (lastTokenId_ == _maxTotalSupply()) {
            soldOut_ = true;

            emit SoldOut();
        }
    }
    // </ PRIVATE FUNCTIONS />

    // <RESTRICTED ACCESS METHODS>


    function setPresaleWhitelistAddresses(address[] memory _addresses, bool _whitelisted)
    external
    override
    onlyOwner
    {
        for (uint256 index = 0; index < _addresses.length; index++) {
            presaleWhitelist[_addresses[index]] = _whitelisted;
            emit SetPresaleWhitelistAddress(_addresses[index], _whitelisted);
        }
    }

    /**
        @notice Sale start time setter function
        @dev Available for owner only
        @dev Impossible to set new time if current sale start time is up
        @param _saleStartTime - new sale start time
    */
    function setSaleStartTime(uint256 _saleStartTime)
    external
    override
    virtual
    onlyOwner
    {
        require(_saleStartTime > block.timestamp, "BaseToken: new sale start time should be in future");
        require(saleStartTime == 0 || saleStartTime > block.timestamp, "BaseToken: sale shouldn't be started");

        saleStartTime = _saleStartTime;

        emit SetSaleStartTime(_saleStartTime);
    }


    function setPresaleTime(uint256 _presaleStartTime, uint256 _presaleEndTime)
    external
    override
    virtual
    onlyOwner
    {
        require(_presaleStartTime > 0 &&
            _presaleStartTime > block.timestamp,
            "BaseToken: Invalid presale start time");
        require(_presaleStartTime < _presaleEndTime,
            "BaseToken: presale_start_time > presale_end_time");
        require(_presaleEndTime < saleStartTime,
            "BaseToken: presale_end_time > sale_start_time");

        presaleStartTime = _presaleStartTime;
        presaleEndTime = _presaleEndTime;

        emit SetPresaleStartTime(_presaleStartTime);
        emit SetPresaleEndTime(_presaleEndTime);
    }

    function setMaxTotalSupply(uint256 _newMaxTotalSupply) external virtual onlyOwner {
        maxTotalSupply = _newMaxTotalSupply;

        emit SetMaxTotalSupply(_newMaxTotalSupply);
    }

    /**
        @notice Used to protect Owner from shooting himself in a foot
        @dev This function overrides same-named function from Ownable
             library and makes it an empty one
    */
    function renounceOwnership() public override onlyOwner {}
    // </ RESTRICTED ACCESS FUNCTIONS>
}
