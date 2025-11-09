import Payments
import SwiftUI

struct EmbeddedCheckoutLineItemRowView: View {
    let lineItem: LineItem

    var failed: Bool {
        lineItem.delivery.failed != nil
    }

    var body: some View {
        HStack(spacing: 16) {
            EmbeddedCheckoutLineItemImage(link: lineItem.metadata.imageUrl, failed: failed)

            VStack(alignment: .leading, spacing: 4) {
                EmbeddedCheckoutLineItemName(name: lineItem.metadata.name)
                EmbeddedCheckoutLineItemCollectionName(name: lineItem.metadata.collection?.name)
            }
            .padding(.trailing, 8)

            Spacer()

            EmbeddedCheckoutLineItemPrice(lineItem: lineItem, failed: failed)
        }
        .padding(.vertical, 12)
    }
}

struct EmbeddedCheckoutLineItemImage: View {
    let link: URL?
    let failed: Bool

    private let imageSize: CGFloat = 48

    var body: some View {
        ZStack {
            // Display image or placeholder
            if let link = link {
                AsyncImage(url: link) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        // Placeholder while loading or if error
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(width: imageSize, height: imageSize)
            } else {
                // Placeholder for no image
                Color.gray.opacity(0.2)
                    .frame(width: imageSize, height: imageSize)
            }

            // Failed overlay
            if failed {
                ZStack {
                    Color.black.opacity(0.4)

                    Image("unavailableIcon", bundle: .module)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: imageSize, height: imageSize)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EmbeddedCheckoutLineItemName: View {
    let name: String?

    var displayName: String {
        name ?? "Unknown"
    }

    var body: some View {
        Text(displayName)
            .font(.system(size: 16))
            .fontWeight(.medium)
            .foregroundColor(.primary)
            .lineLimit(1)
    }
}

struct EmbeddedCheckoutLineItemCollectionName: View {
    let name: String?

    var body: some View {
        if let name = name {
            Text(name)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(1)
        } else {
            EmptyView()
        }
    }
}

struct EmbeddedCheckoutLineItemPrice: View {
    let lineItem: LineItem
    let failed: Bool

    var displayablePrice: String {
        if let priceAmount = lineItem.quote.totalPrice?.amount,
            let priceCurrency = lineItem.quote.totalPrice?.currency {
            let price = Price(amount: priceAmount, currency: priceCurrency)
            return price.displayableNumericPrice()
        }
        return ""
    }

    var body: some View {
        if !displayablePrice.isEmpty {
            Text(displayablePrice)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .strikethrough(failed)
        } else {
            EmptyView()
        }
    }
}
