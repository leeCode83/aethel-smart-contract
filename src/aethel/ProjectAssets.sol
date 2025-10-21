// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155URIStorage} from "lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

// --- Custom Errors ---
error AccessDenied();
error GOTAlreadyMinted();
error TransferNotAllowed();
error InvalidLicenseID();
error InvalidAddress();

contract ProjectAssets is ERC1155URIStorage, Ownable, ReentrancyGuard {
    // --- ID TOKEN STANDAR ---
    uint256 public constant GOT_ID = 0;
    uint256 public constant MAX_CLT_ID = 6; // Hanya mengizinkan ID 1 sampai 6 untuk CLT

    // Alamat ProjectVault yang berwenang.
    address private immutable _projectVault;

    // Konstruktor: Dipanggil saat ProjectVault dibuat.
    constructor(
        address projectVaultAddress,
        string memory contractURI
    ) ERC1155(contractURI) ERC1155URIStorage() Ownable(projectVaultAddress) {
        _projectVault = projectVaultAddress;
    }

    // Modifier: Hanya Kontrak ProjectVault yang berwenang.
    modifier onlyProjectVault() {
        if (msg.sender != _projectVault) revert AccessDenied();
        _;
    }

    // --- FUNGSI MINTING UNTUK PROJECTVAULT ---

    /**
     * @notice Mencetak Genesis Ownership Token (GOT - ID 0). Hanya dapat dilakukan satu kali.
     * @param to Alamat penerima GOT.
     * @param gotURI Metadata URI spesifik untuk GOT ini.
     */
    function mintGOT(
        address to,
        string memory gotURI
    ) external onlyProjectVault nonReentrant {
        if (balanceOf(to, GOT_ID) > 0) revert GOTAlreadyMinted();

        _mint(to, GOT_ID, 1, "");
        _setURI(GOT_ID, gotURI);
    }

    /**
     * @notice Mencetak Consumption License Token (CLT) dengan ID Lisensi yang Tetap (1-6).
     * @param to Alamat pembeli (penerima lisensi).
     * @param cltId ID Lisensi yang telah disetujui (1-6).
     * @param amount Jumlah CLT yang dicetak (biasanya 1 per pembelian lisensi).
     * @param cltURI Metadata URI spesifik untuk CLT ini.
     */
    function mintCLT(
        address to,
        uint256 cltId,
        uint256 amount,
        string memory cltURI
    ) external onlyProjectVault nonReentrant {
        // Keamanan: Memastikan ID yang dicetak adalah ID CLT yang valid (1-6).
        if (cltId <= GOT_ID || cltId > MAX_CLT_ID) revert InvalidLicenseID();

        // CLT ID yang sama (misalnya ID 1) dapat dicetak berulang kali ke pembeli yang berbeda.
        _mint(to, cltId, amount, "");
        _setURI(cltId, cltURI);
    }

    // --- KONTROL TRANSFER HAK CIPTA (CLT Non-Transferable) ---

    /**
     * @notice Hook internal yang dipanggil sebelum minting, transfer, atau burning.
     * Digunakan untuk memblokir transfer CLT (ID 1-6).
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        // Hanya memproses jika terjadi transfer antar alamat (bukan minting/burning)
        if (from == address(0) || to == address(0) || from == to)
            revert InvalidAddress();

        for (uint i = 0; i < ids.length; i++) {
            // Logika: Jika ID > GOT_ID (yaitu CLT, ID 1 hingga 6)
            if (ids[i] > GOT_ID) {
                // Kita blokir transfer CLT antar user.
                if (values[i] > 0) revert TransferNotAllowed();
            }
        }

        super._update(from, to, ids, values);
    }
}
