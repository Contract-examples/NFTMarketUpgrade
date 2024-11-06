// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../src/NFTMarket.sol";
import "../src/MyERC20PermitToken.sol";
import "../src/MyNFT.sol";

contract NFTMarketTest is Test, IERC20Errors {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    NFTMarket public market;
    MyERC20PermitToken public paymentToken;
    MyNFT public nftContract;

    address public owner;
    address public seller;
    address public seller2;
    address public seller3;
    address public buyer;
    address public buyer2;
    address public buyer3;
    address public whitelistBuyer;
    uint256 public whitelistBuyerPrivateKey;
    uint256 public tokenId;
    uint256 public whitelistSignerPrivateKey;
    address public whitelistSigner;

    function setUp() public {
        owner = address(this);
        paymentToken = new MyERC20PermitToken("MyNFTToken2612", "MTK2612", 1_000_000 * 10 ** 18);
        // set owner to this contract
        nftContract = new MyNFT("MyNFT", "MFT", 1000);
        market = new NFTMarket();
        market.initialize(address(nftContract), address(paymentToken), owner);

        // use a fixed private key to generate the address
        whitelistSignerPrivateKey = 0x3389;
        whitelistSigner = vm.addr(whitelistSignerPrivateKey);
        whitelistBuyerPrivateKey = 0x4489;
        whitelistBuyer = vm.addr(whitelistBuyerPrivateKey);

        // make address
        seller = makeAddr("seller");
        seller2 = makeAddr("seller2");
        seller3 = makeAddr("seller3");
        buyer = makeAddr("buyer");
        buyer2 = makeAddr("buyer2");
        buyer3 = makeAddr("buyer3");

        // give buyer/buyer2/buyer3 1000 tokens
        paymentToken.mint(buyer, 20_000 * 10 ** paymentToken.decimals());
        paymentToken.mint(buyer2, 1000 * 10 ** paymentToken.decimals());
        paymentToken.mint(buyer3, 1000 * 10 ** paymentToken.decimals());

        // give whitelist buyer 2000 tokens
        paymentToken.mint(whitelistBuyer, 2000 * 10 ** paymentToken.decimals());

        // mock owner
        vm.prank(owner);

        // let owner mint nft to seller
        nftContract.safeMint(seller, "ipfs://gmh-001");
        nftContract.safeMint(seller2, "ipfs://gmh-002");
        nftContract.safeMint(seller3, "ipfs://gmh-003");

        // get actual tokenId
        // seller
        {
            uint256 i = 0; // set idx = 0
            uint256 currentTokenId = nftContract.tokenOfOwnerByIndex(seller, i);
            console2.log("Index: %s, Minted NFT with ID: %s", i, currentTokenId);
            console2.log("NFT owner:", vm.getLabel(nftContract.ownerOf(currentTokenId)));
        }
        // seller2
        {
            uint256 i = 0; // set idx = 0
            uint256 currentTokenId = nftContract.tokenOfOwnerByIndex(seller2, i);
            console2.log("Index: %s, Minted NFT with ID: %s", i, currentTokenId);
            console2.log("NFT owner:", vm.getLabel(nftContract.ownerOf(currentTokenId)));
        }
        // seller3
        {
            uint256 i = 0; // set idx = 0
            uint256 currentTokenId = nftContract.tokenOfOwnerByIndex(seller3, i);
            console2.log("Index: %s, Minted NFT with ID: %s", i, currentTokenId);
            console2.log("NFT owner:", vm.getLabel(nftContract.ownerOf(currentTokenId)));
        }
    }

    function testListNFT(uint8 sellerIndex, uint256 price) public {
        // limit sellerIndex
        sellerIndex = uint8(bound(uint256(sellerIndex), 0, 2));

        // set a reasonable price range
        uint256 minPrice = 1; // minimum price is 1 wei
        uint256 maxPrice = 1000 * 10 ** paymentToken.decimals(); // maximum price remains the same
        price = bound(price, minPrice, maxPrice);

        address[] memory sellers = new address[](3);
        sellers[0] = seller;
        sellers[1] = seller2;
        sellers[2] = seller3;

        address currentSeller = sellers[sellerIndex];
        uint256 tokenId = sellerIndex;

        vm.startPrank(currentSeller);

        nftContract.approve(address(market), tokenId);
        market.list(tokenId, price);

        vm.stopPrank();

        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);
        console2.log("Seller: listedSeller:", vm.getLabel(listedSeller));
        console2.log("Seller: listedPrice:", listedPrice);
        assertEq(listedSeller, currentSeller);
        assertEq(listedPrice, price);
    }

    function testListNotOwner() public {
        // nft price
        uint256 price = 100 * 10 ** paymentToken.decimals();

        // mock seller
        vm.startPrank(seller);

        // seller's nft tokenId is 0
        tokenId = 0;

        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);

        // set expect revert
        vm.expectRevert(NFTMarket.NotTheOwner.selector);

        // seller's nft tokenId is 0
        // we set 1 to test "not owner"
        tokenId = 1;

        // list nft
        market.list(tokenId, price);

        vm.stopPrank();
    }

    function testListNFTNotApproved() public {
        // nft price
        uint256 price = 100 * 10 ** paymentToken.decimals();

        // mock seller
        vm.startPrank(seller);

        // seller's nft tokenId is 0
        tokenId = 0;

        // set expect revert
        vm.expectRevert(NFTMarket.NFTNotApproved.selector);

        // list nft
        market.list(tokenId, price);

        vm.stopPrank();
    }

    function testListNFTZeroPrice() public {
        // nft price
        uint256 price = 0;

        // mock seller
        vm.startPrank(seller);

        // seller's nft tokenId is 0
        tokenId = 0;

        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);

        // set expect revert
        vm.expectRevert(NFTMarket.PriceMustBeGreaterThanZero.selector);

        // list nft
        market.list(tokenId, price);

        vm.stopPrank();
    }

    function testListEmitEvent() public {
        // nft price
        uint256 price = 100 * 10 ** paymentToken.decimals();

        // mock seller
        vm.startPrank(seller);

        // seller's nft tokenId is 0
        tokenId = 0;

        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);

        // expect emit NFTListed event
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.NFTListed(tokenId, seller, price);

        // list nft
        market.list(tokenId, price);

        vm.stopPrank();
    }

    function testUnlistNFT() public {
        uint256 price = 100 * 10 ** paymentToken.decimals();

        // seller's nft tokenId is 0
        tokenId = 0;

        vm.startPrank(seller);

        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);

        // list nft
        market.list(tokenId, price);

        // unlist nft
        market.unlist(tokenId);

        vm.stopPrank();

        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);
        console2.log("listedSeller:", vm.getLabel(listedSeller));
        console2.log("listedPrice:", listedPrice);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
    }

    function testUnlistNFTNotTheSeller() public {
        uint256 price = 100 * 10 ** paymentToken.decimals();

        // seller's nft tokenId is 0
        tokenId = 0;

        vm.startPrank(seller);

        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);

        // list nft
        market.list(tokenId, price);

        // test unlist nft by not owner
        tokenId = 1;
        // set expect revert
        vm.expectRevert(NFTMarket.NotSellerOrNotListed.selector);
        // unlist nft
        market.unlist(tokenId);

        vm.stopPrank();
    }

    function testUnlistNFTEmitEvent() public {
        uint256 price = 100 * 10 ** paymentToken.decimals();

        // seller's nft tokenId is 0
        tokenId = 0;

        vm.startPrank(seller);

        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);

        // list nft
        market.list(tokenId, price);

        // expect emit NFTUnlisted event
        vm.expectEmit(true, false, false, false);
        emit NFTMarket.NFTUnlisted(tokenId);

        // unlist nft
        market.unlist(tokenId);

        vm.stopPrank();
    }

    function testBuyNFT() public {
        uint256 price = 200 * 10 ** paymentToken.decimals();

        vm.startPrank(seller);

        // seller's nft tokenId is 0
        tokenId = 0;

        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);

        // list nft
        market.list(tokenId, price);
        vm.stopPrank();

        // buyer buy nft
        vm.startPrank(buyer);
        // let nft-market contract operate paymentToken (price)
        paymentToken.approve(address(market), price);
        market.buyNFT(tokenId);
        vm.stopPrank();

        console2.log("nftContract.ownerOf(tokenId):", vm.getLabel(nftContract.ownerOf(tokenId)));
        console2.log("buyer:", vm.getLabel(buyer));
        console2.log("paymentToken.balanceOf(seller):", paymentToken.balanceOf(seller));
        console2.log("price:", price);

        assertEq(nftContract.ownerOf(tokenId), buyer);
        assertEq(paymentToken.balanceOf(seller), price);
    }

    function testBuyNFTRepeat() public {
        uint256 price = 200 * 10 ** paymentToken.decimals();

        vm.startPrank(seller);

        // seller's nft tokenId is 0
        tokenId = 0;

        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);

        // list nft
        market.list(tokenId, price);
        vm.stopPrank();

        // buyer buy nft
        vm.startPrank(buyer);
        // let nft-market contract operate paymentToken (price)
        paymentToken.approve(address(market), price);
        market.buyNFT(tokenId);

        // set expect revert
        vm.expectRevert(NFTMarket.NFTNotListed.selector);

        // buy nft again
        market.buyNFT(tokenId);

        vm.stopPrank();
    }

    function testBuyNFTInsufficientBalance() public {
        // set a very high price to test insufficient balance
        uint256 price = 20_000_000 * 10 ** paymentToken.decimals();

        vm.startPrank(seller);

        // seller's nft tokenId is 0
        tokenId = 0;

        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);

        // list nft
        market.list(tokenId, price);
        vm.stopPrank();

        // buyer buy nft
        vm.startPrank(buyer);
        // let nft-market contract operate paymentToken (price)
        paymentToken.approve(address(market), price);

        // set expect revert (for openzeppelin)
        // bytes memory expectedError =
        //     abi.encodeWithSelector(ERC20InsufficientBalance.selector, buyer, paymentToken.balanceOf(buyer), price);
        // vm.expectRevert(expectedError);

        // set expect revert (for solady)
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);

        market.buyNFT(tokenId);
        vm.stopPrank();
    }

    function testBuyNFTNotListed() public {
        uint256 price = 100 * 10 ** paymentToken.decimals();

        // seller's nft tokenId is 0
        tokenId = 0;

        // buyer buy nft
        vm.startPrank(buyer);

        // let nft-market contract operate paymentToken (price)
        paymentToken.approve(address(market), price);

        // set expect revert
        vm.expectRevert(NFTMarket.NFTNotListed.selector);

        market.buyNFT(tokenId);
        vm.stopPrank();
    }

    function testBuyNFTheSenderIsTheSeller() public {
        uint256 price = 100 * 10 ** paymentToken.decimals();

        // seller's nft tokenId is 0
        tokenId = 0;
        vm.startPrank(seller);
        // let nft-market contract operate paymentToken
        nftContract.approve(address(market), tokenId);
        // list nft
        market.list(tokenId, price);

        // let nft-market contract operate paymentToken (price)
        paymentToken.approve(address(market), price);

        // set expect revert
        vm.expectRevert(NFTMarket.TheSenderIsTheSeller.selector);
        market.buyNFT(tokenId);

        vm.stopPrank();
    }

    function testBuyNFTEmitEvent() public {
        uint256 price = 10 * 10 ** paymentToken.decimals();

        // seller's nft tokenId is 0
        tokenId = 0;
        vm.startPrank(seller);

        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);

        // list nft
        market.list(tokenId, price);
        vm.stopPrank();

        // buyer buy nft
        vm.startPrank(buyer);
        // let nft-market contract operate paymentToken (price)
        paymentToken.approve(address(market), price);

        // expect emit NFTSold event
        vm.expectEmit(true, true, true, true);
        emit NFTMarket.NFTSold(tokenId, seller, buyer, price);

        market.buyNFT(tokenId);
        vm.stopPrank();
    }

    function testBuyNFTCallback() public {
        uint256 price = 100 * 10 ** paymentToken.decimals();

        // seller's nft tokenId is 0
        tokenId = 0;

        // list nft
        vm.startPrank(seller);
        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        // buyer transfer to market contract
        vm.startPrank(buyer);
        bytes memory data = abi.encode(tokenId);

        // transfer token to nft-market contract and call buyNFT
        paymentToken.transferAndCall(address(market), price, data);
        vm.stopPrank();

        console2.log("nftContract.ownerOf(tokenId):", vm.getLabel(nftContract.ownerOf(tokenId)));
        console2.log("buyer:", vm.getLabel(buyer));
        console2.log("paymentToken.balanceOf(seller):", paymentToken.balanceOf(seller));
        console2.log("price:", price);

        assertEq(nftContract.ownerOf(tokenId), buyer);
        assertEq(paymentToken.balanceOf(seller), price);
    }

    function testBuyNFTCallbackTokensReceivedFailed() public {
        uint256 price = 100 * 10 ** paymentToken.decimals();

        // seller's nft tokenId is 0
        tokenId = 0;

        // list nft
        vm.startPrank(seller);
        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        // buyer transfer to market contract
        vm.startPrank(buyer);
        bytes memory data = abi.encode("123");

        // set expect revert
        vm.expectRevert(MyERC20PermitToken.TokensReceivedFailed.selector);

        // transfer token to nft-market contract and call buyNFT
        paymentToken.transferAndCall(address(market), price, data);
        vm.stopPrank();
    }

    function testBuyNFTCallbackInsufficientPayment() public {
        // set a very high price to test insufficient balance
        uint256 price = 20_000_000 * 10 ** paymentToken.decimals();

        // seller's nft tokenId is 0
        tokenId = 0;

        // list nft
        vm.startPrank(seller);
        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        // buyer transfer to market contract
        vm.startPrank(buyer);
        bytes memory data = abi.encode(tokenId);

        // set expect revert
        bytes memory expectedError =
            abi.encodeWithSelector(ERC20InsufficientBalance.selector, buyer, paymentToken.balanceOf(buyer), price);
        vm.expectRevert(expectedError);

        // transfer token to nft-market contract and call buyNFT
        paymentToken.transferAndCall(address(market), price, data);
        vm.stopPrank();
    }

    function testBuyNFTCallbackPaidMoreThanPrice() public {
        uint256 price = 500 * 10 ** paymentToken.decimals();

        // seller's nft tokenId is 0
        tokenId = 0;

        // list nft
        vm.startPrank(seller);
        // let nft-market contract operate nft contract (tokenID)
        nftContract.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        // buyer transfer to market contract
        vm.startPrank(buyer);
        bytes memory data = abi.encode(tokenId);
        // transfer token to nft-market contract and call buyNFT

        // paid more than price
        uint256 paidPrice = price * 2;
        uint256 refundPrice = paidPrice - price;
        uint256 beforBalance = paymentToken.balanceOf(buyer) - paidPrice;

        // expect emit Refund event
        vm.expectEmit(true, false, false, true);
        emit NFTMarket.Refund(buyer, refundPrice);

        paymentToken.transferAndCall(address(market), paidPrice, data);

        console2.log("paymentToken.balanceOf(buyer):", paymentToken.balanceOf(buyer));
        console2.log("price:", price);
        console2.log("paidPrice:", paidPrice);

        assertEq(paymentToken.balanceOf(buyer), beforBalance + refundPrice);

        vm.stopPrank();
    }

    // test fuzzing
    function testFuzzListAndBuyNFT(uint256 price, uint256 buyerSeed) public {
        uint256 decimals = paymentToken.decimals();
        console2.log("decimals:", decimals);
        uint256 minPrice = 10 ** (decimals - 2); // 0.01 token
        console2.log("minPrice:", minPrice);
        uint256 maxPrice = 10_000 * 10 ** decimals; // 10,000 tokens
        console2.log("maxPrice:", maxPrice);

        price = bound(price, minPrice, maxPrice);
        console2.log("Bound result", price);

        // Generate a valid EOA address for the buyer randomly
        address fuzzBuyer = address(uint160(uint256(keccak256(abi.encode(buyerSeed)))));
        // Ensure fuzzBuyer is not the seller
        vm.assume(fuzzBuyer != seller && fuzzBuyer != address(0));
        console2.log("fuzzBuyer:", vm.getLabel(fuzzBuyer));

        // Mint 200_000 tokens to the fuzzy buyer
        vm.prank(owner);
        paymentToken.mint(fuzzBuyer, 200_000 * 10 ** decimals);

        uint256 beforeBalanceOfFuzzBuyer = paymentToken.balanceOf(fuzzBuyer);
        console2.log("beforeBalanceOfFuzzBuyer:", beforeBalanceOfFuzzBuyer);
        uint256 beforeBalanceOfSeller = paymentToken.balanceOf(seller);
        console2.log("beforeBalanceOfSeller:", beforeBalanceOfSeller);

        // List NFT
        vm.startPrank(seller);
        tokenId = 0;
        nftContract.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        // Buy NFT
        vm.startPrank(fuzzBuyer);
        paymentToken.approve(address(market), price);
        market.buyNFT(tokenId);
        vm.stopPrank();

        console2.log("nftContract.ownerOf(tokenId):", vm.getLabel(nftContract.ownerOf(tokenId)));
        console2.log("fuzzBuyer:", vm.getLabel(fuzzBuyer));

        // Assert the NFT ownership and token balances
        assertEq(nftContract.ownerOf(tokenId), fuzzBuyer);
        assertEq(paymentToken.balanceOf(seller), beforeBalanceOfSeller + price);
        assertEq(paymentToken.balanceOf(fuzzBuyer), beforeBalanceOfFuzzBuyer - price);

        console2.log("Fuzzy test passed with price:", price);
        console2.log("Buyer:", vm.getLabel(fuzzBuyer));
    }

    function testNoTokenBalanceInMarket() public {
        uint256 initialPrice = 100 * 10 ** paymentToken.decimals();
        uint256 higherPrice = 150 * 10 ** paymentToken.decimals();

        // List NFT
        vm.startPrank(seller);
        tokenId = 0;
        nftContract.approve(address(market), tokenId);
        market.list(tokenId, initialPrice);
        vm.stopPrank();

        // Check market balance before any transaction
        assertEq(paymentToken.balanceOf(address(market)), 0);

        // Buy NFT
        vm.startPrank(buyer);
        paymentToken.approve(address(market), initialPrice);
        market.buyNFT(tokenId);
        vm.stopPrank();

        // Check market balance after buying
        assertEq(paymentToken.balanceOf(address(market)), 0);

        // List NFT again with a higher price
        vm.startPrank(buyer);
        nftContract.approve(address(market), tokenId);
        market.list(tokenId, higherPrice);
        vm.stopPrank();

        // Buy NFT again with excess payment
        vm.startPrank(buyer2);
        paymentToken.approve(address(market), higherPrice + 10 * 10 ** paymentToken.decimals());
        bytes memory data = abi.encode(tokenId);
        paymentToken.transferAndCall(address(market), higherPrice + 10 * 10 ** paymentToken.decimals(), data);
        vm.stopPrank();

        // Check market balance after buying with excess payment
        assertEq(paymentToken.balanceOf(address(market)), 0);
    }

    function testPermitBuy() public {
        uint256 price = 100 * 10 ** paymentToken.decimals();
        uint256 tokenId = 0;
        uint256 deadline = block.timestamp + 1 hours;

        //set whitelist signer
        vm.prank(owner);
        market.setWhitelistSigner(whitelistSigner);

        // list NFT
        vm.startPrank(seller);
        nftContract.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        // generate whitelist signature
        bytes32 messageHash = keccak256(abi.encodePacked(whitelistBuyer, tokenId));
        console2.log("messageHash: %s", Strings.toHexString(uint256(messageHash)));

        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        console2.log("ethSignedMessageHash: %s", Strings.toHexString(uint256(ethSignedMessageHash)));

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(whitelistSignerPrivateKey, ethSignedMessageHash);
        console2.log("v1: %s", Strings.toHexString(uint256(v1)));
        console2.log("r1: %s", Strings.toHexString(uint256(r1)));
        console2.log("s1: %s", Strings.toHexString(uint256(s1)));

        bytes memory whitelistSignature = abi.encodePacked(r1, s1, v1);
        console2.log("whitelistSignature: ");
        console2.logBytes(whitelistSignature);

        // generate ERC2612 permit signature
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                paymentToken.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        whitelistBuyer,
                        address(market),
                        price,
                        paymentToken.nonces(whitelistBuyer),
                        deadline
                    )
                )
            )
        );
        console2.log("permitHash: %s", Strings.toHexString(uint256(permitHash)));

        // sign the permit hash
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(whitelistBuyerPrivateKey, permitHash);
        console2.log("v2: %s", Strings.toHexString(uint256(v2)));
        console2.log("r2: %s", Strings.toHexString(uint256(r2)));
        console2.log("s2: %s", Strings.toHexString(uint256(s2)));

        // execute permitBuy
        vm.prank(whitelistBuyer);
        market.permitBuy(tokenId, price, deadline, v2, r2, s2, whitelistSignature);

        // verify the result
        assertEq(nftContract.ownerOf(tokenId), whitelistBuyer);
        assertEq(paymentToken.balanceOf(seller), price);
        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);

        // query listing
        (address listingSeller, uint256 listingPrice) = market.listings(tokenId);
        console2.log("listingSeller: %d", listingSeller);
        console2.log("listingPrice: %d", listingPrice);
    }

    function testPermitBuyNotWhitelisted() public {
        uint256 price = 100 * 10 ** paymentToken.decimals();
        uint256 tokenId = 0;
        uint256 deadline = block.timestamp + 1 hours;

        // set whitelist signer
        vm.prank(owner);
        market.setWhitelistSigner(whitelistSigner);

        // list NFT
        vm.startPrank(seller);
        nftContract.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        // generate invalid whitelist signature
        bytes32 whitelistMessageHash = keccak256(abi.encodePacked(whitelistBuyer, tokenId));
        (uint8 v1, bytes32 r1, bytes32 s1) =
            vm.sign(uint256(keccak256(abi.encodePacked("invalidSigner"))), whitelistMessageHash);
        bytes memory whitelistSignature = abi.encodePacked(r1, s1, v1);

        // generate ERC2612 permit signature
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                paymentToken.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        whitelistBuyer,
                        address(market),
                        price,
                        paymentToken.nonces(whitelistBuyer),
                        deadline
                    )
                )
            )
        );

        // sign the permit hash
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(whitelistBuyerPrivateKey, permitHash);

        // try to execute permitBuy, should fail
        vm.prank(whitelistBuyer);
        vm.expectRevert(NFTMarket.NotSignedByWhitelistSigner.selector);
        market.permitBuy(tokenId, price, deadline, v2, r2, s2, whitelistSignature);
    }
}

