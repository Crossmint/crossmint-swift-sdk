import Foundation

/// Centralized log event names for structured logging
/// All event names follow the pattern: {component}.{operation}.{status}
public enum LogEvents {

    // MARK: - Handshake Events

    /// Handshake operation started
    public static let handshakeStart = "signer.handshake.start"

    /// Handshake completed successfully
    public static let handshakeSuccess = "signer.handshake.success"

    /// Handshake failed
    public static let handshakeError = "signer.handshake.error"

    /// Retrying handshake after failure
    public static let handshakeRetry = "signer.handshake.retry"

    // MARK: - GetStatus Events

    /// Requesting signer status
    public static let getStatusStart = "signer.getStatus.start"

    /// Status retrieved successfully
    public static let getStatusSuccess = "signer.getStatus.success"

    /// Failed to get status
    public static let getStatusError = "signer.getStatus.error"

    /// Retrying status request
    public static let getStatusRetry = "signer.getStatus.retry"

    // MARK: - Onboarding Events

    /// Starting onboarding flow
    public static let onboardingStart = "signer.onboarding.start"

    /// Onboarding started successfully
    public static let onboardingSuccess = "signer.onboarding.success"

    /// Failed to start onboarding
    public static let onboardingError = "signer.onboarding.error"

    /// Starting OTP validation
    public static let onboardingCompleteStart = "signer.onboarding.complete.start"

    /// OTP validated successfully
    public static let onboardingCompleteSuccess = "signer.onboarding.complete.success"

    /// OTP validation failed
    public static let onboardingCompleteError = "signer.onboarding.complete.error"

    /// A fresh OTP was issued after onboarding could not be completed (e.g. the signer frame was reloaded mid-onboarding)
    public static let onboardingReissued = "tee.signer.onboarding.reissued"

    // MARK: - Sign Events

    /// Starting signature request
    public static let signStart = "signer.sign.start"

    /// Signature completed successfully
    public static let signSuccess = "signer.sign.success"

    /// Signature failed
    public static let signError = "signer.sign.error"

    // MARK: - Queue Events

    /// Request added to queue
    public static let queueEnqueue = "signer.queue.enqueue"

    /// Request cancelled
    public static let queueCancelled = "signer.queue.cancelled"

    /// Queue error
    public static let queueError = "signer.queue.error"

    /// Processing queued request
    public static let queueProcess = "signer.queue.process"

    /// Request processed successfully
    public static let queueProcessSuccess = "signer.queue.process.success"

    /// Processing failed
    public static let queueProcessError = "signer.queue.process.error"

    /// Failing all queued requests
    public static let queueFailAll = "signer.queue.failAll"

    /// Failed to resume request
    public static let queueResumeError = "signer.queue.resume.error"

    // MARK: - OTP Events

    /// Waiting for user OTP input
    public static let otpWait = "signer.otp.wait"

    /// OTP received from user
    public static let otpReceived = "signer.otp.received"

    /// User provided OTP
    public static let otpProvided = "signer.otp.provided"

    /// User cancelled OTP input
    public static let otpUserCancelled = "signer.otp.userCancelled"

    /// OTP wait cancelled
    public static let otpCancelled = "signer.otp.cancelled"

    /// Newer signature requested
    public static let otpSuperseded = "signer.otp.superseded"

    /// OTP error
    public static let otpError = "signer.otp.error"

    // MARK: - State Management Events

    /// Resetting TEE state
    public static let resetStateStart = "signer.resetState.start"

    /// State reset complete
    public static let resetStateSuccess = "signer.resetState.success"

    /// Error loading TEE
    public static let loadError = "signer.load.error"

    /// Missing email for authId
    public static let getAuthIdError = "signer.getAuthId.error"

    // MARK: - Web Content Process Events

    /// The web view's content process was terminated by the system
    public static let webProcessTerminated = "signer.webProcess.terminated"

    /// Starting recovery after a content process termination
    public static let webProcessRecoveryStart = "signer.webProcess.recovery.start"

