//
//  CheckoutAppearance.swift
//  Crossmint SDK
//
//  Appearance configuration for embedded checkout UI customization
//

import Foundation

// MARK: - Base Styles

public struct CheckoutFontStyle {
    public let family: String?
    public let size: String?
    public let weight: String?
    
    public init(
        family: String? = nil,
        size: String? = nil,
        weight: String? = nil
    ) {
        self.family = family
        self.size = size
        self.weight = weight
    }
    
    func toDictionary() -> [String: String] {
        var dict: [String: String] = [:]
        if let family = family { dict["family"] = family }
        if let size = size { dict["size"] = size }
        if let weight = weight { dict["weight"] = weight }
        return dict
    }
}

public struct CheckoutColorStyle {
    public let text: String?
    public let background: String?
    public let border: String?
    public let boxShadow: String?
    public let placeholder: String?
    
    public init(
        text: String? = nil,
        background: String? = nil,
        border: String? = nil,
        boxShadow: String? = nil,
        placeholder: String? = nil
    ) {
        self.text = text
        self.background = background
        self.border = border
        self.boxShadow = boxShadow
        self.placeholder = placeholder
    }
    
    func toDictionary() -> [String: String] {
        var dict: [String: String] = [:]
        if let text = text { dict["text"] = text }
        if let background = background { dict["background"] = background }
        if let border = border { dict["border"] = border }
        if let boxShadow = boxShadow { dict["boxShadow"] = boxShadow }
        if let placeholder = placeholder { dict["placeholder"] = placeholder }
        return dict
    }
}

public struct CheckoutStateStyle {
    public let colors: CheckoutColorStyle?
    
    public init(colors: CheckoutColorStyle? = nil) {
        self.colors = colors
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let colors = colors, !colors.toDictionary().isEmpty {
            dict["colors"] = colors.toDictionary()
        }
        return dict
    }
}

// MARK: - UI Element Rules

public struct CheckoutDestinationInputRule {
    public let display: String?
    
    public init(display: String? = nil) {
        self.display = display
    }
    
    func toDictionary() -> [String: String] {
        var dict: [String: String] = [:]
        if let display = display { dict["display"] = display }
        return dict
    }
}

public struct CheckoutReceiptEmailInputRule {
    public let display: String?
    
    public init(display: String? = nil) {
        self.display = display
    }
    
    func toDictionary() -> [String: String] {
        var dict: [String: String] = [:]
        if let display = display { dict["display"] = display }
        return dict
    }
}

public struct CheckoutLabelRule {
    public let font: CheckoutFontStyle?
    public let colors: CheckoutColorStyle?
    
    public init(
        font: CheckoutFontStyle? = nil,
        colors: CheckoutColorStyle? = nil
    ) {
        self.font = font
        self.colors = colors
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let font = font, !font.toDictionary().isEmpty {
            dict["font"] = font.toDictionary()
        }
        if let colors = colors, !colors.toDictionary().isEmpty {
            dict["colors"] = colors.toDictionary()
        }
        return dict
    }
}

public struct CheckoutInputRule {
    public let borderRadius: String?
    public let font: CheckoutFontStyle?
    public let colors: CheckoutColorStyle?
    public let hover: CheckoutStateStyle?
    public let focus: CheckoutStateStyle?
    
    public init(
        borderRadius: String? = nil,
        font: CheckoutFontStyle? = nil,
        colors: CheckoutColorStyle? = nil,
        hover: CheckoutStateStyle? = nil,
        focus: CheckoutStateStyle? = nil
    ) {
        self.borderRadius = borderRadius
        self.font = font
        self.colors = colors
        self.hover = hover
        self.focus = focus
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let borderRadius = borderRadius { dict["borderRadius"] = borderRadius }
        if let font = font, !font.toDictionary().isEmpty {
            dict["font"] = font.toDictionary()
        }
        if let colors = colors, !colors.toDictionary().isEmpty {
            dict["colors"] = colors.toDictionary()
        }
        if let hover = hover, !hover.toDictionary().isEmpty {
            dict["hover"] = hover.toDictionary()
        }
        if let focus = focus, !focus.toDictionary().isEmpty {
            dict["focus"] = focus.toDictionary()
        }
        return dict
    }
}

public struct CheckoutTabRule {
    public let borderRadius: String?
    public let font: CheckoutFontStyle?
    public let colors: CheckoutColorStyle?
    public let hover: CheckoutStateStyle?
    public let selected: CheckoutStateStyle?
    
