/* ================================================================================*/
/* Javascript code for Auction DApp
/* ================================================================================*/

/* Check if Metamask is installed. */
if (typeof window.ethereum !== 'undefined') {
    console.log('MetaMask is installed!');
} else {
    console.log('Please install MetaMask or another browser-based wallet');
}

/* Instantiate a Web3 client that uses Metamask for transactions.  Then,
 * enable it for the site so user can grant permissions to the wallet */
const web3 = new Web3(window.ethereum);
window.ethereum.enable();

/* Grab ABI from compiled contract (e.g. in Remix) and fill it in.
 * Grab address of contract on the blockchain and fill it in.
 * Use the web3 client to instantiate the contract within program */
var AuctionABI = [{"name":"NewEntry","inputs":[{"type":"uint256","name":"value","indexed":false}],"anonymous":false,"type":"event"},{"outputs":[],"inputs":[],"stateMutability":"nonpayable","type":"constructor"},{"name":"reset","outputs":[],"inputs":[{"type":"uint256","name":"_tokenId"}],"stateMutability":"nonpayable","type":"function","gas":981626},{"name":"bid","outputs":[],"inputs":[{"type":"string","name":"_name"}],"stateMutability":"payable","type":"function","gas":325404},{"name":"withdraw","outputs":[],"inputs":[],"stateMutability":"nonpayable","type":"function","gas":56244},{"name":"endAuction","outputs":[],"inputs":[],"stateMutability":"nonpayable","type":"function","gas":87347},{"stateMutability":"payable","type":"fallback"},{"name":"auctionStart","outputs":[{"type":"uint256","name":""}],"inputs":[],"stateMutability":"view","type":"function","gas":1301},{"name":"auctionEnd","outputs":[{"type":"uint256","name":""}],"inputs":[],"stateMutability":"view","type":"function","gas":1331},{"name":"minimumBid","outputs":[{"type":"uint256","name":""}],"inputs":[],"stateMutability":"view","type":"function","gas":1361},{"name":"tokenId","outputs":[{"type":"uint256","name":""}],"inputs":[],"stateMutability":"view","type":"function","gas":1391},{"name":"highestBidder","outputs":[{"type":"address","name":""}],"inputs":[],"stateMutability":"view","type":"function","gas":1421},{"name":"highestBid","outputs":[{"type":"uint256","name":""}],"inputs":[],"stateMutability":"view","type":"function","gas":1451},{"name":"totalBids","outputs":[{"type":"uint256","name":""}],"inputs":[],"stateMutability":"view","type":"function","gas":1481},{"name":"ended","outputs":[{"type":"bool","name":""}],"inputs":[],"stateMutability":"view","type":"function","gas":1511},{"name":"isReset","outputs":[{"type":"bool","name":""}],"inputs":[],"stateMutability":"view","type":"function","gas":1541},{"name":"pendingReturns","outputs":[{"type":"uint256","name":""}],"inputs":[{"type":"address","name":"arg0"}],"stateMutability":"view","type":"function","gas":1786},{"name":"owner","outputs":[{"type":"address","name":""}],"inputs":[],"stateMutability":"view","type":"function","gas":1601},{"name":"entries","outputs":[{"type":"address","name":"signer"},{"type":"string","name":"name"},{"type":"uint256","name":"date"},{"type":"uint256","name":"bid"}],"inputs":[{"type":"uint256","name":"arg0"}],"stateMutability":"view","type":"function","gas":10413}]

/*** Requires Compiling the current Auction contract to generate ABI - e.g. use remix.ethereum.org ***/
var Auction = new web3.eth.Contract(AuctionABI,'0xc07A7F67B553Ef997212e93899A4a7A9a1b39490');

/* ================================================================================*/
/* Update the UI with current wallet account address when called */
async function updateAccount() {
  const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
  const account = accounts[0];
  const accountNode = document.getElementById("account");
  if (accountNode.firstChild)
    accountNode.firstChild.remove();
  var textnode = document.createTextNode(account);
  accountNode.appendChild(textnode);
}
/* Update UI with time remaning countdown */
async function updateCountdown() {
  const auctionEnd = await Auction.methods.auctionEnd().call();
  const current = new Date().getTime()/1000
  const countdown = auctionEnd - current
  startTimer(countdown, document.querySelector('#remaining'))
}
// Create interval for countdown display
function startTimer(duration, display) {
    var timer = duration, minutes, seconds;
    setInterval(function () {
        minutes = parseInt(timer / 60, 10);
        seconds = parseInt(timer % 60, 10);

        minutes = minutes < 10 ? "0" + minutes : minutes;
        seconds = seconds < 10 ? "0" + seconds : seconds;

        display.textContent = minutes + ":" + seconds;

        if (--timer < 0) {
            display.textContent = "Bidding is over...";
        }
    }, 1000);
}

