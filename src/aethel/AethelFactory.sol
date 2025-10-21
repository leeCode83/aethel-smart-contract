// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ProjectVault} from "./ProjectVault.sol";

// --- Custom Errors ---
error InvalidAddress();
error CreationFailed();

contract AethelFactory is Ownable {
    // --- KONFIGURASI ERC20 ---
    using SafeERC20 for IERC20;
    // --- KONFIGURASI IMMUTABLE ---
    address public immutable STABLECOIN_ADDRESS;
    address public immutable DAO_ADDRESS; // Disertakan untuk kompatibilitas DAO di masa depan

    // --- REGISTRY ---
    address[] public deployedProjectVaults;
    mapping(address => address[]) public creatorToVaults;

    event ProjectVaultCreated(
        address indexed creator,
        address indexed projectVaultAddress
    );

    /**
     * @notice Konstruktor: Menerima alamat Stablecoin dan DAO saat deployment Factory.
     */
    constructor(
        address _stablecoinAddress,
        address _daoAddress
    ) Ownable(msg.sender) {
        if (_stablecoinAddress == address(0) || _daoAddress == address(0)) {
            revert InvalidAddress();
        }
        STABLECOIN_ADDRESS = _stablecoinAddress;
        DAO_ADDRESS = _daoAddress;
        // Catatan: Alamat DAO tidak disuntikkan ke Vault karena DAO saat ini dinonaktifkan.
    }

    /**
     * @notice Membuat ProjectVault baru untuk kreator dan memicu deployment asetnya sendiri.
     * @param _assetsContractURI URI metadata dasar untuk kontrak aset yang akan di-deploy Vault.
     */
    function createProjectVault(
        string memory _assetsContractURI
    ) external returns (address newVaultAddress) {
        address creator = msg.sender;

        // --- 1. DEPLOYMENT KONTRAK ProjectVault ---

        ProjectVault newVault = new ProjectVault(
            creator,
            address(this), // Factory Address (disuntikkan ke Vault)
            STABLECOIN_ADDRESS
        );
        newVaultAddress = address(newVault);

        // 2. INISIALISASI ASET (Memicu Vault untuk mendeploy ProjectAssets)
        // ProjectVault yang baru dibuat mendeploy ProjectAssets-nya sendiri.
        newVault.initializeAssets(_assetsContractURI);

        // --- PENCATATAN ---
        deployedProjectVaults.push(newVaultAddress);
        creatorToVaults[creator].push(newVaultAddress);

        emit ProjectVaultCreated(creator, newVaultAddress);
    }

    /**
     * @notice Mengembalikan daftar ProjectVault yang dimiliki oleh kreator.
     */
    function getCreatorVaults(
        address _creator
    ) external view returns (address[] memory) {
        return creatorToVaults[_creator];
    }
}
