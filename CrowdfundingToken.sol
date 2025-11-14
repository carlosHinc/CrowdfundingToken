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
        string name;           // "Ayuda para mi emprendimiento"
        string description;     // Descripción larga
        uint256 goal;           // Meta en wei: 10 ETH = 10000000000000000000
        uint256 collected;         // Cuánto se ha recaudado
        uint256 deadline;       // Timestamp: 1699876543 (fecha límite)
        bool claimed;           // ¿Ya el creador retiró el dinero?
        Status status;            // ¿La campaña está activa?
        uint256 minContribution; // Contribución mínima (ej: 0.1 ETH)
    }

    struct Contributor {
        uint256 totalContributed; // Total que ha contribuido en todas las campañas
        uint256 tokensEarned;     // Tokens CFT ganados como recompensa
    }

    // CONSTANTS 
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10**18;
    uint256 public constant MAX_FEE = 10;  // Máximo permitido 10%
    uint256 public constant TOKENS_PER_ETH = 100 * 10**18;  // 100 tokens por 1 ETH

    // State Variables
    mapping(string nameCampaing => bool exists) public nameRegisteredCampaigns;
    mapping(string nameCampaing => uint256 idCampaing) public campaignNameToId;
    Campaign[] public campaigns;

    mapping(uint256 campaignId => mapping(address contributor =>  uint256 amountETH)) public contributions;

    // Perfil de cada contribuyente
    // contributors[0xABC...] = { totalContributed: 10 ETH, tokensEarned: 1000 CFT }
    mapping(address => Contributor) public contributors;

    uint256 public platformFee = 3;
    bool public platformPaused = false;

    constructor(
        string memory _name, 
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {

    }


    // Custom Errors
    error ZeroAmount();
    error BelowMinimum(uint256 sent, uint256 required);
    error NotActive();
    error Ended();
    error ExceedsMaxSupply(uint256 requested, uint256 available);
    error CampaignNameExists(string name);
    error PlatformPaused();
    error CampaignNotFound();


    // Modifiers
    modifier campaignExists(uint256 campaignId) {
        if (campaignId >= campaigns.length) revert CampaignNotFound();
        _;
    }
    
    modifier whenNotPaused() {
        if (platformPaused) revert PlatformPaused();
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

    function contribute(uint256 campaignId) 
        public 
        payable
        
    {
        _contribute(campaignId);
    }

    // Internal functions
    function _addCampaing(Campaign memory _campaing) internal {
        if (nameRegisteredCampaigns[_campaing.name]) 
            revert CampaignNameExists(_campaing.name);
        
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

    function _contribute(uint256 campaignId) internal whenNotPaused campaignExists(campaignId) {
        uint256 amount = msg.value;
        address contributor = msg.sender;
        Campaign storage campaign = campaigns[campaignId];

        if (amount < campaign.minContribution) revert BelowMinimum(amount, campaign.minContribution);
        if (campaign.status != Status.ACTIVE) revert NotActive();
        if (block.timestamp >= campaign.deadline) revert Ended();

        uint256 tokensToReward = (amount * TOKENS_PER_ETH) / 1 ether;
        if (totalSupply() + tokensToReward > MAX_SUPPLY) revert ExceedsMaxSupply(tokensToReward, MAX_SUPPLY);

        unchecked {
            campaign.collected += amount;
        }

        if (campaign.collected >= campaign.goal) {
            campaign.status = Status.COMPLETED;
        }        

        unchecked {       
            contributors[contributor].totalContributed += amount;
            contributions[campaignId][contributor] += amount;
        }

        if (tokensToReward > 0) {
            unchecked {
                contributors[contributor].tokensEarned += tokensToReward;
            }
            _mint(contributor, tokensToReward);
        }

        emit ContributionEvent(campaignId, contributor, amount, tokensToReward);
    }



}