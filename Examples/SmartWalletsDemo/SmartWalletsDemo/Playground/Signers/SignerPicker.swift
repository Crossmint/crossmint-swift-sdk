//
//  SignerPicker.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct SignerPicker: View {
    @Environment(AppState.self) private var appState

    private struct Option: Identifiable {
        var id: String { choice.id }
        var locator: String { choice.locator }

        let choice: SignerChoice
        let name: String?
        let isRecovery: Bool
    }

    private var options: [Option] {
        var result: [Option] = []
        for recovery in appState.selectableRecoveryMethods where isSelectable(recovery.locator) {
            let name = appState.recoveryName(for: recovery.locator)
            result.append(Option(choice: recovery, name: name, isRecovery: true))
        }
        for signer in appState.signers {
            let locator = signer.locator
            guard isSelectable(locator) else { continue }
            if locator.isDevice, locator.value != appState.localDeviceLocator { continue }
            let choice = SignerChoice(locator: locator.value, quorum: nil)
            result.append(Option(choice: choice, name: signer.name, isRecovery: false))
        }
        return result
    }

    var body: some View {
        let opts = options
        if !opts.isEmpty {
            Picker("Sign with", selection: Binding(
                get: { appState.selectedSignerID ?? opts.first?.id ?? "" },
                set: { id in
                    guard let option = opts.first(where: { $0.id == id }) else { return }
                    Task { await appState.selectSigner(option.choice) }
                }
            )) {
                ForEach(opts) { opt in
                    Button { } label: {
                        Text(title(for: opt))
                        Text(subtitle(for: opt))
                    }
                    .tag(opt.id)
                }
            }
        }
    }

    private func title(for option: Option) -> String {
        guard option.isRecovery, option.name == nil else {
            return SignerRow.title(for: option.locator, name: option.name)
        }
        return SignerRow.shortValue(for: option.locator)
    }

    private func subtitle(for option: Option) -> String {
        guard option.isRecovery else { return SignerRow.subtitle(for: option.locator, name: option.name) }
        guard option.name == nil else {
            return "\(SignerRow.subtitle(for: option.locator, name: option.name)) (Recovery)"
        }
        return "\(SignerRow.typeLabel(for: option.locator)) (Recovery)"
    }

    private func isSelectable(_ locator: String) -> Bool {
        guard let parsed = try? SignerLocator(from: locator) else { return false }
        return isSelectable(parsed)
    }

    private func isSelectable(_ locator: SignerLocator) -> Bool {
        switch locator {
        case .email, .phone, .apiKey, .device, .passkey: true
        default: false
        }
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
