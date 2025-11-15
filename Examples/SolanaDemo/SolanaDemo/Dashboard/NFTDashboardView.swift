import CrossmintClient
import SwiftUI
import CrossmintCommonTypes

struct NFTDashboardView: View {
    let wallet: Wallet

    @State private var nfts: [NFT] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentPage = 1
    @State private var hasMoreItems = true
    @State private var isFetchingMore = false

    private let chain: Chain = .solana
    private let nftsPerPage = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NFTs")
                .font(.headline)
                .padding(.bottom, 8)

            if isLoading && nfts.isEmpty {
                loadingView
            } else if let errorMessage = errorMessage, nfts.isEmpty {
                errorView(message: errorMessage)
            } else if nfts.isEmpty {
                emptyStateView
            } else {
                nftsGridView
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            fetchNFTs()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .frame(maxWidth: .infinity)
            Text("Loading NFTs...")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .padding(.bottom, 8)

            Text("Error loading NFTs")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button("Retry") {
                fetchNFTs()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.top, 8)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundColor(.gray)
                .padding(.bottom, 16)

            Text("No NFTs Found")
                .font(.headline)

            Text("Your wallet doesn't have any NFTs in it yet.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    private var nftsGridView: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(nfts) { nft in
                    NFTGridItemView(nft: nft)
                        .onAppear {
                            if nft.id == nfts.last?.id && hasMoreItems && !isFetchingMore {
                                loadMoreNFTs()
                            }
                        }
                }
            }
            .padding(.top, 8)

            if isFetchingMore {
                ProgressView()
                    .padding()
            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await refreshNFTs()
        }
    }

    private func fetchNFTs() {
        isLoading = true
        errorMessage = nil
        currentPage = 1

        Task {
            do {
                let fetchedNFTs = try await wallet.nfts(
                    page: currentPage,
                    nftsPerPage: nftsPerPage
                )

                await MainActor.run {
                    self.nfts = fetchedNFTs
                    self.isLoading = false
                    self.hasMoreItems = fetchedNFTs.count == nftsPerPage
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func loadMoreNFTs() {
        guard hasMoreItems && !isFetchingMore else { return }

        isFetchingMore = true
        let nextPage = currentPage + 1

        Task {
            do {
                let moreNFTs = try await wallet.nfts(
                    page: nextPage,
                    nftsPerPage: nftsPerPage
                )

                await MainActor.run {
                    if !moreNFTs.isEmpty {
                        self.nfts.append(contentsOf: moreNFTs)
                        self.currentPage = nextPage
                    }
                    self.hasMoreItems = moreNFTs.count == nftsPerPage
                    self.isFetchingMore = false
                }
            } catch {
                await MainActor.run {
                    self.isFetchingMore = false
                }
            }
        }
    }

    private func refreshNFTs() async {
        do {
            let fetchedNFTs = try await wallet.nfts(
                page: 1,
                nftsPerPage: nftsPerPage
            )

            await MainActor.run {
                self.nfts = fetchedNFTs
                self.currentPage = 1
                self.hasMoreItems = fetchedNFTs.count == nftsPerPage
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

struct NFTGridItemView: View {
    let nft: NFT
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading) {
            NFTImageView(imageUrl: nft.metadata.image)
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 2, y: 4)

            Text(nft.metadata.name)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .padding(.top, 4)

            if let collection = nft.metadata.collection["name"] {
                Text(collection)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .cornerRadius(12)
    }
}

struct NFTImageView: View {
    let imageUrl: URL

    var body: some View {
        AsyncImage(url: imageUrl) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(Color.gray.opacity(0.1))
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            case .failure:
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.gray)
            @unknown default:
                EmptyView()
            }
        }
    }
}
