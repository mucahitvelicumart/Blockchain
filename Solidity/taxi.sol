// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Taxi{
    //State Variables

    address public owner;
    
    struct Participant{
        address payable addressParticipant;
        uint balance;
        uint dividendMoney;
        bool voteForBuy;
        bool voteForSell;
        bool voteForDriver;

    }

    struct Driver{
        address payable addressDriver;
        bool approved;
        uint salary;
        uint approvalState;
        uint balance;
    }

    struct proposedCar{
        uint32 carID;
        uint price;
        uint offerValidTime;
        uint approvalState;
    }

    address payable carDealer; //Car Dealer address
    uint public totalParticipantCount = 0;  //Number of total participants
    uint totalBalance = 0;  // Total balance of contract
    uint fixedTimeForTaxes = 180 days;  // 6 months
    uint fixedTotalTaxAmount = 5 ether; // Tax fee for car
    uint participationFee = 50 ether;   // participation fee 
    uint lastTaxPayment;  // Tax time for last paid
    uint lastSalaryTime;    // Driver salary time for last paid
    uint lastDividendTime;  // Participants dividend money time for last
    uint112 ownedCarId;  //Approved car by participants

    mapping(address => Participant) public allParticipants; // Map for Participants
    address[] allParticipantsAddresses; // Participant adresses    
    Driver TaxiDriver;      //Taxi Driver
    
    

    proposedCar ProposedCar;            //Proposed car to the participants
    proposedCar ProposedRepurchase;     //Proposed repurchase car to the participants

    constructor(){
        owner = msg.sender;
        lastSalaryTime = block.timestamp;
        lastTaxPayment = block.timestamp;
        lastDividendTime = block.timestamp;
    }

    modifier onlyParticipant() {
        require(allParticipants[msg.sender].addressParticipant != address(0), "You are not Participant");
        _;
    }

    modifier onlyCarDealer(){
        require(msg.sender == carDealer, "You are not Car Dealer");
        _;
    }
     modifier onlyDriver(){
        require(msg.sender == TaxiDriver.addressDriver, "You are not Taxi Driver");
        _;
    }
    modifier onlyOwner(){
        require(msg.sender == owner, "You are not Taxi Driver");
        _;
    }




    function Join() public payable{
        require(totalParticipantCount < 9,"No more Participants");
        require(msg.value >= participationFee,"Don't have enough money(at least 50 Ether)");
        require(allParticipants[msg.sender].addressParticipant==address(0),"You are already a participant");
        uint payBack = msg.value - participationFee;
        if(payBack > 0){
            payable(msg.sender).transfer(payBack);
        }
        Participant memory newParticipant;
        newParticipant.addressParticipant = payable(msg.sender);
        newParticipant.balance = 0;
        newParticipant.voteForBuy = false;
        newParticipant.voteForDriver = false;
        newParticipant.voteForDriver = false;
        newParticipant.dividendMoney = 0;
        allParticipantsAddresses.push(newParticipant.addressParticipant);
        allParticipants[msg.sender] = newParticipant;
        totalParticipantCount += 1;
        totalBalance += participationFee;
    
    }

    function SetCarDealer(address payable _carDealer) public onlyOwner  {
        carDealer = _carDealer;
    }

    function CarProposeToBusiness(uint32 id,uint price, uint validTime) onlyCarDealer public {
        require(ownedCarId == 0, "There is already a car in business");
        ProposedCar = proposedCar(id,price,block.timestamp+(validTime * 1 days),0);
        for(uint i = 0; i < totalParticipantCount; i++){
            allParticipants[allParticipantsAddresses[i]].voteForBuy = false;
        }
    }

    function ApprovePurchaseCar() onlyParticipant public payable {
        require(allParticipants[msg.sender].voteForBuy == false,"Already approved" );
        ProposedCar.approvalState +=1;
        allParticipants[msg.sender].voteForBuy = true;
        if(ProposedCar.approvalState > totalParticipantCount/2){
            PurchaseCar();
        }
    }

    function PurchaseCar()  internal{
        require(ProposedCar.approvalState > (totalParticipantCount / 2),"Less than %50+1 approval");
        require(block.timestamp < ProposedCar.offerValidTime,"Validation time has passed");
        require(totalBalance >= ProposedCar.price,"Not enough money");
        totalBalance -= ProposedCar.price;
        ownedCarId = ProposedCar.carID;
        carDealer.transfer(ProposedCar.price);

    }

    function RepurchaseCarPropose(uint32 id, uint price, uint validTime ) onlyCarDealer public{
        require(ownedCarId == id,"Wrong car");
        ProposedRepurchase = proposedCar(id, price, block.timestamp+(validTime * 1 days), 0);
        for(uint i = 0; i < totalParticipantCount; i++){
            allParticipants[allParticipantsAddresses[i]].voteForSell = false;
        }

    }
    function ApproveSellProposal() onlyParticipant public {
        require(allParticipants[msg.sender].voteForSell == false,"You used your vote");
        ProposedRepurchase.approvalState += 1;
        allParticipants[msg.sender].voteForSell = true;

    }

    function RepurchaseCar() onlyCarDealer public payable{
        require(ProposedRepurchase.approvalState > (totalParticipantCount / 2),"Less than %50+1 repurchase votes");
        require(block.timestamp <= ProposedRepurchase.offerValidTime, "Validation time has passed");
        require(msg.value >= ProposedRepurchase.price,"You didn't give enough money");
        uint payBack = msg.value - ProposedRepurchase.price;
        if(payBack > 0){
            payable(msg.sender).transfer(payBack);
        }
        totalBalance += ProposedRepurchase.price;
        ownedCarId = 0;

    }

    function ProposeDriver (uint _salary)  public {
        require(TaxiDriver.approved == false, "There is already a taxi driver");
        TaxiDriver = Driver(payable(msg.sender),false,_salary,0,0);
        for(uint i = 0; i < totalParticipantCount; i++){
            allParticipants[allParticipantsAddresses[i]].voteForDriver = false;
        }
    }
    
    function ApproveDriver() onlyParticipant public{
        require(allParticipants[msg.sender].voteForDriver == false,"You used your vote");
        TaxiDriver.approvalState +=1;
        allParticipants[msg.sender].voteForDriver = true;
        if(TaxiDriver.approvalState > totalParticipantCount/2){
            SetDriver();
        }
    }

    function SetDriver() internal {
        require(TaxiDriver.approved == false,"There is a taxi driver");
        require(TaxiDriver.addressDriver != address(0),"There is no offered taxi driver");
        require(TaxiDriver.approvalState > totalParticipantCount/2,"Not enough vote for taxi driver");
        TaxiDriver.approved = true;
    }
    function ProposeFireDriver() onlyParticipant public payable{
        require(allParticipants[msg.sender].voteForSell == true,"You already voted");
        require(TaxiDriver.approved == true,"There is no driver");
        TaxiDriver.approvalState -=1;
        allParticipants[msg.sender].voteForDriver = false;
        if(TaxiDriver.approvalState == 0){
            FireDriver();
        }


    }
    function FireDriver() internal{
        require(TaxiDriver.approved == true,"There is no taxi driver already");
        TaxiDriver.addressDriver.transfer(TaxiDriver.salary);
        totalBalance -= TaxiDriver.salary;
        delete TaxiDriver;

    }
    function LeaveJob() onlyDriver public payable{
        FireDriver();
    }
    function GetCharge() public payable{
        totalBalance += msg.value;
    }

    function ReleaseSalary() onlyOwner public {
        require(TaxiDriver.approved, "There is no taxi driver");
        require(totalBalance >= TaxiDriver.salary, "Not enough money to pay driver salary");
        require(block.timestamp > lastSalaryTime + 30 days, "This function can not be called before 1 months");
        totalBalance -= TaxiDriver.salary;
        TaxiDriver.balance += TaxiDriver.salary;
        lastSalaryTime += block.timestamp;
    }

    function GetSalary() onlyDriver public {
        require(block.timestamp > lastSalaryTime + 30 days, "This function can not be called before 1 months");
        require(TaxiDriver.balance > 0 ,"You have no money");
         require(totalBalance >= TaxiDriver.salary, "Not enough money to pay driver salary");
        TaxiDriver.addressDriver.transfer(TaxiDriver.balance);
        lastSalaryTime += block.timestamp;
        totalBalance -= TaxiDriver.salary;
        TaxiDriver.balance = 0;
    }

    function CarExpenses() onlyParticipant public {
        require(block.timestamp > lastTaxPayment + 180 days,"It has been paid in last 6 months");
        require(ownedCarId != 0, "There is no car to pay expense");
        require(totalBalance >= fixedTotalTaxAmount, "Not enough balance to pay expenses");
        carDealer.transfer(fixedTotalTaxAmount);
        lastTaxPayment = block.timestamp;
        totalBalance -= fixedTotalTaxAmount;

    }

    function PayDividend() onlyParticipant public{
        require(block.timestamp > lastDividendTime + 180 days,"It has been done in last 6 months");
        require(totalBalance > 0, "There is no money");
        require(totalBalance > totalParticipantCount* participationFee,"No PROFIT");
        if(block.timestamp > lastTaxPayment+180 days){
            carDealer.transfer(fixedTotalTaxAmount);
            lastTaxPayment = block.timestamp;
            totalBalance -= fixedTotalTaxAmount;
        }
        if(block.timestamp > lastSalaryTime +30 days){
            TaxiDriver.balance += TaxiDriver.salary;
            totalBalance -=TaxiDriver.salary;
            lastSalaryTime = block.timestamp;
        
        }
        require(totalBalance > totalParticipantCount* participationFee,"There is no profit after payments");
        uint profit = totalBalance / totalParticipantCount;
        for(uint i = 0; i < totalParticipantCount; i++){
            allParticipants[allParticipantsAddresses[i]].balance += profit;
        }
        totalBalance = 0;
        lastDividendTime = block.timestamp;
    }

    function GetDividend() onlyParticipant public {
        require(allParticipants[msg.sender].balance > 0 , "You have no money for get");
        payable(msg.sender).transfer(allParticipants[msg.sender].balance);
        allParticipants[msg.sender].balance = 0;
    }
    fallback () external payable {
    }

}