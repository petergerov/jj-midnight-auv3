import SwiftUI

struct AUViewControllerUI: UIViewControllerRepresentable {
    var auViewController: UIViewController?

    init(viewController: UIViewController?) {
        self.auViewController = viewController
    }

    func makeUIViewController(context: Context) -> UIViewController {
        guard let auViewController else { return UIViewController() }
        let viewController = UIViewController()
        viewController.addChild(auViewController)
        auViewController.view.frame = viewController.view.bounds
        auViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewController.view.addSubview(auViewController.view)
        auViewController.didMove(toParent: viewController)
        viewController.view.backgroundColor = .black
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
