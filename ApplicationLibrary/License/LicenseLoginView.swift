import SwiftUI
import UIKit

// ─── 登录页：设备码 + 卡密输入框 ───

public struct LicenseLoginView: View {
    @ObservedObject private var license = LicenseManager.shared
    @State private var copied = false

    public init() {}

    public var body: some View {
        ZStack {
            // 深色背景
            Color(red: 0.06, green: 0.06, blue: 0.07).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Logo
                    VStack(spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 56))
                            .foregroundStyle(.blue)
                        Text("VPN")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 40)

                    // 设备码
                    VStack(alignment: .leading, spacing: 8) {
                        Text("设备码")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(license.deviceID)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = license.deviceID
                                withAnimation { copied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { copied = false }
                                }
                            } label: {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    .font(.body)
                                    .foregroundStyle(copied ? .green : .blue)
                            }
                        }
                        .padding(16)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 卡密输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("卡密")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("XXXX-XXXX-XXXX-XXXX-XXXX", text: $license.cardKey)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 登录按钮
                    Button {
                        Task {
                            let ok = await license.register()
                            if !ok {
                                license.needReLogin = true
                            }
                        }
                    } label: {
                        HStack {
                            if license.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("激活")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(license.isLoading)
                    .padding(.top, 8)

                    // 错误提示
                    if license.showError {
                        Text(license.errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .alert("提示", isPresented: $license.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(license.errorMessage)
        }
    }
}

// ─── 卡密失效重新登录页 ───

public struct LicenseReLoginView: View {
    @ObservedObject private var license = LicenseManager.shared
    @State private var copied = false

    public init() {}

    public var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.07).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                    .padding(.top, 40)

                Text(license.errorMessage.isEmpty ? "卡密已失效" : license.errorMessage)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("请输入新的卡密")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // 设备码
                HStack {
                    Text(license.deviceID)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.gray)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = license.deviceID
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(copied ? .green : .blue)
                    }
                }
                .padding(12)
                .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                TextField("XXXX-XXXX-XXXX-XXXX-XXXX", text: $license.cardKey)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    Task {
                        let ok = await license.register()
                        if ok {
                            license.needReLogin = false
                        }
                    }
                } label: {
                    HStack {
                        if license.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("重新激活")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(license.isLoading)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}

// ─── 闪退屏（黑名单设备）───

public struct LicenseKillView: View {
    public init() {}
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)
                Text("设备已被禁用")
                    .font(.title3.bold())
                    .foregroundStyle(.red)
            }
        }
        .onAppear {
            // 0.5 秒后强制退出
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                exit(0)
            }
        }
    }
}