    /// Recovery after a content process termination succeeded
    public static let webProcessRecoverySuccess = "signer.webProcess.recovery.success"

    /// Recovery after a content process termination failed
    public static let webProcessRecoveryError = "signer.webProcess.recovery.error"

    /// Gave up recovering after repeated content process terminations
    public static let webProcessRecoveryGivenUp = "signer.webProcess.recovery.givenUp"

    // MARK: - Wallet Factory Events

    /// Getting wallet
    public static let walletGetStart = "wallet.get.start"

    /// Wallet not found
    public static let walletGetNotFound = "wallet.get.notFound"

    /// Wallet retrieved successfully
    public static let walletGetSuccess = "wallet.get.success"

    /// Creating wallet
    public static let walletCreateStart = "wallet.create.start"

    /// Wallet creation failed
    public static let walletCreateError = "wallet.create.error"

    /// Wallet created successfully
    public static let walletCreateSuccess = "wallet.create.success"

    // MARK: - Wallet Operation Events

    /// Starting send transaction
    public static let walletSendStart = "wallet.send.start"

    /// Transaction prepared
    public static let walletSendPrepared = "wallet.send.prepared"

    /// Send completed successfully
    public static let walletSendSuccess = "wallet.send.success"

    /// Send failed
    public static let walletSendError = "wallet.send.error"

    /// Getting wallet balances
    public static let walletBalancesStart = "wallet.balances.start"

    /// Balances retrieved successfully
    public static let walletBalancesSuccess = "wallet.balances.success"

    /// Failed to get balances
    public static let walletBalancesError = "wallet.balances.error"

    /// Getting a transaction by ID
    public static let walletGetTransactionStart = "wallet.getTransaction.start"

    /// Transaction retrieved successfully
    public static let walletGetTransactionSuccess = "wallet.getTransaction.success"

    /// Failed to get transaction
    public static let walletGetTransactionError = "wallet.getTransaction.error"

    /// Starting staging fund
    public static let walletStagingFundStart = "wallet.stagingFund.start"

    /// Staging fund completed
    public static let walletStagingFundSuccess = "wallet.stagingFund.success"

    /// Staging fund failed
    public static let walletStagingFundError = "wallet.stagingFund.error"

    // MARK: - API Level Events

    /// API: Creating wallet
    public static let apiCreateWalletStart = "wallets.api.createWallet"

    /// API: Wallet creation failed
    public static let apiCreateWalletError = "wallets.api.createWallet.error"

    /// API: Wallet created successfully
    public static let apiCreateWalletSuccess = "wallets.api.createWallet.success"

    /// API: Getting wallet
    public static let apiGetWalletStart = "wallets.api.getWallet"

    /// API: Get wallet failed
    public static let apiGetWalletError = "wallets.api.getWallet.error"

    /// API: Wallet retrieved successfully
    public static let apiGetWalletSuccess = "wallets.api.getWallet.success"

    /// API: Getting signer
    public static let apiGetSignerStart = "wallets.api.getSigner"

    /// API: Signer retrieved successfully
    public static let apiGetSignerSuccess = "wallets.api.getSigner.success"

    /// API: Sending transaction
    public static let apiSendStart = "wallets.api.send"

    /// API: Send failed
    public static let apiSendError = "wallets.api.send.error"

    /// API: Send successful
    public static let apiSendSuccess = "wallets.api.send.success"

    /// API: Listing transfers
    public static let apiListTransfersStart = "wallets.api.listTransfers"

    /// API: List transfers failed
    public static let apiListTransfersError = "wallets.api.listTransfers.error"

    /// API: List transfers successful
    public static let apiListTransfersSuccess = "wallets.api.listTransfers.success"

    // MARK: - SDK Initialization

    /// SDK initialized
    public static let sdkInitialized = "wallets.sdk.initialized"

    // MARK: - EVM Wallet Events

    /// EVM: Starting send transaction
    public static let evmSendTransactionStart = "evmWallet.sendTransaction.start"

