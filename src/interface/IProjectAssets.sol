// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IProjectAssets {
    // Konstanta: Digunakan oleh ProjectVault untuk verifikasi dan pembacaan
    function GOT_ID() external view returns (uint256);
    function MAX_CLT_ID() external view returns (uint256);

    // --- FUNGSI MINTING ---

    /**
     * @notice Mencetak Genesis Ownership Token (GOT - ID 0).
     * Dipanggil oleh ProjectVault setelah verifikasi DAO sukses.
     */
    function mintGOT(address to, string calldata gotURI) external;

    /**
     * @notice Mencetak Consumption License Token (CLT - ID >= 1).
     * Dipanggil oleh ProjectVault setelah pembelian Marketplace.
     * @param to Alamat pembeli (penerima lisensi).
     * @param cltId ID Lisensi yang valid (1-6).
     * @param amount Jumlah CLT yang dicetak (biasanya 1).
     * @param cltURI Metadata URI spesifik untuk CLT ini.
     */
    function mintCLT(
        address to,
        uint256 cltId,
        uint256 amount,
        string calldata cltURI
    ) external;

    // --- FUNGSI KEAMANAN/READ ---

    /**
     * @notice Memeriksa saldo token ID tertentu.
     */
    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256);

    /**
     * @notice Mengambil alamat ProjectVault yang menjadi owner kontrak ini.
     */
    function owner() external view returns (address);
}
