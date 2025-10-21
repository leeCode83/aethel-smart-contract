// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {AethelFactory} from "../src/aethel/AethelFactory.sol";
import {AethelMarketplace} from "../src/marketplace/AethelMarketplace.sol";
import {ProjectVault} from "../src/aethel/ProjectVault.sol";
import {ProjectAssets} from "../src/aethel/ProjectAssets.sol";
import {WUSDT} from "../src/aethel/WUSDT.sol";
import {TransferNotAllowed} from "../src/aethel/ProjectAssets.sol";

contract AethelTest is Test {
    // === Kontrak Utama ===
    AethelFactory public factory;
    AethelMarketplace public marketplace;
    WUSDT public stablecoin;

    // === Alamat Pengguna ===
    address public deployer = makeAddr("deployer");
    address public creator = makeAddr("creator");
    address public buyer = makeAddr("buyer");
    address public curator = makeAddr("curator");
    address public dao = makeAddr("dao");

    // === Variabel Test ===
    bytes32 public workHash = keccak256("my-artwork-data");
    string public constant ASSET_CONTRACT_URI = "ipfs://asset-collection/";
    string public constant GOT_URI = "ipfs://got-token/";
    string public constant CLT_URI = "ipfs://clt-token/";
    uint256 public constant STAKE_AMOUNT = 100 * 1e18;

    function setUp() public {
        vm.startPrank(deployer);
        stablecoin = new WUSDT();
        factory = new AethelFactory(address(stablecoin), dao);
        marketplace = new AethelMarketplace(address(stablecoin), address(factory));
        vm.stopPrank();

        stablecoin.mint(creator, 1000 * 1e18);
        stablecoin.mint(buyer, 1000 * 1e18);
    }

    function test_FullWorkflow_Success() public {
        // 1. KREATOR: Membuat ProjectVault
        vm.startPrank(creator);
        ProjectVault vault = ProjectVault(payable(factory.createProjectVault(ASSET_CONTRACT_URI)));
        vault.setCuratorOracle(curator);
        vault.setMarketplaceAddress(address(marketplace));
        vm.stopPrank();

        // 2. KREATOR: Melakukan Staking
        vm.startPrank(creator);
        stablecoin.approve(address(vault), STAKE_AMOUNT);
        vault.stampArtwork(workHash, GOT_URI, STAKE_AMOUNT);
        vm.stopPrank();

        // 3. KURATOR: Menyetujui karya
        uint256 creatorBalanceBefore = stablecoin.balanceOf(creator);
        vm.startPrank(curator);
        vault.handleCuratorResult(workHash, true);
        vm.stopPrank();
        
        (, , address assetAddress) = vault.getWorkStatus(workHash);
        ProjectAssets assets = ProjectAssets(payable(assetAddress));
        assertEq(assets.balanceOf(creator, 0), 1);
        assertEq(stablecoin.balanceOf(creator), creatorBalanceBefore + STAKE_AMOUNT);

        // 4. KREATOR: Mengatur Lisensi
        ProjectVault.LicenseTerm[] memory terms = new ProjectVault.LicenseTerm[](1);
        terms[0] = ProjectVault.LicenseTerm({ price: 50 * 1e18, licenseTypeURI: "ipfs://personal-use", cltId: 1 });
        vm.startPrank(creator);
        vault.setMarketplaceListing(workHash, terms);
        vm.stopPrank();

        // Verifikasi listing dengan memanggil fungsi yang sudah diubah namanya
        ProjectVault.LicenseTerm[] memory fetchedTerms = vault.getListingTerms(workHash);
        assertEq(fetchedTerms[0].price, 50 * 1e18);

        // 5. PEMBELI: Membeli lisensi
        uint256 price = fetchedTerms[0].price;
        uint256 fee = (price * marketplace.MARKETPLACE_FEE_PERCENT()) / 10000;
        uint256 creatorPayment = price - fee;
        uint256 creatorBalanceBeforePurchase = stablecoin.balanceOf(creator);

        vm.startPrank(buyer);
        stablecoin.approve(address(marketplace), price);
        marketplace.purchaseLicense(address(vault), workHash, 0, CLT_URI);
        vm.stopPrank();

        assertEq(assets.balanceOf(buyer, 1), 1);
        assertEq(stablecoin.balanceOf(creator), creatorBalanceBeforePurchase + creatorPayment);
        assertEq(stablecoin.balanceOf(address(marketplace)), fee);
    }

    function test_Fail_CurationRejected() public {
        vm.startPrank(creator);
        ProjectVault vault = ProjectVault(payable(factory.createProjectVault(ASSET_CONTRACT_URI)));
        vault.setCuratorOracle(curator);
        stablecoin.approve(address(vault), STAKE_AMOUNT);
        vault.stampArtwork(workHash, GOT_URI, STAKE_AMOUNT);
        vm.stopPrank();

        uint256 creatorBalanceBefore = stablecoin.balanceOf(creator);
        vm.startPrank(curator);
        vault.handleCuratorResult(workHash, false);
        vm.stopPrank();

        (, ProjectVault.StampStatus status, ) = vault.getWorkStatus(workHash);
        assertEq(uint(status), uint(ProjectVault.StampStatus.FAILED));
        assertEq(stablecoin.balanceOf(creator), creatorBalanceBefore);
    }

    function test_Fail_TransferCLT() public {
        vm.prank(creator);
        ProjectVault vault = ProjectVault(payable(factory.createProjectVault(ASSET_CONTRACT_URI)));
        
        ProjectAssets assets = ProjectAssets(payable(address(vault.assetsContract())));
        vm.prank(address(vault));
        assets.mintCLT(buyer, 1, 1, CLT_URI);

        vm.startPrank(buyer);
        vm.expectRevert(TransferNotAllowed.selector);
        assets.safeTransferFrom(buyer, creator, 1, 1, "");
        vm.stopPrank();
    }
}