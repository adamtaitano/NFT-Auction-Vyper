# pragma @version ^0.2.4
from vyper.interfaces import ERC721

# add ERC721 interface to accept approval for NFT token to be auctioned
interface ERC721Receiver:
	def onERC721Received(
		_operator: address,
		_from: address,
		_tokenId: uint256,
		_data: Bytes[1024]
		) -> bytes32: view

# External Interface for NFT contract - used during endAuction to act as escrow for NFT token transfer
interface NFT:
	def safeTransferFrom(_from: address, _to: address, _tokenId: uint256, _data: Bytes[1024]): nonpayable
	def ownerOf(_tokenId: uint256) -> address: view

# Auction paramaters
# Seller is NFT token owner, receives money from the highest bidder of successful auction
# NFT  gives Auction contract operator approval upon reset of new Auction contract duplicate
auctionStart: public(uint256)
auctionEnd: public(uint256)
minimumBid: public(uint256)
tokenId: public(uint256)

# Current state of auction - storage variables
highestBidder: public(address)
highestBid: public(uint256)
totalBids: public(uint256)

# Set to true after endAuction is called, disallows repeat calls
ended: public(bool)
# Set to indicate if duplicate contract has been reset, and prevent subsequet resets
isReset: public(bool)
# Used to keep track of refunded bids so they can be withdrawn by addresses that have been outbid
pendingReturns: public(HashMap[address, uint256])

# Bidder entry structure containing a single entry for frontend display
struct Entry:
    signer: address
    name: String[32]
    date: uint256
    bid: uint256

# Size of the entry list - used to limit entries and preserve new bids
ENTRIES: constant(uint256) = 4

# NFT  contract that created this auction, or the msg.sender that deployed the original contract
owner: public(address)

# List of bidding entries
entries: public(Entry[ENTRIES])

# Successive bids much be larger than the minimum + increment, with default set to 0.005 ETH
increment: constant(uint256) = 5000000000000000

# Event emitted to web3 front-end when the Auction changes. Sends the new bid value.
event NewEntry:
    value: uint256

# Instantiate an original auction with default values:
# auctionEnd time, currently set to five minutes, 'minimumBid' for lowest accepted price
# All values are set to zero after NFT calls create_forwarder_to, and thus must be reset
@external
def __init__():
	# hardcoded values so NFT can create duplicate copies with create_forwarder_to
	# default minimumBid of 0.005 ETH, default auction time of 30 minutes
	self.minimumBid = 5000000000000000
	self.highestBid = 0
	self.totalBids = 0
	self.auctionStart = block.timestamp
	self.auctionEnd = self.auctionStart + 300
	self.owner = msg.sender
	for i in range(ENTRIES):
		self.entries[i].signer = msg.sender	
		self.entries[i].name = "Anonymous"
		self.entries[i].date = block.timestamp
		self.entries[i].bid = self.minimumBid
	self.isReset = True
	self.tokenId = 0

# Internal function to reset auction timers and storage variables upon duplication of contract
# Since __init__ is not called when create_forwarder_to is used, can be modified to suite auction needs
@internal
def _reset(_sender: address, _tokenId: uint256):
	self.minimumBid = 5000000000000000
	self.highestBid = 0
	self.totalBids = 0
	self.auctionStart = block.timestamp
	self.auctionEnd = self.auctionStart + 300
	self.owner = _sender
	for i in range(ENTRIES):
		self.entries[i].signer = _sender	
		self.entries[i].name = "Anonymous"
		self.entries[i].date = block.timestamp
		self.entries[i].bid = self.minimumBid
	self.tokenId = _tokenId
	self.ended = False

# External function to reset after duplication. Can only be called once, and only on duplicate contracts
@external
def reset(_tokenId: uint256):
	assert not self.isReset
	self.isReset = True
	self._reset(msg.sender, _tokenId)

### Auction functions ###
#
# Bid on the auction with the value sent together with this transaction.
# The value will only be refunded if the auction is not won (i.e. not highest bidder)
@external
@payable
def bid(_name: String[32]):
	# Check if bidding period is over.
	assert block.timestamp < self.auctionEnd
	# Check if bid is greater than highest bid plus the increment
	assert msg.value >= self.highestBid + increment
	# Track the refund for the previous highest bidder
	self.pendingReturns[self.highestBidder] += self.highestBid
	# Store new highest bidder address and bid amount
	self.highestBidder = msg.sender
	self.highestBid = msg.value

	# Store new entry by overwriting the oldest entry
	index: uint256 = self.totalBids % 4	
	self.entries[index].signer = msg.sender
	self.entries[index].name = _name
	self.entries[index].date = block.timestamp
	self.entries[index].bid = msg.value
	self.totalBids += 1
	# emit NewEntry event
	log NewEntry(self.highestBid)
	
# Withdraw a bid when you have been outbid. 
@external
def withdraw():
	pending_amount: uint256 = self.pendingReturns[msg.sender]
	# Cleaer pendingReturns to prevent re-entry
	self.pendingReturns[msg.sender] = 0
	send(msg.sender, pending_amount)

# End the auction, after auctionEnd is reached,  and coordinate transfer of NFT token
# to winner of the auction, sending the highest bid value to the previous owner
# If safeTransfer fails, then the highestBid is added to pendingReturns, allowing
# withdrawal of highestBid.
@external
def endAuction():
	# Follows three steps:
	# 1. checking conditions
	# 2. performing actions (potentially changing conditions)
	# 3. interacting with other contracts

	# 1. Conditions 
	# Check if auction endtime has been reached
	assert block.timestamp >= self.auctionEnd
	# Check if this function has already been called
	assert not self.ended	
	# Check if owner is a contract (i.e. NFT used as interface)
	assert self.owner.is_contract	

	# 2. Effects - end auction
	self.ended = True

	# 3. Interaction 
	# Find address of seller of token
	seller: address = NFT(self.owner).ownerOf(self.tokenId)
	# call safeTransfer on contract
	data: Bytes[1024] = b""
	NFT(self.owner).safeTransferFrom(seller, self.highestBidder, self.tokenId, data)
	
	# Check if transfer is complete by checking if highestBidder is now new token owner
	if NFT(self.owner).ownerOf(self.tokenId) == self.highestBidder:
		# if successfful, send highest bid value directly to previous owner
		send(seller, self.highestBid)
	else:
		# otherwise place highestBid into pendingReturns for future withdrawal
		self.pendingReturns[self.highestBidder] += self.highestBid

# Auction contract accepts any ETH through a default payable function
# However, there are no methods to reclaim it.
@external
@payable
def __default__():
	pass

