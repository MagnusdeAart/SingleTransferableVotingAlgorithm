//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Stv {
    struct Ballot{
        address first;
        address second;
        address third;
    }
    struct voteAndTransferValue{
        address voterAddress;
        uint transferValue;
        uint stage;
    }
    struct Candidate{ //we can add more properties here if we want to store more on the candidate
        address candidateAddress;
    }
    struct CandidatesWithSurplus{
        address candidate;
        uint surplus;
        bool surplusFromFirstStage;
    }

    uint ballotCount;
    uint currentStage = 1;
    uint placesFilled =0; //gets upped when a place is filled
    uint numberOfPeopleToElect = 4; // <---------------------------------Change this number to change the number of Positions to be filled
    uint openPlacesRemaining = numberOfPeopleToElect -placesFilled;
    uint numberOfCandidatesStillInRace; // == candidates.length at start, then reduced as candidates get elected or excluded
    
    uint[] quotasOfWinners;
    uint[] allTransferValues = [100];
    address[] winners; //the winners will be entered here
    address[] voters;
    address[] candidatesToExcluded;
    Candidate[] candidates;
    CandidatesWithSurplus[] candidatesWithSurplus;
    
    mapping(uint=>bool) transferValueAlreadyinArray;
    mapping(address=>bool) surplusTransferred;
    mapping(address=>Ballot) ballotBox;
    mapping(address=>voteAndTransferValue[]) detailedSort;
    mapping(address=>uint) voteScore; 
    mapping(address=>bool) hasWon;
    mapping(address=>bool) toBeExcluded; //not yet, but collecting those who will be next round
    mapping(address=>bool) onCandidatesToBeExcludedList;
    mapping(address=>bool) hasBeenExcluded; //exlusion executed
    mapping(address=>uint) currentPreferenceIndex; //tracks on which preference the voter currently is by uint "index"

    function runElectionAlgorithm() public{
        //still need to implement the execute after specific time function
        
        setUp();

        //First Stage
        deemElectedAndCalculateSurplus(); 
        currentStage++;  

        //Second Stage
        while(placesFilled<numberOfPeopleToElect){
            //elect people and distribute surpluses
            while(doSurplusesExist()==true && placesFilled <=numberOfPeopleToElect && deferrTransferYesNo()==true){ //-1 because placesFilled starts counting at 0 to serve as the index for winner[placesFilled]
                distributeSurplus();
                currentStage++;
                deemElectedAndCalculateSurplus();
            }
            //eliminate people and elect candidates if they meet the quota after having received more ballots 
            eliminateLowestCandiates();
            currentStage++;
        }
        printAllScores();
    }



    function setUp()internal{
        numberOfCandidatesStillInRace = candidates.length;
        countAndBundleFirstChoices();
        transferValueAlreadyinArray[100]==true;
    }

    //runElectionAlgorithm
    function deemElectedAndCalculateSurplus() internal{
        if(placesFilled <numberOfPeopleToElect){ //if the num of places filled is not equal to the number of places to be filled
            address candidateWithHighestScore = determineHighestCandidateNotYetElected();
            uint scoreOfCandidate =voteScore[candidateWithHighestScore];
            uint currentQuota =calculateDroopQuota();
            uint otherQuota = calculateOtherQuota();
            uint surplus;
            if(scoreOfCandidate>=currentQuota||scoreOfCandidate>=otherQuota||numberOfCandidatesStillInRace==openPlacesRemaining){
                if(scoreOfCandidate>=currentQuota){
                    quotasOfWinners.push(currentQuota); //pushing the quota with which they won
                }
                else{
                    quotasOfWinners.push(otherQuota); //pushing the quota with which they won
                }
                winners.push(candidateWithHighestScore);
                numberOfCandidatesStillInRace--;

                hasWon[candidateWithHighestScore] = true; //setting the hasWon to true so that we can loop over them
                placesFilled++;
                openPlacesRemaining--;
                
                int m = int(scoreOfCandidate);
                int n = int(currentQuota);
                if(( m-n)<0){
                    surplus =0;
                }
                else{
                    surplus = scoreOfCandidate -currentQuota;
                }
                if(surplus !=0){
                    if(currentStage == 1){ //if this surplus arose in the first round, set surplusFromFirstStage to "true"
                        candidatesWithSurplus.push(CandidatesWithSurplus(candidateWithHighestScore, surplus, true)); //add them to surplusArray if they won
                    }
                    else{
                        candidatesWithSurplus.push(CandidatesWithSurplus(candidateWithHighestScore, surplus, false)); //add them to surplusArray if they won
                    }
                }
            }
        }
        if(voteScore[determineHighestCandidateNotYetElected()]>=calculateDroopQuota()&& openPlacesRemaining!=0){ //call the function recursively until everyone over the quota has been elected
            deemElectedAndCalculateSurplus();
        }
    }
    //runElectionAlgorithm
    function eliminateLowestCandiates()internal{
        determineCandidatesToBeExcluded();
        
        uint activeTransferValue =100;
        for(uint k=0;k<allTransferValues.length;k++){
            activeTransferValue = allTransferValues[k]; //set the transferValue to the first in the array
            for(uint w=0;w<candidatesToExcluded.length;w++){
                address looser = candidatesToExcluded[w]; //select the looser
                if((numberOfCandidatesStillInRace>openPlacesRemaining)){
                    hasBeenExcluded[looser]=true; //since the loosers are eliminated, do not give them any more votes
                    numberOfCandidatesStillInRace--;
                    for(uint i=0;i<detailedSort[looser].length;i++){ //looping through all the ballots of the looser
                        address voter = detailedSort[looser][i].voterAddress; 
                        if(activeTransferValue == detailedSort[looser][i].transferValue){ //if the transferValue matches the activeTransferValue, allow transfer
                            
                            address secondPreference = ballotBox[voter].second; //take their second choice
                            currentPreferenceIndex[voter] =1; //track their currently active preference, now second
                            if(hasWon[secondPreference]==true||hasBeenExcluded[secondPreference]==true||secondPreference ==looser){ //if the second preference has already been elected or excluded, move to third
                                address thirdPreference = ballotBox[voter].third;
                                if(thirdPreference ==looser){
                                    voteScore[0x0000000000000000000000000000000000000000] +=activeTransferValue;
                                }
                                else{
                                    currentPreferenceIndex[voter] =2; //track their currently active preference, now third
                                    voteScore[thirdPreference] +=activeTransferValue; //we add the the activeTransferValue here.
                                    detailedSort[thirdPreference].push(voteAndTransferValue(voter, activeTransferValue, currentStage));
                                }
                            }
                            else{ 
                                voteScore[secondPreference] +=activeTransferValue; //we simply add the value here, is that good?
                                detailedSort[secondPreference].push(voteAndTransferValue(voter, activeTransferValue, currentStage)); //register the voter under their second preference now
                            }
                        }
                    }
                }
            }
            deemElectedAndCalculateSurplus(); //after having transferred the first batch of papers, check if any candidate is elected
        }
    }
    //eliminateLowestCandiates
    function determineCandidatesToBeExcluded() internal{
        uint sum;
        address last;
        address next =returnNextLowest();
        while(sum <= voteScore[next]==true){ //as long as this is smaller than the next highest voter
            if(sum <=voteScore[next] && last!=0x0000000000000000000000000000000000000000 && onCandidatesToBeExcludedList[last]==false){
                onCandidatesToBeExcludedList[last] =true;
                candidatesToExcluded.push(last);
            }
            sum+=voteScore[next];
            last =next;
            next = returnNextLowest(); //take next up the line
        }
        for(uint i = 0; i<candidates.length;i++){ //resetting the candidates --------------------is this the right way to do it?
            toBeExcluded[candidates[i].candidateAddress] =false;
        }
    }
    
    
    
    
    //distribute Surplus (first and higher stage) + runElectionAlgorithm
    function returnCandidateWithHighestSurplus() internal view returns(address, uint) {
        address candidateWithHighestSurplus;
        uint maxSurplus;
        for(uint i=0; i<candidatesWithSurplus.length;i++){
            if(surplusTransferred[candidatesWithSurplus[i].candidate] ==false){ //only display candidate if their surplus has not yet been transferred
                if(candidatesWithSurplus[i].surplus>maxSurplus){
                candidateWithHighestSurplus = candidatesWithSurplus[i].candidate;
                maxSurplus =candidatesWithSurplus[i].surplus;
                }
            }
        }
        //console.log("-----");
        //console.log(candidateWithHighestSurplus);
        return (candidateWithHighestSurplus, maxSurplus); //type CandidatesWithSurplus
    } 
    //deemElectedAndCalculateSurplus
    function determineHighestCandidateNotYetElected() internal view returns(address){ //loop through all candidates, select the one with the most votes, excluding already selected ones
        uint mostVotes;
        address candidateWithMostVotes;
        for(uint i; i<candidates.length;i++){
            address currentCandidate = candidates[i].candidateAddress;
            if(hasWon[currentCandidate] ==false){ //if hasWon is true, skip them
                if(voteScore[currentCandidate]>mostVotes){
                    mostVotes = voteScore[currentCandidate];
                    candidateWithMostVotes = currentCandidate;
                }
            }
        }
        return(candidateWithMostVotes);
    }



    //runElectionAlgorithm
    function distributeSurplus()internal{
        (address candidateWithBiggestSurplus, ) = returnCandidateWithHighestSurplus();
        if(isSurplusFromFirstStage(candidateWithBiggestSurplus)){
            distributeHighestSurplusFirstStage();
        }
        else{
            distributeHighestSurplusHigherStage();
        }
    }
    //distributeSurplus
    function distributeHighestSurplusFirstStage()internal{
        (address candidateWithHigestsurplus, uint surplus) = returnCandidateWithHighestSurplus();
        (uint numOfTransferablePapers, uint totalValueOfPapers) = transferablePapers(candidateWithHigestsurplus);
        uint transferValue =100;
        if(transferValueAlreadyinArray[transferValue]==false){
            allTransferValues.push(transferValue); //adding the first transferValue
            transferValueAlreadyinArray[transferValue]==true;
        }
        
        if(totalValueOfPapers>surplus){  
            transferValue = surplus/numOfTransferablePapers;
            if(transferValueAlreadyinArray[transferValue]==false){
                allTransferValues.push(transferValue); //adding the first transferValue
                transferValueAlreadyinArray[transferValue]==true;
            }
        }
        for(uint i=0;i<detailedSort[candidateWithHigestsurplus].length;i++){
            if(detailedSort[candidateWithHigestsurplus][i].transferValue==100){ //only voters who selected the candidate as their first preference
                address voter = detailedSort[candidateWithHigestsurplus][i].voterAddress; 
                address secondPreference = ballotBox[voter].second; //take their second choice
                currentPreferenceIndex[voter] =1; //track their currently active preference, now second
                if(hasWon[secondPreference]==true){ //if the second preference has already been elected, use third preference
                    address thirdPreference = ballotBox[voter].third;
                    currentPreferenceIndex[voter] =2; //track their currently active preference, now third
                    voteScore[thirdPreference] +=transferValue; //we simply add the value here, is that good?
                    detailedSort[thirdPreference].push(voteAndTransferValue(voter, transferValue, currentStage)); //register the voter under their third preference now
                }
                else{
                    voteScore[secondPreference] +=transferValue; //we simply add the value here, is that good?
                    detailedSort[secondPreference].push(voteAndTransferValue(voter, transferValue, currentStage)); //register the voter under their second preference now
                }
            }
        }
        surplusTransferred[candidateWithHigestsurplus] =true;
    }
    //distributeSurplus
    function distributeHighestSurplusHigherStage()internal{
        (address candidateWithHigestsurplus, uint surplus) = returnCandidateWithHighestSurplus();
        (uint numOfTransferablePapers, uint totalValueOfPapers) = transferablePapers(candidateWithHigestsurplus);
        if(totalValueOfPapers>surplus){  //if the totalTransferableValue is higher, calculateTransferValue
            uint transferValue = surplus/numOfTransferablePapers;
            if(transferValueAlreadyinArray[transferValue]==false){
                allTransferValues.push(transferValue); //adding the first transferValue
                transferValueAlreadyinArray[transferValue]==true;
            }
            for(uint i=0;i<detailedSort[candidateWithHigestsurplus].length;i++){ //looping through all votes of candidate
                if(detailedSort[candidateWithHigestsurplus][i].stage ==currentStage-1){ //if the voters were added last stage
                    address voter = detailedSort[candidateWithHigestsurplus][i].voterAddress; 
                    address secondPreference = ballotBox[voter].second; //take their second choice
                    currentPreferenceIndex[voter] =1; //track their currently active preference, now second
                    if(hasWon[secondPreference]==true){ //if the second preference has already been elected, use third preference
                        address thirdPreference = ballotBox[voter].third;
                        currentPreferenceIndex[voter] =2; //track their currently active preference, now third
                        voteScore[thirdPreference] +=transferValue; //add the newly calculated transferValue to their score
                        detailedSort[thirdPreference].push(voteAndTransferValue(voter, transferValue, currentStage)); //register the voter under their third preference now
                    }
                    else{
                        voteScore[secondPreference] +=transferValue; //we simply add the value here, is that good?
                        detailedSort[secondPreference].push(voteAndTransferValue(voter, transferValue, currentStage)); //register the voter under their second preference now
                    }
                }
            }
        }
        else{ //if the total value does not exceed the surplus, transferValue is present Value
            for(uint i=0;i<detailedSort[candidateWithHigestsurplus].length;i++){
                if(detailedSort[candidateWithHigestsurplus][i].stage ==currentStage-1){ //if the voters were added last stage
                    address voter = detailedSort[candidateWithHigestsurplus][i].voterAddress; 
                    uint transferValue = detailedSort[candidateWithHigestsurplus][i].transferValue;
                    address secondPreference = ballotBox[voter].second; //take their second choice
                    currentPreferenceIndex[voter] =1; //track their currently active preference, now second
                    if(hasWon[secondPreference]==true){ //if the second preference has already been elected, use third preference
                        address thirdPreference = ballotBox[voter].third;
                        currentPreferenceIndex[voter] =2; //track their currently active preference, now third
                        voteScore[thirdPreference] +=transferValue; //we simply add the value here, is that good?
                        detailedSort[thirdPreference].push(voteAndTransferValue(voter, transferValue, currentStage)); //register the voter under their third preference now
                    }
                    else{
                    voteScore[secondPreference] +=transferValue; //we simply add the value here, is that good?
                    detailedSort[secondPreference].push(voteAndTransferValue(voter, transferValue, currentStage)); //register the voter under their second preference now
                    }
                }   
            }
        }
        surplusTransferred[candidateWithHigestsurplus] =true;
        //console.log("transfer abgeschlossen!");
        //console.log(candidateWithHigestsurplus);
    }


    //distributeSurplus
    function transferablePapers(address _candidate)internal view returns(uint, uint){
        uint numberOfPapers;
        uint totalValueOfPapers;
        if(currentStage==1){
            for(uint i = 0; i<detailedSort[_candidate].length;i++){ //of all voters in voteAndTransferValue-structs, 
                if(detailedSort[_candidate][i].transferValue==100){ //if they are full votes
                    address voter =detailedSort[_candidate][i].voterAddress;
                    if(ballotBox[voter].second !=0x0000000000000000000000000000000000000000){
                        numberOfPapers++;
                        totalValueOfPapers+=100;
                    }
                }
            }
        }
        if(currentStage !=1){
            for(uint i = 0; i<detailedSort[_candidate].length;i++){
                if(detailedSort[_candidate][i].stage ==currentStage-1){ //this should hopefully only select the voters which were added last stage
                    address voter = detailedSort[_candidate][i].voterAddress;
                    uint transferValue = detailedSort[_candidate][i].transferValue;
                    //uint currentpreference = currentPreferenceIndex[voter];
                    if(currentPreferenceIndex[voter]==0){
                        address preferredCandidate = ballotBox[voter].first;
                        if(preferredCandidate!=0x0000000000000000000000000000000000000000){ //actually redundant since first choice cannot be empty
                            numberOfPapers++;
                            totalValueOfPapers +=transferValue;
                        }
                    }
                    else if(currentPreferenceIndex[voter]==1){
                        address preferredCandidate = ballotBox[voter].second;
                        if(preferredCandidate!=0x0000000000000000000000000000000000000000){
                            numberOfPapers++;
                            totalValueOfPapers +=transferValue;
                        }
                    }
                    else if(currentPreferenceIndex[voter]==2){
                        address preferredCandidate = ballotBox[voter].third;
                        if(preferredCandidate!=0x0000000000000000000000000000000000000000){
                            numberOfPapers++;
                            totalValueOfPapers +=transferValue;
                        }
                    }
                }
            }
        }
        return(numberOfPapers, totalValueOfPapers);     
    }

    
    
    //runElectionAlgorithm
    function isSurplusFromFirstStage(address _candidate) internal view returns(bool){
        for(uint i=0;i<candidatesWithSurplus.length;i++){
            if(candidatesWithSurplus[i].candidate == _candidate){
                return candidatesWithSurplus[i].surplusFromFirstStage; //will return true if the candidates surplus arose from first stage, otherwise false
            }
        }
        return false;
    }
    //runElectionAlgorithm
    function doSurplusesExist()internal view returns(bool){
        for(uint i=0;i<candidatesWithSurplus.length;i++){
            if(surplusTransferred[candidatesWithSurplus[i].candidate] ==false){
                return true;
            }
        }
        return false;
    }
    //runElectionAlgorithm
    function deferrTransferYesNo() internal returns(bool){
        uint totalOfAllNonTransferredSurpluses;
        for(uint i=0;i<candidatesWithSurplus.length;i++){
            if(surplusTransferred[candidatesWithSurplus[i].candidate] ==false){
                totalOfAllNonTransferredSurpluses +=candidatesWithSurplus[i].surplus;
            }
        }
        (uint lowestVoteScore, uint secondLowestVoteScore) = determineLowestAndSecondLowest();
        uint difference = determineDifference(); //difference between total of candidates to be excluded and next up
        if(totalOfAllNonTransferredSurpluses>(lowestVoteScore+secondLowestVoteScore) && totalOfAllNonTransferredSurpluses>difference){ //if this is true, then the we need to transfer the highest surplus
            return true;
        }
        return false;
    }
    //deferrTransferYesNo
    function determineLowestAndSecondLowest() internal view returns(uint, uint){    
        uint lowestVoteScore = ballotCount*100; //first sets the leastVotes to the maximum attainable votescore
        address candidateWithLeastVotes;
        for(uint i; i<candidates.length;i++){
            address currentCandidate = candidates[i].candidateAddress;
            if(hasWon[currentCandidate] ==false && hasBeenExcluded[currentCandidate] ==false){ //if hasWon is true or hasBeenExcluded, skip them
                if(voteScore[currentCandidate]<lowestVoteScore){
                    lowestVoteScore = voteScore[currentCandidate];
                    candidateWithLeastVotes = currentCandidate;
                }
            }
        }
        uint secondLowestVoteScore = ballotCount*100;
        address candidateWithSecondLeastVotes;
        for(uint i; i<candidates.length;i++){
            address currentCandidate = candidates[i].candidateAddress;
            if(hasWon[currentCandidate] ==false && hasBeenExcluded[currentCandidate] ==false && currentCandidate != candidateWithLeastVotes){ //if hasWon is true or hasBeenExcluded or is the currentLowest, skip them
                if(voteScore[currentCandidate]<secondLowestVoteScore){
                    secondLowestVoteScore = voteScore[currentCandidate];
                    candidateWithSecondLeastVotes = currentCandidate;
                }
            }
        }
        return(lowestVoteScore, secondLowestVoteScore);
    }
    //deferrTransferYesNo
    function returnNextLowest() internal returns(address){
        uint leastVotes =ballotCount*100;
        address candidateWithLeastVotes;
        for(uint i; i<candidates.length;i++){
            address currentCandidate = candidates[i].candidateAddress;
            if(hasWon[currentCandidate] ==false && hasBeenExcluded[currentCandidate] ==false && toBeExcluded[currentCandidate]==false){ //if hasWon is true or hasBeenExcluded, skip them
                if(voteScore[currentCandidate]<leastVotes){
                    leastVotes = voteScore[currentCandidate];
                    candidateWithLeastVotes = currentCandidate;
                }
            }
        }
        toBeExcluded[candidateWithLeastVotes] =true;
        return candidateWithLeastVotes;
    }

    //deferrTransferYesNo
    function determineDifference() internal returns(uint){
        uint sum;
        address last;
        uint difference;
        address next =returnNextLowest();
        while(sum <= voteScore[next]==true){ //as long as this is smaller than the next highest voter
            sum+=voteScore[next];
            last =next;
            next = returnNextLowest(); //take next up the line
        }
        for(uint i = 0; i<candidates.length;i++){ //resetting the candidates --------------------is this the right way to do it?
            toBeExcluded[candidates[i].candidateAddress] =false;
        }
        int k = ((int(sum)-int(voteScore[last])) -int(voteScore[last]));
        if(k<0){
            difference =0;
        }
        else{
            difference = (sum-voteScore[last]) -voteScore[last];
        }
        return difference;
    }
    
    //deemElectedAndCalculateSurplus
    function calculateDroopQuota() internal view returns(uint){
        uint totalVote = ballotCount*100;
        uint quota = totalVote/(numberOfPeopleToElect+1)+1;
        return quota;
    }

    //deemElectedAndCalculateSurplus
    function calculateOtherQuota() internal view returns(uint){
        uint totalVote = ballotCount*100;
        uint nontransferableVoteValue = voteScore[0x0000000000000000000000000000000000000000];
        uint sumOfWinnerQuotas;
        for(uint i=0;i<quotasOfWinners.length;i++){ //hopefully summing all the quotas
            sumOfWinnerQuotas +=quotasOfWinners[i];
        }
        uint totalActiveVote = totalVote - sumOfWinnerQuotas - nontransferableVoteValue;
        return totalActiveVote/(numberOfPeopleToElect-placesFilled+1);
    }

    //pre-election
    function addMultipleCandidates(Candidate[] calldata allCandidates) public{ //runs once at the start;
        for(uint i=0;i<allCandidates.length;i++){
            candidates.push(allCandidates[i]);
        }
    }
    //pre-election
    function addSingleCandidate(address candidate) public {
        candidates.push(Candidate(candidate));
    }
    //pre-election
    function castBallot(address voter, address first, address second, address third)public{
        ballotBox[voter] = Ballot(first, second, third);
        voters.push(voter);
        ballotCount++;
    }

    //part of the setup of the election
    function countAndBundleFirstChoices() internal{
        for(uint i =0; i<voters.length;i++){
            address voter = voters[i];
            address firstchoice = ballotBox[voter].first; //selecting the address of the first choice of the voter
            voteScore[firstchoice]+=100;
            detailedSort[firstchoice].push(voteAndTransferValue(voter, 100, 1)); //adding the voter to the register of the candidate
        }
    } 

    function printAllScores() public view{
        console.log("--------------------------------------------");
        console.log("All candidates standing for election:");
        for(uint i=0;i<candidates.length;i++){ //display all candidates and their scores
            console.log("");
            console.log(i+1);
            console.log(candidates[i].candidateAddress);
            console.log(voteScore[candidates[i].candidateAddress]);
        }
        console.log("- - - - - - - - - - - - - - - - - - - - - - - ");
        if(winners.length!=0){
            for(uint i=0; i<winners.length;i++){
                console.log("");
                console.log("Winner Number: ");
                console.log(i+1);
                console.log(winners[i]);
                console.log(voteScore[winners[i]]);
            }
        }
        console.log("--------------------------------------------");
    }
}


