# pragma @version ^0.2.4

# import ERC721
from vyper.interfaces import ERC721

implements: ERC721

# Interface for contract - used by safeTransferFrom()
# Allows this NFT contract to accept NFT tokens and send NFT tokens
# as a contract by providing correct returnValue checked during SafeTransferFrom()
interface ERC721Receiver:
	def onERC721Received(
		_operator: address,
		_from: address,
		_tokenId: uint256,
		_data: Bytes[1024]
		) -> bytes32: view

# Interface for Auction contract to reset storage variables in duplication when create_auction() is called
interface Auction:
	def reset(_tokenId: uint256): nonpayable


### Events for Transfer, Approval and ApprovalForAll ###

# Emits when the ownership of any NFT changes, except during creation of this contract
# NFT from sender, to receiver, with Id of NFT being transfered
event Transfer:
	sender: indexed(address)
	receiver: indexed(address)
	tokenId: indexed(uint256)

# Emits when the approved address for an NFT token changes or is reaffirmed. If the approved address is zero,
# this indicates there is no approval for this token. A transfer event means the approved address, if not zero,
# is reset to no one. The owner address is the current owner of the NFT token. The approved address is a valid
# address that is getting approval, and the tokenId indicates which NFT token is getting approval for.. 
event Approval:
	owner: indexed(address)
	approved: indexed(address)
	tokenId: indexed(uint256)

# Emits when an operator is enabled or disabled by an owner. When ApprovedForAll,an  Operators is  allowed 
# to manage all NFTS of the owner. The owner can set the operator's address approval to True (approved) or 
# False (approval is revoked)
event ApprovalForAll:
	owner: indexed(address)
	operator: indexed(address)
	approved: bool

# NFT ID to owner address mapping
idToOwner: HashMap[uint256, address]

# NFT ID to approved address mapping
idToApprovals: HashMap[uint256, address]

# NFT owner address to token count mapping
ownerToNFTokenCount: HashMap[address, uint256]

# Mapping of owner address to mapping of operator addresses and approval bools
ownerToOperators: HashMap[address, HashMap[address, bool]]

# Address of NFT deployer, who is allowed to mint new NFTs and create auctions
minter: address

# Storage variable to count number of NFTs minted
totalNFTs: uint256

# Mapping of interface id to bool - indicating supported or not
supportedInterfaces: HashMap[bytes32, bool]

# Interface ID of ERC165
ERC165_INTERFACE_ID: constant(bytes32) = 0x0000000000000000000000000000000000000000000000000000000001ffc9a7
# Interface ID of ERC721
ERC721_INTERFACE_ID: constant(bytes32) = 0x0000000000000000000000000000000000000000000000000000000080ac58cd

# Constructor
@external
def __init__():
	self.supportedInterfaces[ERC165_INTERFACE_ID] = True
	self.supportedInterfaces[ERC721_INTERFACE_ID] = True
	self.minter = msg.sender
	self.totalNFTs = 0


### View Functions ###

# Allows view of supported interfaces for this NFT
@view
@external
def supportsInterface(_interfaceID: bytes32) -> bool:
	return self.supportedInterfaces[_interfaceID]

# Gets number of NFTs owned by a specific address
# Throws if _owner is a zero address
@view
@external
def balanceOf(_owner: address) -> uint256:
	assert _owner != ZERO_ADDRESS
	return self.ownerToNFTokenCount[_owner]

# Returns address of owner for NFT with specified tokenId
@view
@external
def ownerOf(_tokenId: uint256) -> address:
	owner: address = self.idToOwner[_tokenId]
	assert owner != ZERO_ADDRESS
	return owner

# Returns approved address for a given NFT of tokenId
# Throws if tokenID is not a valid NFT
@view
@external
def getApproved(_tokenId: uint256) -> address:
	assert self.idToOwner[_tokenId] != ZERO_ADDRESS
	return self.idToApprovals[_tokenId]

# Returns boolean whether or not an operator address is approved by an owner address
@view
@external
def isApprovedForAll(_owner: address, _operator: address) -> bool:
	return (self.ownerToOperators[_owner])[_operator]

