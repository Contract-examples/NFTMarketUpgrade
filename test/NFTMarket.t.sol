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
        factory =
            IUUPSProxyFactory(deployCode("../lib/UUPSProxyFactorySDK/abi/UUPSProxyFactory.sol:UUPSProxyFactory"));

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

    function testInitialSetup() public {
        console2.log("Proxy address:", proxy);
    }
}
