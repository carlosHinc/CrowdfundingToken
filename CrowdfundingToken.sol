// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.24;

import "./node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract CrowdfundingToken  is ERC20, Ownable {

    // Structs and Enums
    enum Status {
        ACTIVE,
        INACTIVE,
        COMPLETED,
        CANCELLED
    }

    struct Campaign {
        address creator;        
        string name;
        string description;
        uint256 goal;
        uint256 collected;
        uint256 deadline;
        bool claimed;
        Status status;
        uint256 minContribution;
    }

    struct Contributor {
        uint256 totalContributed;
        uint256 tokensEarned;
        
    }


    // CONSTANTS 
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10**18;
    uint256 public constant MAX_FEE = 10;
    uint256 public constant WEI_PER_ETH = 10**18;
    uint256 public constant TOKENS_PER_ETH = 100 * WEI_PER_ETH;

    // State Variables

    mapping(string nameCampaing => bool exists) public nameRegisteredCampaigns;
    mapping(string nameCampaing => uint256 idCampaing) public campaignNameToId;
    Campaign[] public campaigns;

    mapping(uint256 campaignId => mapping(address contributor =>  uint256 amountETH)) public contributions;

    mapping(address => Contributor) public contributors;

    uint256 private platformFee = 3;
    bool public platformPaused = false;

    constructor(
        string memory _name, 
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {}

    // Custom Errors
    error ZeroMinContribution();
    error BelowMinimum(uint256 sent, uint256 required);
    error NotActive();
    error Ended();
    error ExceedsMaxSupply(uint256 requested, uint256 available);
    error CampaignNameExists(string name);
    error PlatformPaused();
    error CampaignNotFound();
    error NotCampaignOwner();
    error IncompleteCampaign();
    error ClaimedCampaign();
    error FeeNotAllowed();
    error GoalGreaterThanMinimumContribution();


    // Modifiers
    modifier campaignExists(uint256 campaignId) {
        if (campaignId >= campaigns.length) revert CampaignNotFound();
        _;
    }
    
    modifier whenNotPaused() {
        if (platformPaused) revert PlatformPaused();
        _;
    }

    modifier onlyCampaignCreator(uint256 _campaignId) {
        if (campaigns[_campaignId].creator != msg.sender) revert NotCampaignOwner();
        _;
    }

    // Events

    event AddCampaingEvent(
        address creator,        
        string name,           
        string description,     
        uint256 goal,           
        uint256 deadline,       
        uint256 minContribution
    );

    event ContributionEvent(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount,
        uint256 tokensRewarded
    );

    event ClaimFundsEvent(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 creatorAmount,
        uint256 feeAmount,
        uint256 date
    );

    // External functions
    function addCampaing(
        address _creator, 
        string memory _name, 
        string memory _description, 
        uint256 _goal,
        uint256 _durationDays,                  
        uint256 _minContribution
    ) public {
        uint256 deadline = block.timestamp + (_durationDays * 1 days);

        Campaign memory newCmapaing = Campaign(
            _creator,
            _name,
            _description,
            _goal,
            0,
            deadline,
            false,
            Status.ACTIVE,
            _minContribution
        );
        _addCampaing(newCmapaing);
    }

    function contribute(uint256 _campaignId) 
        public 
        payable
    {
        _contribute(_campaignId);
    }

    function pausePlatform() public {
        _pausePlatform();
    }

     function claimFunds(uint256 _campaignId) public {
        _claimFunds(_campaignId);
    }

    function changeFee(uint256 _newFee) public {
        _changeFee(_newFee);
    }

    function unpausePlatform() external onlyOwner  {
        platformPaused = false;
    }



    // Internal functions
    function _changeFee(uint256 _newFee) internal onlyOwner {
        if(_newFee > MAX_FEE) revert FeeNotAllowed();

        platformFee = _newFee;
    }

    function _claimFunds(uint256 _campaignId) internal onlyCampaignCreator(_campaignId) {
        Campaign storage campaing = campaigns[_campaignId];

        if(campaing.claimed) revert ClaimedCampaign();
        if(campaing.status != Status.COMPLETED) revert IncompleteCampaign();

        uint256 fee = (campaing.collected * platformFee) / 100;
        uint256 creatorAmount = campaing.collected - fee;
        
        campaing.claimed = true;

        payable(campaing.creator).transfer(creatorAmount);
        payable(owner()).transfer(fee);

        emit ClaimFundsEvent(_campaignId, campaing.creator, creatorAmount, fee, block.timestamp);
    }

    function _pausePlatform() internal onlyOwner  {
        platformPaused = true;
    }

    function _addCampaing(Campaign memory _campaing) internal whenNotPaused {
        if (nameRegisteredCampaigns[_campaing.name]) 
            revert CampaignNameExists(_campaing.name);
        
        if(_campaing.minContribution < 1) revert ZeroMinContribution();

        if(_campaing.goal < _campaing.minContribution) revert GoalGreaterThanMinimumContribution();

        campaigns.push(_campaing);

        uint256 _idNewCampaign = campaigns.length - 1;
        nameRegisteredCampaigns[_campaing.name] = true;
        campaignNameToId[_campaing.name] = _idNewCampaign;

        emit AddCampaingEvent(
            _campaing.creator, 
            _campaing.name, 
            _campaing.description, 
            _campaing.goal, 
            _campaing.deadline,
            _campaing.minContribution 
        );
    }   

    function _contribute(uint256 _campaignId) internal whenNotPaused campaignExists(_campaignId) {
        uint256 amount = msg.value;
        address contributor = msg.sender;
        Campaign storage campaign = campaigns[_campaignId];
        Contributor storage contributorData = contributors[contributor];

        if (amount < campaign.minContribution) revert BelowMinimum(amount, campaign.minContribution);
        if (campaign.status != Status.ACTIVE) revert NotActive();
        if (block.timestamp >= campaign.deadline) revert Ended();

        uint256 tokensToReward = (amount * TOKENS_PER_ETH) / WEI_PER_ETH;
        if (totalSupply() + tokensToReward > MAX_SUPPLY) revert ExceedsMaxSupply(tokensToReward, MAX_SUPPLY);


        unchecked {
            campaign.collected += amount;
            contributorData.totalContributed += amount;
            contributions[_campaignId][contributor] += amount;
            if (tokensToReward > 0) {
                contributorData.tokensEarned += tokensToReward;
            }
        }

        if (campaign.collected >= campaign.goal) {
            campaign.status = Status.COMPLETED;
        }        


        if (tokensToReward > 0) {
            _mint(contributor, tokensToReward);
        }

        emit ContributionEvent(_campaignId, contributor, amount, tokensToReward);
    }



}