/* ================================================================================*/
/* Update the UI with current highest bid when called */
async function updateBid(){
  const bid = await Auction.methods.highestBid().call();
  updateBidUI(bid);
}

function updateBidUI(value){
  const bidNode = document.getElementById("highestBid");
  if (bidNode.firstChild)
    bidNode.firstChild.remove();
  var textnode = document.createTextNode(value + " Wei");
  bidNode.appendChild(textnode);
}

/* ================================================================================*/
/* Update the UI with Auction entries from contract when called */
async function updateEntries(){
  const entriesNode = document.getElementById("entries");
  while (entriesNode.firstChild) {
    entriesNode.firstChild.remove();
  }
  var current = 0
  for (var i = 0; i < 4; i++) {
      var entry = await Auction.methods.entries(i).call();
      const name = document.createTextNode("Name: " + entry.name);
      const wallet = document.createTextNode("Address: " + entry.signer);
      const entrydate = new Date(parseInt(entry.date)*1000);
      const signedOn = document.createTextNode("Bid placed on: " + entrydate.toUTCString());
      const bidAmount = document.createTextNode("Bid Amount: " + entry.bid + " Wei");
      const br1 = document.createElement("br");
      const br2 = document.createElement("br");
      const br3 = document.createElement("br");
      const br4 = document.createElement("br");
      const p = document.createElement("p");

      p.classList.add("entry");
      p.appendChild(name);
      p.appendChild(br1);
      p.appendChild(wallet);
      p.appendChild(br2);
      p.appendChild(signedOn);
      p.appendChild(br3);
      p.appendChild(bidAmount);
      p.appendChild(br4);
      entriesNode.prepend(p);
  }
}

/* ================================================================================*/
/* Issue a transaction to place a new bid based on form field values */
async function bid() {
  const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
  const account = accounts[0];
  const name = document.getElementById("name").value;
  const highestBid = await Auction.methods.highestBid().call();
  const bidPlaced = document.getElementById("bid").value;

  minBid = parseInt(highestBid) + 5000000000000000;
  if (bidPlaced >= minBid) {
    const transactionParameters = {
	    from: account,
	    gasPrice: 0x1D91CA3600,
	    value: bidPlaced
    };
  await Auction.methods.bid(name).send(transactionParameters);
  }
  else {
    window.alert("Your bid must exceed the highest bid + 0.005 ETH")
  }
};

/* ================================================================================*/
/* Call endAuction to claim NFT token after bidding is over*/
async function claim() {
  const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
  const account = accounts[0];
  const auctionEnd = await Auction.methods.auctionEnd().call();
  const current = new Date().getTime()/1000
  const countdown = auctionEnd - current

  const transactionParameters = {
	  from: account,
	  gasPrice: 0x1D91CA3600
  };
  if (countdown < 0) {
    await Auction.methods.endAuction().send(transactionParameters);
  }
  else {
    window.alert("You cannot claim the prize yet.")
  }
};

/* ================================================================================*/
/* call withdraw to regain any unsuccessful bids */
async function withdraw() {
  const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
  const account = accounts[0];
  const bid = await Auction.methods.pendingReturns(account).call()
  const withdraw = await Auction.methods.withdraw().call();

  const transactionParameters = {
	  from: account,
	  gasPrice: 0x1D91CA3600
  };
  if (bid) {
    await Auction.methods.withdraw().send(transactionParameters);
  }
  else {
    window.alert("You do not have any bids to withdraw")
  }
};

/* ================================================================================*/
/* Register a handler for when contract emits an Entry event after Auction
 * receives new bid to reload the page */
Auction.events.NewEntry().on("data", function(event) {
  updateBidUI(event.returnValues.value);
  updateEntries();
  updateCountdown();
});

/* Create submission button.  Then, register an event listener on it to invoke sign
 * transaction when clicked */
const button = document.getElementById('sign');
button.addEventListener('click', () => {
  bid();
});

/* Create claim prize  button.  Then, register an event listener on it to invoke  endAuction
 * transaction when clicked */
const prize = document.getElementById('prize');
prize.addEventListener('click', () => {
  claim();
});

/* Create withdraw button.  Then, register an event listener on it to invoke withdraw
 * transaction when clicked */
const get = document.getElementById('withdraw');
get.addEventListener('click', () => {
  withdraw();
});
