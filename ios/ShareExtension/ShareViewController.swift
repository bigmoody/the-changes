// Taking a chart from another app's share sheet.
//
// On iOS this is the only way in when iReal Pro is installed, because it
// owns the links and two apps claiming one scheme is undefined: tapping
// one opens iReal Pro, as it probably should. Sharing is the way round
// that, and sharing into an app needs an extension, which is a separate
// little program with its own sandbox.
//
// It does as little as possible. It takes the text or the link and
// knocks on the app with it. Everything about what a chart is and what
// to do with one stays in the app.
//
// The chart travels in the knock rather than in a shared container. A
// container between an extension and its app is an App Group, and an App
// Group is an entitlement, which is a provisioning profile, which is a
// thing to go wrong on somebody else's phone for a feature whose whole
// job is to carry one short line of text.

import MobileCoreServices
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    guard
      let item = extensionContext?.inputItems.first as? NSExtensionItem,
      let providers = item.attachments
    else {
      return finish()
    }
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
        load(provider, as: UTType.url.identifier)
        return
      }
      if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        load(provider, as: UTType.plainText.identifier)
        return
      }
    }
    finish()
  }

  private func load(_ provider: NSItemProvider, as type: String) {
    provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] value, _ in
      let text: String?
      switch value {
      case let url as URL: text = url.absoluteString
      case let string as String: text = string
      default: text = nil
      }
      DispatchQueue.main.async {
        if let text, !text.isEmpty {
          self?.openTheApp(with: text)
        }
        self?.finish()
      }
    }
  }

  /// Opens the app, carrying the chart.
  ///
  /// An extension cannot open a URL directly, so it asks whatever is
  /// above it in the responder chain to do it: the usual way round a
  /// restriction that has no official way round it.
  private func openTheApp(with text: String) {
    var parts = URLComponents()
    parts.scheme = "thechanges"
    parts.host = "shared"
    parts.queryItems = [URLQueryItem(name: "text", value: text)]
    guard let url = parts.url else { return }
    var responder: UIResponder? = self
    while let next = responder {
      if let application = next as? UIApplication {
        application.open(url)
        return
      }
      responder = next.next
    }
  }

  private func finish() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}
