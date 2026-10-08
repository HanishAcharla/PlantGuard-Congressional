import SwiftData
import SwiftUI

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @Environment(\.modelContext) private var context
    @Query private var orchards: [Orchard]
    @State private var preparing = false

    var body: some View {
        ZStack {
            if hasOnboarded && !orchards.isEmpty {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else if !preparing {
                OnboardingView { withHistory in prepare(withHistory: withHistory) }
                    .transition(.opacity)
            }
            if preparing {
                PreparingView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: hasOnboarded)
        .animation(.easeInOut(duration: 0.4), value: preparing)
        .task {
            #if DEBUG
            if DebugLaunch.seedDemo && orchards.isEmpty { prepare(withHistory: true) }
            #endif
            await LeafClassifier.shared.warmUp()
        }
    }

    private func prepare(withHistory: Bool) {
        preparing = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            try? DemoSeeder.reset(context, withHistory: withHistory)
            try? await Task.sleep(for: .milliseconds(600))
            Haptics.success()
            hasOnboarded = true
            preparing = false
        }
    }
}

private struct PreparingView: View {
    @State private var phase = 0
    private let diseases: [Disease] = [.healthy, .scab, .rust, .powderyMildew, .frogEyeLeafSpot]

    var body: some View {
        VStack(spacing: 22) {
            LeafArt(disease: diseases[phase % diseases.count], seed: phase * 31, tilt: false)
                .frame(width: 120, height: 120)
                .id(phase)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            Text("Planting your orchard")
                .font(.display(24)).foregroundStyle(Theme.textPrimary)
            Text("Laying out 254 trees and nine seasons of survey history")
                .font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
            ProgressView().tint(Theme.rustLight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(380))
                withAnimation(.spring(response: 0.4)) { phase += 1 }
            }
        }
    }
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    @State private var homePath = NavigationPath()

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            TabView(selection: $router.tab) {
                NavigationStack(path: $homePath) { HomeView().appRoutes() }
                    .toolbar(.hidden, for: .tabBar)
                    .tag(AppTab.home)
                NavigationStack { OrchardView().appRoutes() }
                    .toolbar(.hidden, for: .tabBar)
                    .tag(AppTab.orchard)
                NavigationStack { SeasonsView().appRoutes() }
                    .toolbar(.hidden, for: .tabBar)
                    .tag(AppTab.seasons)
                NavigationStack { CommunityView().appRoutes() }
                    .toolbar(.hidden, for: .tabBar)
                    .tag(AppTab.community)
            }
            FloatingTabBar(selection: $router.tab) { router.startScan() }
                .padding(.bottom, 6)
                .ignoresSafeArea(.keyboard)
        }
        .fullScreenCover(item: $router.scanRequest) { request in
            ScanFlowView(preselectedTreeCode: request.treeCode)
        }
        #if DEBUG
        .task { DebugLaunch.apply(router: router, homePath: &homePath) }
        #endif
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    var onScan: () -> Void
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            item(.home)
            item(.orchard)
            scanButton
            item(.seasons)
            item(.community)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Theme.canopy950.opacity(0.6)))
        }
        .overlay(Capsule().strokeBorder(Theme.parchment.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
        .padding(.horizontal, 16)
    }

    private func item(_ tab: AppTab) -> some View {
        let selected = selection == tab
        return Button {
            guard !selected else { return }
            Haptics.tap()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolEffect(.bounce, value: selected)
                    .frame(height: 22)
                Text(tab.title).font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(selected ? Theme.parchment : Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                if selected {
                    Capsule().fill(Theme.parchment.opacity(0.1))
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var scanButton: some View {
        Button(action: onScan) {
            ZStack {
                Circle().fill(Theme.rustGradient)
                    .frame(width: 60, height: 60)
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .shadow(color: Theme.rust.opacity(0.65), radius: 16, y: 6)
                Image(systemName: "viewfinder")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(PressableStyle())
        .offset(y: -16)
        .padding(.horizontal, 4)
        .accessibilityLabel("Scan a leaf")
    }
}