// // test invariant
// contract NFTMarketInvariantTest is Test {
//     NFTMarket public market;
//     MyERC20PermitToken public paymentToken;
//     MyNFT public nftContract;
//     address public owner;
//     address[] public users;

//     function setUp() public {
//         owner = address(this);
//         paymentToken = new MyERC20PermitToken("MyNFTToken2612", "MTK2612", 1_000_000 * 10 ** 18);
//         nftContract = new MyNFT("MyNFT", "MFT", 1000);
//         market = new NFTMarket();
//         market.initialize(address(nftContract), address(paymentToken), owner);

//         // Create some users
//         for (uint256 i = 0; i < 5; i++) {
//             address user = address(uint160(i + 1));
//             users.push(user);
//             paymentToken.mint(user, 1000 * 10 ** 18);
//             nftContract.safeMint(user, string(abi.encodePacked("ipfs://test-url-", Strings.toString(i))));
//         }

//         // Approve market for all users
//         for (uint256 i = 0; i < users.length; i++) {
//             vm.prank(users[i]);
//             nftContract.setApprovalForAll(address(market), true);
//             paymentToken.approve(address(market), type(uint256).max);
//         }

//         // Set up invariant test targets
//         targetContract(address(market));
//         for (uint256 i = 0; i < users.length; i++) {
//             targetSender(users[i]);
//         }
//     }

//     function invariant_marketHasNoBalance() public {
//         assertEq(paymentToken.balanceOf(address(market)), 0);
//     }

//     function invariant_listingsAreValid() public {
//         for (uint256 i = 0; i < 5; i++) {
//             (address seller, uint256 price) = market.listings(i);
//             if (seller != address(0)) {
//                 assertEq(nftContract.ownerOf(i), seller);
//                 assertEq(price > 0, true);
//             }
//         }
//     }

//     function invariant_nftOwnersHaveCorrectBalance() public {
//         for (uint256 i = 0; i < 5; i++) {
//             address owner = nftContract.ownerOf(i);
//             (address seller, uint256 price) = market.listings(i);
//             if (seller == address(0)) {
//                 // NFT is not listed, owner should have it
//                 assertEq(nftContract.balanceOf(owner), 1);
//             } else {
//                 // NFT is listed, seller should not have it
//                 assertEq(nftContract.balanceOf(seller), 0);
//             }
//         }
//     }
// }
