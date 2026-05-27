public protocol SmartWalletService:
    WalletService,
    TransactionService,
    TransferService,
    BalanceService,
    NFTService,
    SignatureService {}
