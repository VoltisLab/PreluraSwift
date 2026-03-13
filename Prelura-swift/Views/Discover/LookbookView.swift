//
//  LookbookView.swift
//  Prelura-swift
//
//  Photo grid (3 per row); tap → overlay (image above grid); tap overlay again → modal with slider.
//  Up to 10 random entrance/exit animations for grid and overlay.
//

import SwiftUI

/// One lookbook cell: one or more image asset names (multiple = slider in modal).
struct LookbookEntry: Identifiable {
    let id = UUID()
    let imageNames: [String]
}

private let lookbookGridColumns = 2
/// Spacing between cells. No overlap so no photo has >40% covered.
private let lookbookSpacing: CGFloat = 8

/// Static lookbook content. Some entries have multiple images for slider.
private let lookbookEntries: [LookbookEntry] = [
    LookbookEntry(imageNames: ["LookbookGrid1"]),
    LookbookEntry(imageNames: ["LookbookGrid2", "LookbookGrid3"]),
    LookbookEntry(imageNames: ["LookbookGrid4"]),
    LookbookEntry(imageNames: ["LookbookGrid5", "LookbookGrid6"]),
    LookbookEntry(imageNames: ["LookbookGrid7"]),
    LookbookEntry(imageNames: ["LookbookGrid8"]),
    LookbookEntry(imageNames: ["LookbookGrid1", "LookbookGrid2"]),
    LookbookEntry(imageNames: ["LookbookGrid3"]),
    LookbookEntry(imageNames: ["LookbookGrid4", "LookbookGrid5", "LookbookGrid6"]),
    LookbookEntry(imageNames: ["LookbookGrid7"]),
    LookbookEntry(imageNames: ["LookbookGrid8"]),
    LookbookEntry(imageNames: ["LookbookGrid1"]),
]

// MARK: - Random transitions (up to 10) for entrance/exit
private let entranceTransitions: [AnyTransition] = [
    .opacity,
    .scale(scale: 0.3),
    .move(edge: .leading),
    .move(edge: .trailing),
    .move(edge: .top),
    .move(edge: .bottom),
    .slide,
    .asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.8)), removal: .opacity),
    .asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)),
    .asymmetric(insertion: .scale(scale: 0.5).combined(with: .opacity), removal: .opacity),
]

private func transitionForIndex(_ index: Int) -> AnyTransition {
    entranceTransitions[index % entranceTransitions.count]
}

struct LookbookView: View {
    @State private var overlayEntry: LookbookEntry?
    @State private var modalEntry: LookbookEntry?
    @State private var fullScreenIndex: Int = 0
    @State private var gridHasAppeared: Bool = false
    @State private var overlayTransitionIndex: Int = 0
    @State private var modalTransitionIndex: Int = 0
    /// Front-to-back order for tap-to-bring-forward. Last = front.
    @State private var frontToBackIds: [UUID] = lookbookEntries.map(\.id)

    var body: some View {
        ZStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: lookbookSpacing), count: lookbookGridColumns), spacing: lookbookSpacing) {
                    ForEach(Array(lookbookEntries.enumerated()), id: \.element.id) { index, entry in
                        lookbookCell(entry: entry, index: index)
                    }
                }
                .padding(lookbookSpacing)
                .padding(.top, Theme.Spacing.lg)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    gridHasAppeared = true
                }
            }

            if let entry = overlayEntry {
                lookbookOverlay(entry: entry)
                    .transition(transitionForIndex(overlayTransitionIndex))
                    .zIndex(1000)
            }
        }
        .navigationTitle(L10n.string("Lookbooks"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fullScreenCover(item: $modalEntry) { entry in
            LookbookFullScreenView(entry: entry, initialIndex: fullScreenIndex) {
                modalEntry = nil
            }
            .transition(transitionForIndex(modalTransitionIndex))
        }
    }

    private func lookbookCell(entry: LookbookEntry, index: Int) -> some View {
        let name = entry.imageNames[0]
        let zOrder = frontToBackIds.firstIndex(of: entry.id) ?? 0
        return Button(action: {
            bringToFront(entry: entry)
        }) {
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
        .buttonStyle(.plain)
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .contentShape(Rectangle())
        .zIndex(Double(zOrder))
        .opacity(gridHasAppeared ? 1 : 0)
        .scaleEffect(gridHasAppeared ? 1 : scaleForEntrance(index % 10))
        .offset(offsetForEntrance(index % 10, appeared: gridHasAppeared))
        .animation(.easeOut(duration: 0.4).delay(Double(index % 12) * 0.03), value: gridHasAppeared)
        .transition(transitionForIndex(index))
        .onTapGesture(count: 2) {
            overlayTransitionIndex = Int.random(in: 0..<entranceTransitions.count)
            withAnimation(.easeInOut(duration: 0.3)) {
                overlayEntry = entry
            }
        }
    }

    private func bringToFront(entry: LookbookEntry) {
        guard let idx = frontToBackIds.firstIndex(of: entry.id), idx < frontToBackIds.count - 1 else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            frontToBackIds.remove(at: idx)
            frontToBackIds.append(entry.id)
        }
    }

    private func scaleForEntrance(_ style: Int) -> CGFloat {
        switch style {
        case 0, 2, 4: return 0.6
        case 1, 3, 5: return 0.85
        default: return 0.75
        }
    }

    private func offsetForEntrance(_ style: Int, appeared: Bool) -> CGSize {
        guard !appeared else { return .zero }
        let d: CGFloat = 40
        switch style {
        case 2: return CGSize(width: -d, height: 0)
        case 3: return CGSize(width: d, height: 0)
        case 4: return CGSize(width: 0, height: -d)
        case 5: return CGSize(width: 0, height: d)
        case 6: return CGSize(width: d, height: 0)
        case 7: return CGSize(width: -d, height: d * 0.5)
        case 8: return CGSize(width: 0, height: d)
        case 9: return CGSize(width: -d * 0.5, height: 0)
        default: return .zero
        }
    }

    private func lookbookOverlay(entry: LookbookEntry) -> some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .onTapGesture {
                fullScreenIndex = 0
                modalTransitionIndex = Int.random(in: 0..<entranceTransitions.count)
                modalEntry = overlayEntry
                withAnimation(.easeInOut(duration: 0.25)) {
                    overlayEntry = nil
                }
            }
            .overlay {
                Image(entry.imageNames[0])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(Theme.Spacing.lg)
                    .onTapGesture {
                        fullScreenIndex = 0
                        modalTransitionIndex = Int.random(in: 0..<entranceTransitions.count)
                        modalEntry = overlayEntry
                        withAnimation(.easeInOut(duration: 0.25)) {
                            overlayEntry = nil
                        }
                    }
            }
    }
}

struct LookbookFullScreenView: View {
    let entry: LookbookEntry
    let initialIndex: Int
    let onDismiss: () -> Void
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $currentIndex) {
                ForEach(Array(entry.imageNames.enumerated()), id: \.offset) { index, name in
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: entry.imageNames.count > 1 ? .automatic : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .ignoresSafeArea()
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear { currentIndex = initialIndex }
    }
}

extension LookbookEntry: Equatable {
    static func == (lhs: LookbookEntry, rhs: LookbookEntry) -> Bool { lhs.id == rhs.id }
}

#if DEBUG
struct LookbookView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LookbookView()
        }
    }
}
#endif
