//
//  SafariBrowserView.swift
//  iOS-NativeSafari
//

import SwiftUI
import WebKit

// MARK: - WebViewStore
class WebViewStore: ObservableObject {
    weak var webView: WKWebView?

    func goBack()    { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload()    { webView?.reload() }
    func stop()      { webView?.stopLoading() }
}

// MARK: - WKWebView UIViewRepresentable
struct SafariWebViewRepresentable: UIViewRepresentable {
    let url: URL
    let store: WebViewStore
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    var onScrollOffset: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        // Bottom inset so content isn't hidden behind the floating chrome
        webView.scrollView.contentInset.bottom = 130
        webView.scrollView.verticalScrollIndicatorInsets.bottom = 130
        store.webView = webView
        context.coordinator.observeScrollView(webView.scrollView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SafariWebViewRepresentable
        private var scrollObservation: NSKeyValueObservation?

        init(_ parent: SafariWebViewRepresentable) { self.parent = parent }

        deinit { scrollObservation?.invalidate() }

        func observeScrollView(_ scrollView: UIScrollView) {
            scrollObservation = scrollView.observe(\.contentOffset, options: .new) { [weak self] sv, _ in
                DispatchQueue.main.async {
                    self?.parent.onScrollOffset(sv.contentOffset.y)
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }
    }
}

// MARK: - SafariBrowserView
@available(iOS 26.0, *)
struct SafariBrowserView: View {
    let url: URL
    var onLock: () -> Void = {}
    var showChrome: Bool = false

    @StateObject private var store = WebViewStore()
    @State private var canGoBack    = false
    @State private var canGoForward = false
    @State private var isLoading    = false
    @State private var isCollapsed  = false
    @Namespace private var ns

    // Strips "www." prefix for cleaner display
    private var displayHost: String {
        (url.host ?? url.absoluteString)
            .replacingOccurrences(of: "www.", with: "")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // WebView — full screen
            SafariWebViewRepresentable(
                url: url,
                store: store,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                isLoading: $isLoading,
                onScrollOffset: updateCollapse
            )
            .ignoresSafeArea()

            // Floating bottom chrome
            if showChrome {
                bottomChrome
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    // MARK: - Bottom chrome
    @ViewBuilder
    private var bottomChrome: some View {
        GlassEffectContainer(spacing: 8) {
            if isCollapsed {
                // ── Collapsed: solo pill del dominio centrada ──────────────
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(displayHost)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 20)
                .frame(height: 44)
                .glassEffect(.regular.interactive(), in: Capsule())
                .glassEffectID("urlbar", in: ns)

            } else {
                // ── Expanded: address bar row ──────────────────────────────
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        // Back siempre visible; Forward solo cuando hay historial adelante
                        HStack(spacing: 0) {
                            Button { store.goBack() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(canGoBack ? .primary : .tertiary)
                                    .frame(width: 44, height: 44)
                            }
                            .disabled(!canGoBack)

                            if canGoForward {
                                Button { store.goForward() } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .frame(width: 44, height: 44)
                                }
                            }
                        }
                        .glassEffect(.regular.interactive(), in: Capsule())
                        .glassEffectID("nav", in: ns)

                        // URL pill (wide)
                        HStack(spacing: 6) {
                            Text(displayHost)
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Spacer()
                            Button {
                                if isLoading { store.stop() } else { store.reload() }
                            } label: {
                                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .glassEffect(.regular.interactive(), in: Capsule())
                        .glassEffectID("urlbar", in: ns)

                        // Tabs
                        tabsButton
                            .glassEffect(.regular.interactive(), in: Capsule())
                            .glassEffectID("tabs", in: ns)
                    }
                }
            }
        }
        // Loading bar at the very top of the chrome
        .overlay(alignment: .top) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .frame(maxWidth: .infinity)
                    .offset(y: -6)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Tabs button → returns to lock screen
    private var tabsButton: some View {
        Button {
            onLock()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Scroll → collapse
    private func updateCollapse(scrollY: CGFloat) {
        let should = scrollY > 60
        guard should != isCollapsed else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isCollapsed = should
        }
    }
}

// MARK: - Preview
@available(iOS 26.0, *)
#Preview("Safari Browser") {
    SafariBrowserView(url: URL(string: "https://www.apple.com")!)
}
