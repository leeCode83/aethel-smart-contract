// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/IProjectAssets.sol"; // Interface Lapisan 4

// --- Custom Errors ---
error AccessDenied();
error InvalidStage();
error WorkAlreadyProcessed();
error InvalidStakeAmount();
error TransferFailed();
error InvalidAddress();
error InvalidIndex();
error InvalidLicenseID(); // Ditambahkan dari IProjectAssets

contract ProjectVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    // --- KONFIGURASI IMMUTABLE (Di-assign di Constructor) ---
    address public immutable CREATOR;
    address public immutable FACTORY_ADDRESS;

    // --- INTERFACE INSTANCES (Dibuat di Constructor) ---
    IProjectAssets public immutable assetsContract;
    IERC20 public immutable stablecoinContract;

    // --- PERAN KHUSUS ---
    address public curatorOracle;
    address public marketplaceAddress;

    // --- ENUM UNTUK VERIFIKASI SATU TAHAP ---
    enum StampStatus {
        NONE,
        CURATION_PENDING,
        MINTED,
        FAILED
    }

    // --- DATA KARYA DAN STAMP ---
    // workHash (bytes32) adalah HASH VALUE dari KARYA DIGITAL
    struct Work {
        StampStatus status;
        string gotURI;
        uint256 creatorStake;
    }
    mapping(bytes32 => Work) public workRegistry;

    // --- DATA LISENSI (Marketplace Listing) ---
    struct LicenseTerm {
        uint256 price;
        string licenseTypeURI;
        uint256 cltId;
    }
    mapping(bytes32 => LicenseTerm[]) public listingTerms;

    event StampStatusUpdated(bytes32 indexed workHash, StampStatus newStatus);
    event ListingUpdated(bytes32 indexed workHash);
    event CLTMinted(bytes32 indexed workHash, address indexed buyer);

    // Konstruktor: Menerima semua alamat yang diperlukan
    constructor(
        address _creator,
        address _factoryAddress,
        address _stablecoinAddress,
        address _assetsContractAddress
    ) Ownable(_creator) {
        // Assign Immutables
        CREATOR = _creator;
        FACTORY_ADDRESS = _factoryAddress;

        // Inisialisasi Interface
        if (
            _assetsContractAddress == address(0) ||
            _stablecoinAddress == address(0)
        ) revert InvalidAddress();
        assetsContract = IProjectAssets(_assetsContractAddress);
        // PERBAIKAN: Inisialisasi IERC20
        stablecoinContract = IERC20(_stablecoinAddress);
    }

    // --- FUNGSI PENGATURAN ---

    function setMarketplaceAddress(
        address _marketplaceAddress
    ) external onlyOwner {
        marketplaceAddress = _marketplaceAddress;
    }

    function setCuratorOracle(address _oracleAddress) external onlyOwner {
        curatorOracle = _oracleAddress;
    }

    // --- FUNGSI UTAMA 1: PROVENANCE (MINT GOT) ---

    function stampArtwork(
        bytes32 _workHash,
        string memory _gotURI,
        uint256 _stakeAmount
    ) external nonReentrant {
        if (workRegistry[_workHash].status != StampStatus.NONE)
            revert WorkAlreadyProcessed();

        // PERBAIKAN: Menggunakan stablecoinContract.transferFrom()
        if (
            !stablecoinContract.transferFrom(
                msg.sender,
                address(this),
                _stakeAmount
            )
        ) {
            revert TransferFailed();
        }

        workRegistry[_workHash] = Work({
            status: StampStatus.CURATION_PENDING,
            gotURI: _gotURI,
            creatorStake: _stakeAmount
        });

        emit StampStatusUpdated(_workHash, StampStatus.CURATION_PENDING);
    }

    // Dipanggil oleh Oracle Kurator
    function handleCuratorResult(
        bytes32 _workHash,
        bool _isApproved
    ) external nonReentrant {
        if (msg.sender != curatorOracle) revert AccessDenied();
        if (workRegistry[_workHash].status != StampStatus.CURATION_PENDING)
            revert InvalidStage();

        Work storage work = workRegistry[_workHash];

        if (_isApproved) {
            // LULUS KURASI: Langsung Mint GOT

            // MINT GOT ke kreator
            assetsContract.mintGOT(CREATOR, work.gotURI);

            // Kembalikan Stake Kreator (Prototipe Sederhana)
            uint256 stake = work.creatorStake;
            work.creatorStake = 0;
            // PERBAIKAN: Menggunakan stablecoinContract.transfer()
            if (!stablecoinContract.transfer(CREATOR, stake)) {
                // Biarkan dana di Vault untuk ditarik owner (kreator) jika transfer gagal
            }

            work.status = StampStatus.MINTED;
        } else {
            // GAGAL KURASI: Stake disita
            work.status = StampStatus.FAILED;
        }
        emit StampStatusUpdated(_workHash, work.status);
    }

    // --- FUNGSI UTAMA 2: MARKETPLACE LISENSI (MINT CLT) ---

    function setMarketplaceListing(
        bytes32 _workHash,
        LicenseTerm[] calldata _terms
    ) external onlyOwner {
        if (workRegistry[_workHash].status != StampStatus.MINTED)
            revert InvalidStage();

        uint256 len = _terms.length;

        // --- 1. Hapus listing lama (Penting sebelum mengganti) ---
        // Kosongkan array storage terlebih dahulu
        delete listingTerms[_workHash];

        // --- 2. Verifikasi & Salin Struktur Array Baru secara Manual ---
        for (uint i = 0; i < len; i++) {
            LicenseTerm calldata term = _terms[i]; // Ambil elemen dari calldata

            // Verifikasi ID Lisensi (1-6)
            if (
                term.cltId <= assetsContract.GOT_ID() ||
                term.cltId > assetsContract.MAX_CLT_ID()
            ) {
                revert InvalidLicenseID();
            }

            // SALIN MANUAL ke storage
            listingTerms[_workHash].push(
                LicenseTerm({
                    price: term.price,
                    licenseTypeURI: term.licenseTypeURI,
                    cltId: term.cltId
                })
            );
        }

        emit ListingUpdated(_workHash);
    }

    // Dipanggil oleh Marketplace setelah pembelian berhasil
    function mintCLTByMarketplace(
        address _buyer,
        bytes32 _workHash,
        uint256 _cltId,
        uint256 _cltAmount,
        string memory _cltURI
    ) external nonReentrant {
        if (msg.sender != marketplaceAddress) revert AccessDenied();
        if (workRegistry[_workHash].status != StampStatus.MINTED)
            revert InvalidStage();

        // MINT CLT (menggunakan ID Lisensi yang dipilih)
        assetsContract.mintCLT(_buyer, _cltId, _cltAmount, _cltURI);

        emit CLTMinted(_workHash, _buyer);
    }

    // --- FUNGSI READ (Untuk Marketplace/UI) ---

    function getWorkStatus(
        bytes32 _workHash
    )
        external
        view
        returns (address creator, StampStatus status, address assetsAddress)
    {
        return (
            CREATOR,
            workRegistry[_workHash].status,
            address(assetsContract)
        );
    }

    // Fungsi untuk Kreator menarik dana yang tersisa.
    function withdrawVaultFunds(
        uint256 amount
    ) external onlyOwner nonReentrant {
        // Menggunakan stablecoinContract.transfer()
        if (!stablecoinContract.transfer(msg.sender, amount)) {
            revert TransferFailed();
        }
    }
}