    /// EVM: Transaction prepared
    public static let evmSendTransactionPrepared = "evmWallet.sendTransaction.prepared"

    /// EVM: Transaction sent successfully
    public static let evmSendTransactionSuccess = "evmWallet.sendTransaction.success"

    /// EVM: Starting sign message
    public static let evmSignMessageStart = "evmWallet.signMessage.start"

    /// EVM: Sign message failed
    public static let evmSignMessageError = "evmWallet.signMessage.error"

    /// EVM: Message signature prepared
    public static let evmSignMessagePrepared = "evmWallet.signMessage.prepared"

    /// EVM: Message signed successfully
    public static let evmSignMessageSuccess = "evmWallet.signMessage.success"

    /// EVM: Starting sign typed data
    public static let evmSignTypedDataStart = "evmWallet.signTypedData.start"

    /// EVM: Sign typed data failed (invalid data)
    public static let evmSignTypedDataErrorInvalidData = "evmWallet.signTypedData.error (invalid data)"

    /// EVM: Sign typed data failed (invalid domain)
    public static let evmSignTypedDataErrorInvalidDomain = "evmWallet.signTypedData.error (invalid domain)"

    /// EVM: Sign typed data failed
    public static let evmSignTypedDataError = "evmWallet.signTypedData.error"

    /// EVM: Typed data signature prepared
    public static let evmSignTypedDataPrepared = "evmWallet.signTypedData.prepared"

    /// EVM: Typed data signed successfully
    public static let evmSignTypedDataSuccess = "evmWallet.signTypedData.success"

    // MARK: - Solana Wallet Events

    /// Solana: Starting send transaction
    public static let solanaSendTransactionStart = "solanaWallet.sendTransaction.start"

    /// Solana: Transaction prepared
    public static let solanaSendTransactionPrepared = "solanaWallet.sendTransaction.prepared"

    /// Solana: Transaction sent successfully
    public static let solanaSendTransactionSuccess = "solanaWallet.sendTransaction.success"

    // MARK: - Stellar Wallet Events

    /// Stellar: Starting send transaction
    public static let stellarSendTransactionStart = "stellarWallet.sendTransaction.start"

    /// Stellar: Transaction prepared
    public static let stellarSendTransactionPrepared = "stellarWallet.sendTransaction.prepared"

    /// Stellar: Transaction sent successfully
    public static let stellarSendTransactionSuccess = "stellarWallet.sendTransaction.success"

    // MARK: - Wallet Approve Events

    /// Starting transaction/signature approval
    public static let walletApproveStart = "wallet.approve.start"

    /// Transaction approval successful
    public static let walletApproveSuccessTransaction = "wallet.approve.success (transaction)"

    /// Signature approval successful
    public static let walletApproveSuccessSignature = "wallet.approve.success (signature)"

    /// Approval failed
    public static let walletApproveError = "wallet.approve.error"

    // MARK: - Delegated Signer Events

    /// Starting add delegated signer
    public static let walletAddDelegatedSignerStart = "wallet.addDelegatedSigner.start"

    /// Add delegated signer failed
    public static let walletAddDelegatedSignerError = "wallet.addDelegatedSigner.error"

    /// Add delegated signer failed (no transaction)
    public static let walletAddDelegatedSignerErrorNoTransaction = "wallet.addDelegatedSigner.error (no transaction)"

    /// Delegated signer transaction prepared
    public static let walletAddDelegatedSignerPrepared = "wallet.addDelegatedSigner.prepared"

    /// Delegated signer added (transaction)
    public static let walletAddDelegatedSignerSuccessTransaction = "wallet.addDelegatedSigner.success (transaction)"

    /// Delegated signer signature failed
    public static let walletAddDelegatedSignerErrorSignature = "wallet.addDelegatedSigner.error (signature)"

    /// Delegated signer signature prepared
    public static let walletAddDelegatedSignerPreparedSignature = "wallet.addDelegatedSigner.prepared (signature)"