    public init(
        borderRadius: String? = nil,
        font: CheckoutFontStyle? = nil,
        colors: CheckoutColorStyle? = nil,
        hover: CheckoutStateStyle? = nil,
        selected: CheckoutStateStyle? = nil
    ) {
        self.borderRadius = borderRadius
        self.font = font
        self.colors = colors
        self.hover = hover
        self.selected = selected
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let borderRadius = borderRadius { dict["borderRadius"] = borderRadius }
        if let font = font, !font.toDictionary().isEmpty {
            dict["font"] = font.toDictionary()
        }
        if let colors = colors, !colors.toDictionary().isEmpty {
            dict["colors"] = colors.toDictionary()
        }
        if let hover = hover, !hover.toDictionary().isEmpty {
            dict["hover"] = hover.toDictionary()
        }
        if let selected = selected, !selected.toDictionary().isEmpty {
            dict["selected"] = selected.toDictionary()
        }
        return dict
    }
}

public struct CheckoutPrimaryButtonRule {
    public let borderRadius: String?
    public let font: CheckoutFontStyle?
    public let colors: CheckoutColorStyle?
    public let hover: CheckoutStateStyle?
    public let disabled: CheckoutStateStyle?
    
    public init(
        borderRadius: String? = nil,
        font: CheckoutFontStyle? = nil,
        colors: CheckoutColorStyle? = nil,
        hover: CheckoutStateStyle? = nil,
        disabled: CheckoutStateStyle? = nil
    ) {
        self.borderRadius = borderRadius
        self.font = font
        self.colors = colors
        self.hover = hover
        self.disabled = disabled
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let borderRadius = borderRadius { dict["borderRadius"] = borderRadius }
        if let font = font, !font.toDictionary().isEmpty {
            dict["font"] = font.toDictionary()
        }
        if let colors = colors, !colors.toDictionary().isEmpty {
            dict["colors"] = colors.toDictionary()
        }
        if let hover = hover, !hover.toDictionary().isEmpty {
            dict["hover"] = hover.toDictionary()
        }
        if let disabled = disabled, !disabled.toDictionary().isEmpty {
            dict["disabled"] = disabled.toDictionary()
        }
        return dict
    }
}

// MARK: - Appearance Rules

public struct CheckoutAppearanceRules {
    public let destinationInput: CheckoutDestinationInputRule?
    public let receiptEmailInput: CheckoutReceiptEmailInputRule?
    public let label: CheckoutLabelRule?
    public let input: CheckoutInputRule?
    public let tab: CheckoutTabRule?
    public let primaryButton: CheckoutPrimaryButtonRule?
    
    public init(
        destinationInput: CheckoutDestinationInputRule? = nil,
        receiptEmailInput: CheckoutReceiptEmailInputRule? = nil,
        label: CheckoutLabelRule? = nil,
        input: CheckoutInputRule? = nil,
        tab: CheckoutTabRule? = nil,
        primaryButton: CheckoutPrimaryButtonRule? = nil
    ) {
        self.destinationInput = destinationInput
        self.receiptEmailInput = receiptEmailInput
        self.label = label
        self.input = input
        self.tab = tab
        self.primaryButton = primaryButton
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let destinationInput = destinationInput, !destinationInput.toDictionary().isEmpty {
            dict["DestinationInput"] = destinationInput.toDictionary()
        }
        if let receiptEmailInput = receiptEmailInput, !receiptEmailInput.toDictionary().isEmpty {
            dict["ReceiptEmailInput"] = receiptEmailInput.toDictionary()
        }
        if let label = label, !label.toDictionary().isEmpty {
            dict["Label"] = label.toDictionary()
        }
        if let input = input, !input.toDictionary().isEmpty {
            dict["Input"] = input.toDictionary()
        }
        if let tab = tab, !tab.toDictionary().isEmpty {
            dict["Tab"] = tab.toDictionary()
        }
        if let primaryButton = primaryButton, !primaryButton.toDictionary().isEmpty {
            dict["PrimaryButton"] = primaryButton.toDictionary()
        }
        return dict
    }
}

// MARK: - Appearance

public struct CheckoutAppearance {
    public let rules: CheckoutAppearanceRules?
    
    public init(rules: CheckoutAppearanceRules? = nil) {
        self.rules = rules
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let rules = rules, !rules.toDictionary().isEmpty {
            dict["rules"] = rules.toDictionary()
        }
        return dict
    }
}

