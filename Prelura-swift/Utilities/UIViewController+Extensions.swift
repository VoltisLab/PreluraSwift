import UIKit

/// Call from SwiftUI when the tab bar should be visible (e.g. tab root onAppear, or after popping from detail).
func showAppTabBar() {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first,
          let tbc = window.rootViewController?.findTabBarController() else { return }
    tbc.tabBar.isHidden = false
}

/// Call when entering a full-screen flow that should hide the tab bar (e.g. product detail). Pair with showAppTabBar() on exit.
func hideAppTabBar() {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first,
          let tbc = window.rootViewController?.findTabBarController() else { return }
    tbc.tabBar.isHidden = true
}

extension UIViewController {
    func findTabBarController() -> UITabBarController? {
        if let tabBarController = self as? UITabBarController {
            return tabBarController
        }
        
        if let navigationController = self as? UINavigationController {
            return navigationController.viewControllers.first?.findTabBarController()
        }
        
        for child in children {
            if let tabBarController = child.findTabBarController() {
                return tabBarController
            }
        }
        
        return parent?.findTabBarController()
    }
}