    /// Delegated signer signature pending
    public static let walletAddDelegatedSignerSuccessSignaturePending =
        "wallet.addDelegatedSigner.success (signature pending)"

    /// Delegated signer signature complete
    public static let walletAddDelegatedSignerSuccessSignatureComplete =
        "wallet.addDelegatedSigner.success (signature complete)"

    /// Delegated signer added successfully
    public static let walletAddDelegatedSignerSuccess = "wallet.addDelegatedSigner.success"

    /// Getting signers
    public static let walletSignersStart = "wallet.signers.start"

    /// Failed to get signers
    public static let walletSignersError = "wallet.signers.error"

    /// A signer state lookup failed and that signer was returned with unknown status
    public static let walletSignersStateLookupFailed = "wallet.signers.error (state lookup failed)"

    /// Signers retrieved
    public static let walletSignersSuccess = "wallet.signers.success"

    // MARK: - Remove Signer Events

    /// Starting remove signer
    public static let walletRemoveSignerStart = "wallet.removeSigner.start"

    /// Remove signer succeeded
    public static let walletRemoveSignerSuccess = "wallet.removeSigner.success"

    /// Remove signer failed
    public static let walletRemoveSignerError = "wallet.removeSigner.error"

    // MARK: - Device Signer Events

    /// Device signer key prepared for new wallet creation
    public static let walletCreateDeviceSignerPrepared = "wallet.create.deviceSigner.prepared"

    /// Device signer skipped (not configured)
    public static let walletCreateDeviceSignerSkipped = "wallet.create.deviceSigner.skipped"

    // MARK: - addSigner Events

    /// Starting addSigner
    public static let walletAddSignerStart = "wallet.addSigner.start"

    /// addSigner succeeded
    public static let walletAddSignerSuccess = "wallet.addSigner.success"

    /// Signer registration approval routed to the transaction, signature, or no-op flow
    public static let walletAddSignerApprovalRouted = "wallet.addSigner.approvalRouted"

    /// addSigner failed
    public static let walletAddSignerError = "wallet.addSigner.error"

    // MARK: - isSignerApproved Events

    /// Starting isSignerApproved
    public static let walletIsSignerApprovedStart = "wallet.isSignerApproved.start"

    /// isSignerApproved resolved
    public static let walletIsSignerApprovedSuccess = "wallet.isSignerApproved.success"

    /// isSignerApproved failed
    public static let walletIsSignerApprovedError = "wallet.isSignerApproved.error"

    // MARK: - recover Events

    /// Starting recover
    public static let walletRecoverStart = "wallet.recover.start"

    /// Recover skipped — device signer already approved on this device
    public static let walletRecoverSkipped = "wallet.recover.skipped"

    /// Recover succeeded
    public static let walletRecoverSuccess = "wallet.recover.success"

    /// Recover failed
    public static let walletRecoverError = "wallet.recover.error"

    /// Recover fell back to the recovery signer — the wallet's provider does not support device signers
    public static let walletRecoverDeviceSignerUnsupported = "wallet.recover.deviceSignerUnsupported"

    // MARK: - registerDeviceSigner Events

    /// Starting device signer registration
    public static let walletRegisterDeviceSignerStart = "wallet.registerDeviceSigner.start"

    /// Device key generated
    public static let walletRegisterDeviceSignerKeyGenerated = "wallet.registerDeviceSigner.keyGenerated"

    /// Registration awaiting approval
    public static let walletRegisterDeviceSignerAwaitingApproval = "wallet.registerDeviceSigner.awaitingApproval"

    /// Registration approved
    public static let walletRegisterDeviceSignerApproved = "wallet.registerDeviceSigner.approved"

    /// Device signer registered and persisted successfully
    public static let walletRegisterDeviceSignerSuccess = "wallet.registerDeviceSigner.success"

    /// Device signer registration failed
    public static let walletRegisterDeviceSignerError = "wallet.registerDeviceSigner.error"

    // MARK: - WalletFactory Error Events

    public static let walletFactoryInvalidChain = "walletFactory.invalidChain"
}
