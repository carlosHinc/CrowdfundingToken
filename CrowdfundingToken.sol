// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.24;

import "./node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract CrowdfundingToken  is ERC20, Ownable {

    uint256 public constant MAX_SUPPLY = 1_000_000 * 10**18;

    constructor(
        string memory _name, 
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        _mint(msg.sender, MAX_SUPPLY);
    }

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
        uint256 raised;         // Cuánto se ha recaudado
        uint256 deadline;       // Timestamp: 1699876543 (fecha límite)
        bool claimed;           // ¿Ya el creador retiró el dinero?
        Status status;            // ¿La campaña está activa?
        uint256 minContribution; // Contribución mínima (ej: 0.1 ETH)
    }

    struct Contributor {
        uint256 totalContributed; // Total que ha contribuido en todas las campañas
        uint256 tokensEarned;     // Tokens CFT ganados como recompensa
    }

    // State Variables
    mapping(string nameCampaing => bool exists) public nameRegisteredCampaigns;
    mapping(string nameCampaing => uint256 idCampaing) public campaignNameToId;
    Campaign[] public campaigns;

    mapping(uint256 campaignId => mapping(address contributor =>  uint256 amountETH)) public contributions;

    // Perfil de cada contribuyente
    // contributors[0xABC...] = { totalContributed: 10 ETH, tokensEarned: 1000 CFT }
    mapping(address => Contributor) public contributors;

    uint256 public platformFee = 3;  // 3% de comisión
    uint256 public constant MAX_FEE = 10;  // Máximo permitido 10%

    uint256 public tokensPerEth = 100 * 10**18;  // 100 tokens por 1 ETH

    bool public platformPaused = false;  // ¿Plataforma pausada?


    // Modifiers
    modifier uniqueCampaignName(string memory _campaignName) {
        require(!nameRegisteredCampaigns[_campaignName], "The campaign name already exists");
        _;
    }

    modifier campaignExists(uint256 campaignId) {
        require(campaignId < campaigns.length, "Campaign does not exist");
        _;
    }

    modifier whenNotPaused() {
        require(!platformPaused, "Platform paused");
        _;
    }

    // Events

    // External functions
    function addCampaing(
        address _creator, 
        string memory _name, 
        string memory _description, 
        uint256 _goal,
        uint256 _raised,        
        uint256 _durationDays,       
        bool _claimed,             
        uint256 _minContribution
    ) public {
        uint256 deadline = block.timestamp + (_durationDays * 1 days);

        Campaign memory newCmapaing = Campaign(
            _creator,
            _name,
            _description,
            _goal,
            _raised,
            deadline,
            _claimed,
            Status.ACTIVE,
            _minContribution
        );
        _addCampaing(newCmapaing);
    }

    function contribute(uint256 campaignId) 
        public 
        payable  // ← Puede recibir ETH
        whenNotPaused 
        campaignExists(campaignId) 
    {

    }



    // Internal functions
    function _addCampaing(Campaign memory campaing) internal uniqueCampaignName(campaing.name) {
        campaigns.push(campaing);

        uint256 _idNewCampaign = campaigns.length - 1;
        nameRegisteredCampaigns[campaing.name] = true;
        campaignNameToId[campaing.name] = _idNewCampaign;
    }   

    function _contribute() internal {
        
    }



}