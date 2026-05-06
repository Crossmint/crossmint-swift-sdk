public protocol SmartWalletService:
    WalletCoreService,
    TransactionService,
    TransferService,
    BalanceService,
    NFTService,
    SignatureService {}
