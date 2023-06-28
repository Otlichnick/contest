//
//  AppAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class AppAssembly {
  
  lazy var tabBarAssembly = TabBarAssembly()
  lazy var onboardingAssembly = OnboardingAssembly()
  
  func tabBarCoordinator() -> TabBarCoordinator {
    let tabBarController = UITabBarController()
    tabBarController.configureAppearance()
    let router = TabBarRouter(rootViewController: tabBarController)
    let coordinator = TabBarCoordinator(router: router, assembly: tabBarAssembly)
    return coordinator
  }
  
  func onboardingCoordinator(output: OnboardingCoordinatorOutput) -> OnboardingCoordinator {
    let navigationController = UINavigationController()
    navigationController.setNavigationBarHidden(true, animated: false)
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = OnboardingCoordinator(router: router,
                                            assembly: onboardingAssembly)
    coordinator.output = output
    return coordinator
  }
}