# Returns total number of NFT tokens - used to identify tokenId in Auction contract
# Currently tokens are minted in sequential order, but this just an implemenation choice
@view
@external
def totalTokens() -> uint256:
	return self.totalNFTs


### Transfer Utility Functions ###

# Returns boolean of whether _spender has approval to transfer a given _tokenId NFT, is approved for
# the token, or is the owner of the token
@view
@internal
def _isApprovedOrOwner(_spender: address, _tokenId: uint256) -> bool:
	owner: address = self.idToOwner[_tokenId]
	spenderIsOwner: bool = owner == _spender
	spenderIsApproved: bool = _spender == self.idToApprovals[_tokenId]
	spenderIsApprovedForAll: bool = (self.ownerToOperators[owner])[_spender]
	return (spenderIsOwner or spenderIsApproved) or spenderIsApprovedForAll

# Adds an NFT to a given address, throws if _tokenId is already owned by an address
# Used in mint and transferFrom functions
@internal
def _addTokenTo(_to: address, _tokenId: uint256):
	assert self.idToOwner[_tokenId] == ZERO_ADDRESS
	# set new owner
	self.idToOwner[_tokenId] = _to
	# increment token count of new owner
	self.ownerToNFTokenCount[_to] += 1

# Remove ownership address from a given NFT _tokenId
# Throws if _from address to remove is not the current owner of the NFT token
@internal
def _removeTokenFrom(_from: address, _tokenId: uint256):
	assert self.idToOwner[_tokenId] == _from
	# remove ownership of _from address
	self.idToOwner[_tokenId] = ZERO_ADDRESS
	# decrement token count of _from address
	self.ownerToNFTokenCount[_from] -= 1

# Reset (i.e. revoke) approvals for a given NFT _tokenId
# Throws if _owner is not the current owner of the NFT
@internal
def _clearApproval(_owner: address, _tokenId: uint256):
	assert self.idToOwner[_tokenId] == _owner
	if self.idToApprovals[_tokenId] != ZERO_ADDRESS:
		# clear approvals
		self.idToApprovals[_tokenId] = ZERO_ADDRESS

# Internal function to execute the transfer of an NFT
# Throws if msg.sender is not the current owner, operator, or approved for this _tokenId
# Throws if _to is the zero address, if _from is not current owner, or _tokenId is not valid NFT
@internal
def _transferFrom(_from: address, _to: address, _tokenId: uint256, _sender: address):
	# ensure requirements are met
	assert self._isApprovedOrOwner(_sender, _tokenId)
	# ensure transfer address is not zero
	assert _to != ZERO_ADDRESS
	# reset approval for NFT token
	self._clearApproval(_from, _tokenId)
	# remove token from previous owner
	self._removeTokenFrom(_from, _tokenId)
	# add NFT token to new owner _to
	self._addTokenTo(_to, _tokenId)
	# log transfer event
	log Transfer(_from, _to, _tokenId)


### External Transfer Functions ###

# Transfer NFT token _from to _to addresses. If _to is not capable of receiving NFTs
# the token may be lost permanently
# Throws if _from is not current owner, if _to is the zero address, or if _tokenId is not valid
@external
def transferFrom(_from: address, _to: address, _tokenId: uint256):
	self._transferFrom(_from, _to, _tokenId, msg.sender)

# Transfers ownership of NFT from one address to another address
# Used to coordinate escrow by Auction contract during endAuction()
# Throws if _from is not current owner, if _to is the zero address, if _tokenId is not a valid NFT
# If _to is a smart contract, calls onERC721Received on _to and throws if return value is not:
# 'bytes4(keccak256("onERC721Received(address, address, uint256, bytes)"))'
@external
def safeTransferFrom(
	_from: address,
	_to: address,
	_tokenId: uint256,
	_data: Bytes[1024]=b""
	):
	self._transferFrom(_from, _to, _tokenId, msg.sender)
	# check if _to is a contract address
	if _to.is_contract: 
		returnValue: bytes32 = ERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data)
		assert returnValue == method_id("onERC721Received(address,address,uint256,bytes)", output_type = bytes32)

