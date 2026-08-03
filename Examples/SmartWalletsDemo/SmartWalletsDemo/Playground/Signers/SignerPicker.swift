//
//  SignerPicker.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct SignerPicker: View {
    @Environment(AppState.self) private var appState

    private struct Option: Identifiable {
        var id: String { locator }

        let locator: String
        let typeLabel: String
        let isRecovery: Bool
    }

    private var options: [Option] {
        var result: [Option] = []
        if let recovery = appState.recoveryLocator, isSelectable(recovery) {
            result.append(Option(locator: recovery, typeLabel: SignerRow.typeLabel(for: recovery), isRecovery: true))
        }
        for signer in appState.signers {
            let locator = signer.locator
            guard isSelectable(locator) else { continue }
            if locator.hasPrefix("device:"), locator != appState.localDeviceLocator { continue }
            result.append(Option(locator: locator, typeLabel: SignerRow.typeLabel(for: locator), isRecovery: false))
        }
        return result
    }

    var body: some View {
        let opts = options
        if !opts.isEmpty {
            Picker("Sign with", selection: Binding(
                get: { appState.selectedSignerLocator ?? opts.first?.id ?? "" },
                set: { new in Task { await appState.selectSigner(locator: new) } }
            )) {
                ForEach(opts) { opt in
                    Button { } label: {
                        Text(opt.typeLabel + (opt.isRecovery ? " (Recovery)" : ""))
                        Text(opt.id)
                    }
                    .tag(opt.id)
                }
            }
        }
    }

    private func isSelectable(_ locator: String) -> Bool {
        locator.hasPrefix("email:") || locator.hasPrefix("api-key:") || locator.hasPrefix("device:")
    }
}

#Preview {
    struct GenderPickerPreview: View {
        let options = [
            (id: "male", label: "Male", sublabel: "gender:male"),
            (id: "female", label: "Female", sublabel: "gender:female"),
            (id: "non-binary", label: "Non-binary", sublabel: "gender:non-binary")
        ]
        @State private var selection = "male"
        var body: some View {
            Form {
                Section {
                    Picker("Sign with", selection: $selection) {
                        ForEach(options, id: \.id) { opt in
                            Button { } label: {
                                Text(opt.label)
                                Text(opt.sublabel)
                            }
                            .tag(opt.id)
                        }
                    }
                }
            }
        }
    }
    return GenderPickerPreview()
}
