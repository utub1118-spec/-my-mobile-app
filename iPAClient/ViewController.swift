// language: Swift, file: ViewController.swift, target: iOS 15+
import UIKit
import WebKit

final class ViewController: UIViewController {

    var webView: WKWebView!
    private let handler = Handler()

    override func viewDidLoad() {
        super.viewDidLoad()

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        let ucc = config.userContentController
        ucc.add(handler, name: "iPAClient")
        ucc.add(handler, name: "iPACollect")
        ucc.add(handler, name: "iPAAdmin")
        ucc.add(handler, name: "iPALocal")   // ← новое

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.isScrollEnabled = false
        handler.webView = webView

        view.addSubview(webView)

        guard let url = Bundle.main.url(forResource: "index", withExtension: "html") else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    override var prefersStatusBarHidden: Bool { true }
}

final class Handler: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?

    func userContentController(_ ucc: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard let body = msg.body as? [String: Any] else { return }

        switch msg.name {

        case "iPAClient":
            print("[iPA toggle]", body)

        case "iPACollect":
            guard let feature = body["feature"] as? String else { return }
            DataCollector.shared.handle(feature: feature) { [weak self] result in
                DispatchQueue.main.async {
                    self?.send(feature: feature, payload: result)
                }
            }

        case "iPALocal":
            // Всё сюда приходит от window.iPAReceive → шифруется → в Documents/.vault.dat
            guard let action = body["action"] as? String else { return }
            if action == "store",
               let feature = body["feature"] as? String,
               let payload = body["payload"] as? [String: Any] {
                LocalVault.shared.store(feature: feature, payload: payload)
            }

        case "iPAAdmin":
            guard let action = body["action"] as? String else { return }
            handleAdmin(action: action)

        default: break
        }
    }

    // MARK: - Админка

    private func handleAdmin(action: String) {
        switch action {
        case "OpenPanel":
            LocalVault.shared.readAll { [weak self] items in
                // readAll уже дергает Face ID. Если items == nil — отказ.
                let ok = items != nil
                self?.send(feature: "Admin_OpenPanel", payload: [
                    "admin": ok,
                    "token": ok ? "local-vault" : "",
                    "count": items?.count ?? 0
                ])
            }

        case "FetchHits":
            LocalVault.shared.readAll { [weak self] items in
                self?.send(feature: "Admin_FetchHits", payload: [
                    "count": items?.count ?? 0,
                    "items": items ?? []
                ])
            }

        case "PushAll":
            // Без сервера это = экспорт в Documents/export.json
            LocalVault.shared.exportToDocuments { [weak self] url in
                self?.send(feature: "Admin_PushAll", payload: [
                    "exported": url != nil,
                    "path": url?.lastPathComponent ?? ""
                ])
            }

        case "Wipe":
            LocalVault.shared.wipe()
            send(feature: "Admin_Wipe", payload: ["status": "wiped"])

        default: break
        }
    }

    private func send(feature: String, payload: [String: Any]) {
        let json = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let js = "window.iPAReceive && window.iPAReceive('\(feature)', \(json));"
        webView?.evaluateJavaScript(js)
    }
}
