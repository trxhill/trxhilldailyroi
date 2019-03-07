pragma solidity >=0.4.22 <0.6.0;

import "./SafeMath.sol";

contract TrxHill {
   

    using SafeMath for uint256;
   
    uint32 number_of_investors;
    
    uint8 public i_precision = 18;
    uint8 public tron_precision = 6;
    
    address dev_address;
    address owner;
    
    uint256 dev_support_percent = 3;
    uint256 referral_bonus_percent = 7;
    uint256 min_investment = 10;
    
    
    struct Investor{
        bool hasInvested;
        uint256 totalInvestment;
        uint256 last_blockNumber;
        uint256 dividend_calculation_time;
    }
    
    struct DividendWithdrawal{
        uint256 totalWithdrawal;    
        uint40 withdraw_count;   
    }
    
    
    struct InvitedAccounts{
        address[] invitees;
    }
    
    struct Invitation{
        address inviter;
        uint256 referred_time;
        bool referred_status;
    }
    
    mapping (address=>Investor) investor_map;
    mapping (address=>DividendWithdrawal) withdrawal_map;
    
    mapping(address => Invitation) invitation_details;
    mapping(address => InvitedAccounts) invitee_list; 
    mapping(address => uint256) referralBonus;
    
    event Invested(address investor,uint256 amount);
    event Withdrawn(address investor,uint256 amount);
    event ReferralSet(address indexed inviter, address indexed invitee);
    
    
   constructor() public {
        owner = msg.sender;
    }

    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
  
    function getTotalInvestors() public view returns (uint32){
        return number_of_investors;
    }
  
 
    function invest(address _inviter_address) public payable returns (bool){
        
      require(msg.value >= (min_investment * 10 ** 6),"Investment Problem");
       setReferral(_inviter_address);
          
      if(!isInvestor(msg.sender)){
          investor_map[msg.sender].hasInvested = true;
          number_of_investors ++;
      }
      
      
       if(hasInviter(msg.sender)){
          address _inviter_person = getInviter(msg.sender);
          referralBonus[_inviter_person] = referralBonus[_inviter_person].add((msg.value * referral_bonus_percent)/100);
       }
       
      dev_address.transfer((msg.value * dev_support_percent)/100); // 3
      
      investor_map[msg.sender].last_blockNumber = block.number;
      investor_map[msg.sender].dividend_calculation_time = now;
      
      // if investment added again,add the collected divs to total investmap
      investor_map[msg.sender].totalInvestment = investor_map[msg.sender].totalInvestment.add(getDividendCollection(msg.sender));
      investor_map[msg.sender].totalInvestment = (investor_map[msg.sender].totalInvestment).add(msg.value);
     
      
      emit Invested(msg.sender,msg.value);
      return true;
    }
    
    
    function isInvestor(address _address) internal view returns (bool){
        return investor_map[_address].hasInvested;
    }
    
    function getTotalInvestedAmount(address _address) public view returns (uint256){
        return investor_map[_address].totalInvestment;
    }
    
    function getInvestorOtherInfo(address _address) public view returns(uint256,uint256){
        return (investor_map[_address].last_blockNumber,investor_map[_address].dividend_calculation_time);
    }
    
    
    function getDividendCollection(address _investor) public view returns (uint256){
       uint256 total_investment = getTotalInvestedAmount(_investor);
      
       if(total_investment > 0){
          uint256 time_diff = now.sub(investor_map[_investor].dividend_calculation_time);
          uint256 collected_dividend = getCollectedDividend(total_investment,time_diff);
          return collected_dividend;
       }else{
        return 0;
       }
    }
    
    
    function withdrawDivCollection() public returns (bool){
        
        require(getTotalInvestedAmount(msg.sender) != 0,'Must Have Some Investment');
        require(block.number > investor_map[msg.sender].last_blockNumber,"Cannot Travel To Past");
       
        uint256 collected_dividend = getDividendCollection(msg.sender);
      
        investor_map[msg.sender].last_blockNumber = block.number;
        investor_map[msg.sender].dividend_calculation_time = now;
        
        withdrawal_map[msg.sender].totalWithdrawal = (withdrawal_map[msg.sender].totalWithdrawal).add(collected_dividend); // get the caller's dividend
        withdrawal_map[msg.sender].withdraw_count++;
        
        
        msg.sender.transfer(collected_dividend);
        
        emit Withdrawn(msg.sender,collected_dividend);
        return true;
    }
    

    function getWithDrawInfo(address _address) public view returns (uint256,uint40){
        return (withdrawal_map[_address].totalWithdrawal,withdrawal_map[_address].withdraw_count);
    }
    
    
    function reInvestDividends() public returns (bool){
        
       uint256 collected_dividend = getDividendCollection(msg.sender);
       require(collected_dividend != 0,'No Dividend Collection Yet');
     
       investor_map[msg.sender].last_blockNumber = block.number;
       investor_map[msg.sender].dividend_calculation_time = now;
       investor_map[msg.sender].totalInvestment = (investor_map[msg.sender].totalInvestment).add(collected_dividend);
    
       return true;
    }
    

    function setReferral(address _inviter)  private  {
     
     if(_inviter != address(0) && 
      _inviter != msg.sender && 
      countInviteesOf(msg.sender) == 0 &&
      !invitation_details[msg.sender].referred_status
      && investor_map[msg.sender].hasInvested == false 
     ){
         
       invitation_details[msg.sender] = Invitation(_inviter,now,true); 
       invitee_list[_inviter].invitees.push(msg.sender);
       emit ReferralSet(_inviter,msg.sender);
    }
    
     }
   
   
     function getInviter(address _child) public  view returns(address){
        return invitation_details[_child].inviter;
     }
   
     function hasInviter(address _child) public view returns(bool){
       return (getInviter(_child) != address(0));
     }
   
  
     function countInviteesOf(address _address) public view returns (uint256){
       return invitee_list[_address].invitees.length;
     }
  
     function getReferralBonus(address _address) public view returns(uint256){
      return referralBonus[_address];
     }
     
    
     function withdrawRefBonus() public returns (bool){
       
        uint256 collected_ref_bonus = getReferralBonus(msg.sender);
        require(collected_ref_bonus != 0,'No Referral Bonus Yet');
        referralBonus[msg.sender] = 0;
        msg.sender.transfer(collected_ref_bonus);
        return true;
    }
     
     
     function reInvestReferralBonus() public returns (bool){
         
       uint256 collected_ref_bonus = getReferralBonus(msg.sender);
       require(collected_ref_bonus != 0,'No Referral Bonus Yet');

       require(collected_ref_bonus >= (min_investment * 10 ** 6),"Investment Problem");

       if(!isInvestor(msg.sender)){
            investor_map[msg.sender].hasInvested = true;
            number_of_investors ++;
       }
       
       uint256 collected_dividend = getDividendCollection(msg.sender);
       
       referralBonus[msg.sender] = 0;
       
       investor_map[msg.sender].last_blockNumber = block.number;
       investor_map[msg.sender].dividend_calculation_time = now;
       
       investor_map[msg.sender].totalInvestment = (investor_map[msg.sender].totalInvestment).add(collected_dividend);
       investor_map[msg.sender].totalInvestment = (investor_map[msg.sender].totalInvestment).add(collected_ref_bonus);
       
       emit Invested(msg.sender, collected_ref_bonus);
       return true;
       
     }
     
     function setDevAddress(address _dev_address) public onlyOwner returns(bool) {
        dev_address = _dev_address;
       return true; 
     }


     
      function getTronBase(uint256 numerator, uint256 denominator) internal view returns(uint256){
         uint256 _numerator  = numerator.mul(10 ** uint256(tron_precision));
         uint256 _quotient = _numerator.div(denominator);
         return _quotient;
     }
  
  
  function getDividendPerSecond(uint256 investment) internal view returns(uint256){
      
        if(investment >= 10 * 10 ** uint256(tron_precision) && investment <= 1999* 10 ** uint256(tron_precision)){
          uint256 div1_per_day =  ((investment * 10 ** 12 )  * 400/10000);
          return div1_per_day/86400;
        }
        if(investment >= 2000* 10 ** uint256(tron_precision) && investment <= 19999* 10 ** uint256(tron_precision)){
           uint256 div2_per_day =  ((investment * 10 ** 12 ) * 425/10000);
          return div2_per_day/86400;
        }
        if(investment >= 20000* 10 ** uint256(tron_precision) && investment <= 99999* 10 ** uint256(tron_precision)){
           uint256 div3_per_day =  ((investment * 10 ** 12 ) * 450/10000);
          return div3_per_day/86400;
        }
        
        if(investment >=100000* 10 ** uint256(tron_precision)){
           uint256 div4_per_day =  ((investment * 10 ** 12 ) * 475/10000);
          return div4_per_day/86400;
        }
    
  }
 
   function getCollectedDividend(uint256 investment,uint256 timediff) internal view  returns(uint256){
      uint256 divs_now = (timediff) * getDividendPerSecond(investment);
      uint256 divider = 1*10**uint256(i_precision);
      uint256 tron_divs = getTronBase(divs_now,divider);
      return tron_divs;
  }

  function getWalletBalance(address _address) public view returns(uint256){
    return _address.balance;
  }
  
   function getDevAddress() public onlyOwner view returns(address){
       return dev_address;
  }
  
     

}
