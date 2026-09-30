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
            // старый toggle — можно логировать
            print("[iPA toggle]", body)

        case "iPACollect":
            guard let feature = body["feature"] as? String else { return }
            DataCollector.shared.handle(feature: feature) { [weak self] result in
                DispatchQueue.main.async {
                    self?.send(feature: feature, payload: result)
                }
            }

        case "iPAAdmin":
            guard let action = body["action"] as? String else { return }
            AdminServer.shared.handle(action: action) { [weak self] result in
                DispatchQueue.main.async {
                    self?.send(feature: "Admin_" + action, payload: result)
                }
            }

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
