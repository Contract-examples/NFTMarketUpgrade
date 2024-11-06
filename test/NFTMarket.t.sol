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
import "@uups-proxy-factory-sdk/sdk/IUUPSProxyFactory.sol";
import "../src/NFTMarket.sol";
import "../src/MyERC20PermitToken.sol";
import "../src/MyNFT.sol";

contract NFTMarketTest is Test, IERC20Errors {
    bytes32 salt = keccak256(abi.encodePacked("salt"));

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

    IUUPSProxyFactory factory;
    address proxy;

    function setUp() public {
        factory = IUUPSProxyFactory(deployCode("../lib/UUPSProxyFactorySDK/abi/UUPSProxyFactory.sol:UUPSProxyFactory"));

        owner = address(this);
        paymentToken = new MyERC20PermitToken("MyNFTToken2612", "MTK2612", 1_000_000 * 10 ** 18);
        // set owner to this contract
        nftContract = new MyNFT("MyNFT", "MFT", 1000);
        market = new NFTMarket();
        bytes memory initData =
            abi.encodeWithSelector(NFTMarket.initialize.selector, address(nftContract), address(paymentToken), owner);
        address predictedProxy = factory.predictProxyAddress(address(market), initData, salt);
        console2.log("Predicted proxy address:", predictedProxy);

        proxy = factory.deployProxy(address(market), initData, salt);
        console2.log("Deployed proxy address:", proxy);

        market = NFTMarket(payable(proxy));

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
}