# Set or reaffirm the approved address for an NFT. Zero address means NFT token has no approved address
# Throws unless msg.sender is NFT owner, or operator for the owner
# Throws if _tokenId is not a valid NFT, or if _approved is the current owner
@external
def approve(_approved: address, _tokenId: uint256):
	owner: address = self.idToOwner[_tokenId]
	# check if token is valid NFT
	assert owner != ZERO_ADDRESS
	# check if _approved is owner
	assert _approved != owner
	# check requirements are met
	senderIsOwner: bool = self.idToOwner[_tokenId] == msg.sender
	senderIsApprovedForAll: bool = (self.ownerToOperators[owner])[msg.sender]
	assert (senderIsOwner or senderIsApprovedForAll)
	# confirm approval
	self.idToApprovals[_tokenId] = _approved
	# log Approval event
	log Approval(owner, _approved, _tokenId)

# Adds or removes approval for an operator (third party address) to manage all of
# msg.sender's NFT tokens. Emits ApprovalForAll event. Works even if msg.sender
# does not own any tokens at the time of function call
# Throws if _operator is msg.sender
@external
def setApprovalForAll(_operator: address, _approved: bool):
	# check if _operator address is msg.sender
	assert _operator != msg.sender
	self.ownerToOperators[msg.sender][_operator] = _approved
	# log ApprovalForAll event
	log ApprovalForAll(msg.sender, _operator, _approved)


### Mint and Burn Functions ###

# Mints new NFT tokens - returns True if mint is successful
# Throws if msg.sender is not minter, if _to is zero address, or if _tokenId is already owned
@external
def mint(_to: address, _tokenId: uint256) -> bool:
	# ensure msg.sender is minter
	assert msg.sender == self.minter
	# check if _to is zero address
	assert _to != ZERO_ADDRESS
	# check if _tokenId is already owned by someone
	self._addTokenTo(_to, _tokenId)
	self.totalNFTs += 1
	# log Transfer event
	log Transfer(ZERO_ADDRESS, _to, _tokenId)
	return True

# Burns a specific NFT token
# Throws unless msg.sender is owner, operator, or approved address for the NFT
# Throws if _tokenId is not a valid NFT
@external
def burn(_tokenId: uint256):
	# check requirements are met
	assert self._isApprovedOrOwner(msg.sender, _tokenId)
	owner: address = self.idToOwner[_tokenId]
	# Throws if _tokenId is not valid
	assert owner != ZERO_ADDRESS
	self._clearApproval(owner, _tokenId)
	self._removeTokenFrom(owner, _tokenId)
	# log Transfer event
	log Transfer(owner, ZERO_ADDRESS, _tokenId)

# Internal function called during create_auction()
# Used to in essence to initiate a duplicate contract, by calling on 
# its reset() function to reset its relevant storage variables
@internal
def reset_auction(_target: address, _tokenId: uint256) -> bool:
	# check if address is not zero
	assert _target != ZERO_ADDRESS
	# check if address is contract
	assert _target.is_contract
	# instantiate new auction duplicate
	Auction(_target).reset(_tokenId)	
	return True

# Generates a new Auction contract based on existing one
# by duplicating the original contract and clearing all state variables
# Throws if caller is not also the minter and deployer of NFT
@external
def create_auction(_target: address) -> address:
	assert msg.sender == self.minter
	# create new auction contract based on existing target address
	new_auction: address = create_forwarder_to(_target)
	assert new_auction != ZERO_ADDRESS
	# set token id based on current total	
	tokenId: uint256 = self.totalNFTs
	# mint new token and add to minter
	self._addTokenTo(self.minter, tokenId)	
	self.totalNFTs += 1
	# log Transfer event
	log Transfer(ZERO_ADDRESS, self.minter, tokenId)
	# approve new auction contract as operator
	self.idToApprovals[tokenId] = new_auction
	# log Approval event
	log Approval(self.minter, new_auction, tokenId)
	# call reset on new contract
	self.reset_auction(new_auction, tokenId)	
	# return address of new auction	contract
	return new_auction

