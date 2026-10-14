import ApplicationLibrary
import Foundation
import Library
import SwiftUI

@main
struct Application: App {
    @UIApplicationDelegateAdaptor private var appDelegate: ApplicationDelegate
    @StateObject private var environments = ExtensionEnvironments()
    @StateObject private var peerStore = TailscaleSSHPeerStore()
    @StateObject private var tailscaleViewModel = TailscaleStatusViewModel()
    @StateObject private var taildropSendManager = TaildropSendManager()
    @StateObject private var taildropInbox = TaildropInboxViewModel()
    @StateObject private var license = LicenseManager.shared

    // 0=checking, 1=blacklisted(kill), 2=need login, 3=need relogin, 4=ok
    @State private var licenseState: Int = 0

    init() {
        Task { @MainActor in
            await ImportedFontStore.shared.bootstrap()
        }
    }

    var body: some Scene {
        WindowGroup {
            switch licenseState {
            case 0:
                // 启动检查中
                ZStack {
                    Color(red: 0.06, green: 0.06, blue: 0.07).ignoresSafeArea()
                    ProgressView("正在验证...")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
                .task {
                    // 1. 黑名单检查
                    let notBlacklisted = await license.checkBlacklist()
                    if !notBlacklisted {
                        licenseState = 1
                        return
                    }
                    // 2. 已注册 → 后台验证
                    if license.isRegistered {
                        let result = await license.verify()
                        switch result {
                        case .ok:
                            licenseState = 4
                        case .invalid(let msg):
                            license.errorMessage = msg
                            license.needReLogin = true
                            licenseState = 3
                        case .killed:
                            licenseState = 1
                        case .networkError:
                            // 网络问题 → 允许进入（后续 verify 会拦截）
                            licenseState = 4
                        }
                    } else {
                        // 3. 未注册 → 登录页
                        licenseState = 2
                    }
                }

            case 1:
                // 被拉黑 → 闪退屏
                LicenseKillView()

            case 2:
                // 首次登录
                LicenseLoginView()
                    .environmentObject(environments)
                    .onChange(of: license.isRegistered) { registered in
                        if registered { licenseState = 4 }
                    }

            case 3:
                // 卡密失效 → 重新登录
                LicenseReLoginView()
                    .environmentObject(environments)
                    .onChange(of: license.isRegistered) { registered in
                        if registered {
                            license.needReLogin = false
                            licenseState = 4
                        }
                    }

            default:
                // 正常进入主界面 + VPN连接后自动校验
                MainView()
                    .tailscaleStatusSubscription(tailscaleViewModel, environments: environments, peerStore: peerStore)
                    .environmentObject(environments)
                    .environmentObject(peerStore)
                    .environmentObject(tailscaleViewModel)
                    .environmentObject(taildropSendManager)
                    .environmentObject(taildropInbox)
                    .onReceive(environments.$extensionProfile) { profile in
                        guard let profile = profile else { return }
                        // 监听 VPN 连接状态
                        if profile.status == .connected {
                            // 连接后 10 秒自动校验
                            Task {
                                try? await Task.sleep(nanoseconds: 10_000_000_000)
                                let result = await license.verify()
                                await MainActor.run {
                                    switch result {
                                    case .killed:
                                        licenseState = 1
                                    case .invalid(let msg):
                                        license.errorMessage = msg
                                        license.needReLogin = true
                                        licenseState = 3
                                    default:
                                        break // ok 或网络错误 → 继续
                                    }
                                }
                            }
                        }
                    }
            }
        }
    }
}
