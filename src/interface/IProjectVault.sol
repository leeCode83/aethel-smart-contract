// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Interface untuk ProjectVault.LicenseTerm, diperlukan di luar kontrak ProjectVault.
struct LicenseTerm {
    uint256 price;             
    string licenseTypeURI;      
    uint256 cltId;             
}

interface IProjectVault {
    // --- FUNGSI READ (untuk menampilkan listing di Marketplace) ---

    /**
     * @notice Mengembalikan daftar semua ketentuan lisensi (harga/tipe) yang ditawarkan kreator untuk hash karya tertentu.
     * @param _workHash Hash karya (GOT).
     */
    function listingTerms(bytes32 _workHash) external view returns (LicenseTerm[] memory);

    /**
     * @notice Mengembalikan status verifikasi karya.
     */
    function getWorkStatus(
        bytes32 _workHash
    ) external view returns (address creator, uint256 status, address assetsAddress);

    // --- FUNGSI TULIS (untuk memicu minting CLT) ---

    /**
     * @notice Dipanggil oleh Marketplace setelah pembelian Stablecoin berhasil untuk mencetak CLT.
     * @dev Marketplace perlu memanggil ini setelah pembayaran Stablecoin dikunci.
     */
    function mintCLTByMarketplace(
        address _buyer,
        bytes32 _workHash,
        uint256 _cltId,
        uint256 _cltAmount,
        string calldata _cltURI
    ) external;

    /**
     * @notice Mengambil alamat kreator (Owner Vault).
     */
    function CREATOR() external view returns (address);
}