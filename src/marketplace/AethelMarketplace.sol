// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Import OpenZeppelin Modules
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Import Interface ProjectVault yang dibutuhkan
import {IProjectVault }from "../interface/IProjectVault.sol"; 

// --- Custom Errors ---
error InvalidPrice();
error TransferFailed();
error InvalidAddress();
error InvalidListing();
error InvalidTermIndex();
error UnauthorizedCaller();

// --- DEFINISI LOKAL STRUCT ---
// Diperlukan agar compiler dapat mengidentifikasi tipe data array yang dikembalikan dari IProjectVault.
struct LicenseTerm {
    uint256 price;             
    string licenseTypeURI;      
    uint256 cltId;             
}

contract AethelMarketplace is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20; // Menggunakan SafeERC20 untuk keamanan transfer

    // --- KONFIGURASI IMMUTABLE DAN INTERFACE ---
    uint256 public constant MARKETPLACE_FEE_PERCENT = 300; // 3.00% (300 basis points)

    IERC20 public immutable stablecoinContract;
    address public immutable FACTORY_ADDRESS; 

    // --- EVENT ---
    event LicensePurchased(
        bytes32 indexed workHash,
        address indexed buyer,
        uint256 cltId,
        uint256 price
    );

    constructor(address _stablecoinAddress, address _factoryAddress)
        Ownable(msg.sender)
    {
        if (_stablecoinAddress == address(0) || _factoryAddress == address(0))
            revert InvalidAddress();
        
        // Assign interface dan address di constructor
        stablecoinContract = IERC20(_stablecoinAddress);
        FACTORY_ADDRESS = _factoryAddress;
    }

    // --- FUNGSI UTAMA: PEMBELIAN/CHECKOUT ---

    /**
     * @notice Fungsi utama pembelian lisensi dan pemicu minting CLT.
     * @dev Pembeli HARUS sudah melakukan approve Stablecoin ke kontrak Marketplace ini.
     * @param _vaultAddress Alamat ProjectVault kreator.
     * @param _workHash Hash karya (GOT) yang dibeli.
     * @param _termIndex Index (posisi) lisensi yang dipilih dalam array ListingTerms.
     * @param _cltURI Metadata URI CLT unik untuk pembelian ini.
     */
    function purchaseLicense(
        address _vaultAddress,
        bytes32 _workHash,
        uint256 _termIndex,
        string memory _cltURI
    ) external nonReentrant {
        // PERSIAPAN INTERFACE DAN DATA
        IProjectVault vault = IProjectVault(_vaultAddress);
        address buyer = msg.sender;
        
        // Memastikan Vault valid (opsional: cek terhadap Factory, tapi diabaikan untuk kesederhanaan)

        // MENGAMBIL DATA LISENSI
        // Gunakan struct LicenseTerm yang didefinisikan secara lokal untuk menerima array
        LicenseTerm[] memory terms = vault.listingTerms(_workHash);
        
        // VERIFIKASI INDEX DAN LISENSI
        if (_termIndex >= terms.length) revert InvalidTermIndex();
        
        LicenseTerm memory selectedTerm = terms[_termIndex];
        
        // Verifikasi Status Karya (Status MINTED = 2 di ProjectVault.StampStatus)
        (, uint256 status, ) = vault.getWorkStatus(_workHash);
        require(status == 2, "MP: Work not finalized"); 

        // PERHITUNGAN DANA
        uint256 price = selectedTerm.price;
        uint256 fee = price * MARKETPLACE_FEE_PERCENT / 10000;
        uint256 creatorPayment = price - fee;
        address creator = vault.CREATOR();
        
        // 1. TRANSFER DANA DARI PEMBELI KE MARKETPLACE
        stablecoinContract.safeTransferFrom(buyer, address(this), price);

        // 2. TRANSFER BAGIAN KREATOR (ROYALTI)
        stablecoinContract.safeTransfer(creator, creatorPayment);
        
        // 3. MINT CLT UNTUK PEMBELI (Delegasi ke ProjectVault)
        // ProjectVault yang memanggil ProjectAssets
        vault.mintCLTByMarketplace(
            buyer,
            _workHash,
            selectedTerm.cltId,      // ID Lisensi (1-6)
            1,                       // Amount (selalu 1 per lisensi)
            _cltURI
        );

        emit LicensePurchased(_workHash, buyer, selectedTerm.cltId, price);
    }

    // --- FUNGSI ADMIN ---
    
    /**
     * @notice Owner dapat menarik fee operasional Marketplace (profit).
     */
    function withdrawFees(uint256 amount) external onlyOwner nonReentrant {
        stablecoinContract.safeTransfer(msg.sender, amount);
    }
}