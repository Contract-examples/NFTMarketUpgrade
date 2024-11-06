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
import "../src/NFTMarketV2.sol";
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
    uint256 public sellerPrivateKey;
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
        sellerPrivateKey = 0x1189;
        seller = vm.addr(sellerPrivateKey);
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

    function testListNFTV2(uint8 sellerIndex, uint256 price) public {
        vm.startPrank(owner);
        NFTMarketV2 marketV2 = new NFTMarketV2();
        NFTMarketV2(proxy).upgradeToAndCall(
            address(marketV2),
            abi.encodeWithSelector(marketV2.initialize.selector, address(nftContract), address(paymentToken), owner)
        );
        vm.stopPrank();

        marketV2 = NFTMarketV2(proxy);

        {
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

            nftContract.approve(address(marketV2), tokenId);
            marketV2.list(tokenId, price);

            vm.stopPrank();

            (address listedSeller, uint256 listedPrice) = marketV2.listings(tokenId);
            console2.log("Seller: listedSeller:", vm.getLabel(listedSeller));
            console2.log("Seller: listedPrice:", listedPrice);
            assertEq(listedSeller, currentSeller);
            assertEq(listedPrice, price);
        }
    }

    function testListWithSignatureV2() public {
        // upgrade to v2
        vm.startPrank(owner);
        NFTMarketV2 marketV2 = new NFTMarketV2();
        NFTMarketV2(proxy).upgradeToAndCall(
            address(marketV2),
            abi.encodeWithSelector(marketV2.initialize.selector, address(nftContract), address(paymentToken), owner)
        );
        vm.stopPrank();

        marketV2 = NFTMarketV2(proxy);

        uint256 tokenId = 0;
        uint256 price = 100 * 10 ** paymentToken.decimals();
        uint256 deadline = block.timestamp + 1 hours;

        // set approval for all
        vm.prank(seller);
        nftContract.setApprovalForAll(address(marketV2), true);

        // generate signature
        bytes32 messageHash = marketV2.getListingMessageHash(tokenId, price, deadline);
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // call listWithSignature
        vm.prank(seller);
        marketV2.listWithSignature(tokenId, price, deadline, signature);

        // verify listing result
        (address listedSeller, uint256 listedPrice) = marketV2.listings(tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
    }
}
