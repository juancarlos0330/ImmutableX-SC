// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Collectionmanager.sol";
import "./NFTCollection.sol";

contract NFTMarketplace {

  NFTCollection nftCollection;
  CollectionManager collectionmanager;
  
  
  mapping (string => NFTCollection) Collections;

  uint256 count;
  uint256 public offerCount;
  mapping (string => mapping(uint256 => _Offer)) public offers;
  mapping (string  => mapping(address => uint256)) public userFunds;
  mapping(string => mapping(uint256 => Seller)) public sellers;
   
  address private treasury = 0x076F605BF8d2bD03c991cECcc2B4a1d5bC50BaaB; // Treasury Account
  address private dev = 0x38CE0D89101129A94f913248fd9ce99ab259B968; // Dev Account

  struct _Offer {
    uint256 offerId;
    uint256 id;
    address user;
    uint256 price;
    bool fulfilled;
    bool cancelled;
  }

  struct Seller {
       address userAddres;
       uint256 balance;
   }

  event Offer(
    uint256 offerId,
    uint256 id,
    address user,
    uint256 price,
    bool fulfilled,
    bool cancelled
  );

  event OfferFilled(uint256 offerId, uint256 id, address newOwner);
  event OfferCancelled(uint256 offerId, uint256 id, address owner);
  event ClaimFunds(address user, uint256 amount);

  constructor(address _collectionmanager) {
    collectionmanager = CollectionManager(_collectionmanager);
  }

  // Get Treasury wallet 
  function gettreasury() public view returns(address) {
      return treasury;
  }

  // Set Treasury Wallet
  function settreasury(address _newAddr) external {
      require(msg.sender == 0xaaaffAb7763fB811f3d4C692BdA070A8474BcE93);
      treasury = _newAddr;
  } 

  // Get Dev wallet 
  function getdevwallet() public view returns(address) {
      return dev;
  }

  // Set dev Wallet
  function setdevwallet(address _newAddr) external {
    require(msg.sender == 0xaaaffAb7763fB811f3d4C692BdA070A8474BcE93);
    dev = _newAddr;
  }

  
  function makeOffer(string memory _collectionName , uint256 _id, uint256 _price) public {
    require(collectionmanager.Ex_collectionnameexists(_collectionName), "Collection should be exist !");
    nftCollection = collectionmanager.Ex_nftcollectionsbyname(_collectionName);
    Collections[_collectionName] = nftCollection;
    nftCollection.transferFrom(msg.sender, address(this), _id, msg.sender);
    offerCount ++;
    offers[_collectionName][offerCount] = _Offer(offerCount, _id, msg.sender, _price, false, false);
    emit Offer(offerCount, _id, msg.sender, _price, false, false);
  }

  function fillOffer(string memory _collectionName, uint256 _offerId) public payable {
    require(collectionmanager.Ex_collectionnameexists(_collectionName), "Collection should be exist !");
    _Offer storage _offer = offers[_collectionName][_offerId];
    require(_offer.offerId == _offerId, 'The offer must exist');
    require(_offer.user != msg.sender, 'The owner of the offer cannot fill it');
    require(!_offer.fulfilled, 'An offer cannot be fulfilled twice');
    require(!_offer.cancelled, 'A cancelled offer cannot be fulfilled');
    require(msg.value == _offer.price, 'The ETH amount should match with the NFT Price');

    Collections[_collectionName].transferFrom(address(this), msg.sender, _offer.id, address(this));
    _offer.fulfilled = true;
    userFunds[_collectionName][_offer.user] += msg.value*98/100;
    
    // Marketing fee 2%
    uint256 marketingfeetreasury = msg.value * 1 / 100; // marketing fee 1 %
    payable(treasury).transfer(marketingfeetreasury);
    uint256 marketingfeedev = msg.value * 1 / 100; // marketing fee 1 %
    payable(dev).transfer(marketingfeedev);

    // Royalty for Collaborator
    uint256 royaltyfee = msg.value * collectionmanager.getRoyalty(_collectionName) / 100;
    for (uint256 i=0; i < collectionmanager.getcollaborators(_collectionName).length; i++ ) {
      address colla = collectionmanager.getcollaborators(_collectionName)[i];
      uint256 funds = royaltyfee * collectionmanager.Getroyaltyvaluepercollaborators(colla) / 100;
      payable(colla).transfer(funds);
    }
    // Pay buyer from seller
    uint256 restfunds = msg.value - marketingfeetreasury - marketingfeedev - royaltyfee;
    payable(_offer.user).transfer(restfunds);

    sellers[_collectionName][count].userAddres = _offer.user;
    sellers[_collectionName][count].balance = msg.value;
    Collections[_collectionName].setTrack(msg.sender, _offer.id);
    count++;
    emit OfferFilled(_offerId, _offer.id, msg.sender);
  }

  function cancelOffer(string memory _collectionName, uint256 _offerId) public {
    require(collectionmanager.Ex_collectionnameexists(_collectionName), "Collection should be exist !");
    _Offer storage _offer = offers[_collectionName][_offerId];
    require(_offer.offerId == _offerId, 'The offer must exist');
    require(_offer.user == msg.sender, 'The offer can only be canceled by the owner');
    require(_offer.fulfilled == false, 'A fulfilled offer cannot be cancelled');
    require(_offer.cancelled == false, 'An offer cannot be cancelled twice');
    Collections[_collectionName].transferFrom(address(this), msg.sender, _offer.id, address(this));
    _offer.cancelled = true;
    emit OfferCancelled(_offerId, _offer.id, msg.sender);
  }

  // Fallback: reverts if Ether is sent to this smart-contract by mistake
  fallback () external {
    revert();
  }
}