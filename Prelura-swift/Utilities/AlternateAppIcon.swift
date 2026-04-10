//
//  AlternateAppIcon.swift
//  Prelura-swift
//
//  Home Screen alternate icons (asset catalog names must match build setting
//  ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES).
//

import SwiftUI
import UIKit

/// UserDefaults key: raw value of `AlternateAppIconChoice`.
let kAlternateAppIcon = "alternate_app_icon"

enum AlternateAppIconChoice: String, CaseIterable, Identifiable, Equatable {
    case primary
    case gradient
    case gradient3D
    case black

    var id: String { rawValue }

    /// Name passed to `setAlternateIconName`; `nil` = primary `AppIcon`.
    var catalogName: String? {
        switch self {
        case .primary: nil
        case .gradient: "AppIconGradient"
        case .gradient3D: "AppIconGradient3D"
        case .black: "AppIconBlack"
        }
    }

    /// Asset name for list preview thumbnails (non–app-icon imagesets).
    var previewImageName: String {
        switch self {
        case .primary: "AlternateIconPreviewPrimary"
        case .gradient: "AlternateIconPreviewGradient"
        case .gradient3D: "AlternateIconPreviewGradient3D"
        case .black: "AlternateIconPreviewBlack"
        }
    }

    static func resolved(stored: String?) -> AlternateAppIconChoice {
        guard let stored, let choice = AlternateAppIconChoice(rawValue: stored) else { return .primary }
        return choice
    }

    /// Applies stored preference if it differs from the system’s current icon (e.g. after reinstall).
    @MainActor
    static func syncStoredPreferenceWithSystem() {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let stored = UserDefaults.standard.string(forKey: kAlternateAppIcon)
        let choice = resolved(stored: stored)
        let desired = choice.catalogName
        let current = UIApplication.shared.alternateIconName
        guard current != desired else { return }
        UIApplication.shared.setAlternateIconName(desired, completionHandler: nil)
    }

    @MainActor
    func apply(completion: ((Error?) -> Void)? = nil) {
        guard UIApplication.shared.supportsAlternateIcons else {
            completion?(nil)
            return
        }
        let name = catalogName
        UIApplication.shared.setAlternateIconName(name) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
}
