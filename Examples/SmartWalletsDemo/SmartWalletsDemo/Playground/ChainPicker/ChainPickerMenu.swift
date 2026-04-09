//
//  ChainPickerMenu.swift
//  SmartWalletsDemo
//

import SwiftUI

struct ChainPickerMenu: View {
    let selectedChain: SupportedChain
    let onSelect: (SupportedChain) -> Void

    var body: some View {
        Menu {
            ForEach([SupportedChain.evm, .solana, .stellar]) { chain in
                Button {
                    onSelect(chain)
                } label: {
                    Label {
                        Text(chain.name)
                    } icon: {
                        chain.icon
                    }
                }
            }
        } label: {
            selectedChain.icon
        }
    }
}
