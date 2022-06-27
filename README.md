This is my implementation of how to conduct an election by the Single Transferable Vote. 
This is my final project for the Chainshot Ethereum Developer Bootcamp.
The implemention is based on this guide from the Electoral Reform society:
https://www.electoral-reform.org.uk/latest-news-and-research/publications/how-to-conduct-an-election-by-the-single-transferable-vote-3rd-edition/

For a less dry introduction of how an election using STV works and what the benefits are, i can only recommend:
Politics in the Animal Kingdom: Single Transferable Vote on Youtube by CGP Grey
https://www.youtube.com/watch?v=l8XOZJkozfI&t=309s

Note: The whole voting algorithm is stored and executed on chain in the smart contract. For an actual implementation it should be
considered to only store the individual votes on chain, and calculate the results offchain, to minimise gas costs. Since this is 
a demo project and i wanted to use this as a way to practice my solidity understanding, i built it fully on chain.
