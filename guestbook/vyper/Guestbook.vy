# pragma @version ^0.2.4

# Guestbook entry structure containing a single entry
struct gbentry:
    signer: address
    name: String[32]
    email: String[32]
    message: String[100]
    date: uint256
    bounty_entry: uint256

# Size of the guestbook
ENTRIES: constant(uint256) = 3

# Owner of the guestbook contract to send funds to upon selfdestruct
owner: public(address)

# List of guestbook entries
gb: public(gbentry[ENTRIES])

# Current minimum bounty.  Calls to sign guestbook must exceed this
# value in order to be added.
bounty: public(uint256)

# Event emitted to web3 front-end when the guestbook changes. Sends
# the new bounty value.
event Entry:
    value: uint256

# Constructor that initializes guestbook and its initial entries
@external
def __init__():
    self.owner = msg.sender
    self.bounty = 0
    for i in range(ENTRIES):
        self.gb[i].signer = msg.sender
        self.gb[i].name = "Owner of Contract"
        self.gb[i].email = "owner@pdx.edu"
        self.gb[i].message = "Hello!"
        self.gb[i].date = block.timestamp
        self.gb[i].bounty_entry = convert(i*10,uint256)

# Finds the minimum bounty value and updates the storage variable for it
@internal
def update_bounty():
    minimum: uint256 = 0
    for i in range(ENTRIES):
        if (minimum == 0) or (self.gb[i].bounty_entry < minimum):
            minimum = self.gb[i].bounty_entry
    self.bounty = minimum

# Implement insertion of new entry. Signer must supply sufficient funds
# in excess of the bounty in order for call to succeed.  Upon success,
# emit Event to front-end
@external
@payable
def sign(name: String[32], email: String[32], message: String[100]):
    assert msg.value > self.bounty, "ETH sent in msg.value not more than bounty"
    for i in range(ENTRIES):
        if self.gb[i].bounty_entry == self.bounty:
            self.gb[i].signer = msg.sender
            self.gb[i].name = name
            self.gb[i].email = email
            self.gb[i].message = message
            self.gb[i].date = block.timestamp
            self.gb[i].bounty_entry = msg.value
            break
    self.update_bounty()
    log Entry(self.bounty)

# Destroy contract and return funds to the contract owner
@external
def cashOut():
    selfdestruct(self.owner)

# Contract accepts any ETH someone wants to send us!
@external
@payable
def __default__():
    pass
