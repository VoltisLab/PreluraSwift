import SwiftUI

/// Notification settings: full page matching Flutter NotificationSettingScreen.
/// Push: main toggle + General (Likes, Messages, New Followers, Profile View).
/// Email: same structure with email preference.
struct NotificationSettingsView: View {
    let title: String // "Push" or "Email"
    @StateObject private var viewModel: NotificationSettingsViewModel

    init(title: String) {
        self.title = title
        _viewModel = StateObject(wrappedValue: NotificationSettingsViewModel(title: title))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.preference == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        Toggle(viewModel.isEmailMode ? "Email Notifications" : "Push Notifications", isOn: Binding(
                            get: { viewModel.mainToggleOn },
                            set: { viewModel.setMainToggle($0) }
                        ))
                        .tint(Theme.primaryColor)
                        .disabled(viewModel.isUpdating)
                    }

                    Section {
                        Text("General")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.primaryColor)
                    }

                    Section {
                        toggleRow("Likes", keyPath: \.likes)
                        toggleRow("Messages", keyPath: \.messages)
                        toggleRow("New Followers", keyPath: \.newFollowers)
                        toggleRow("Profile View", keyPath: \.profileView)
                    }

                    if let err = viewModel.errorMessage {
                        Section {
                            Text(err)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.error)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("\(title) Notification Settings")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    private func toggleRow(_ label: String, keyPath: WritableKeyPath<NotificationSubPreferences, Bool>) -> some View {
        Toggle(label, isOn: Binding(
            get: { viewModel.subPreferences[keyPath: keyPath] },
            set: { viewModel.setSub(keyPath: keyPath, value: $0) }
        ))
        .tint(Theme.primaryColor)
        .disabled(viewModel.subTogglesDisabled || viewModel.isUpdating)
    }
}
