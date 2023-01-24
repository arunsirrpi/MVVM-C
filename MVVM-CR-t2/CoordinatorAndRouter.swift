//
//  Coordinator.swift
//  MVVM-CR-t2
//
//  Created by Arun Sinthanaisirrpi on 23/1/2023.
//

import Foundation
import UIKit
import Combine

protocol NavigationStep {}

protocol CoordinatableScreen {
    var screenID: UUID { get }
    var viewController: UIViewController { get }
}

protocol CoordinatorProtocol: AnyObject {
    associatedtype NavigationStepType: NavigationStep
    var coordinatableScreen: CoordinatableScreen { get }
    var navigationBindings: ViewControllerNavigationBinding? { get }
    var subscriptions: Set<AnyCancellable> { get set }
    var childCoordinators: [UUID: Any] { get set }
    func handleFlow(forNavigationStep: NavigationStepType)
}

extension CoordinatorProtocol {
    func setupFlowLogicBinding() {
        /// Routing
        navigationBindings?
            .nextNavigationStepPublisher
            .compactMap { $0 as? NavigationStepType }
            .compactMap { $0 }
            .sink{ [unowned self] navigationStep in
                self.handleFlow(forNavigationStep: navigationStep)
            }
            .store(in: &subscriptions)
    }
    
    func addChild(coordinator: any CoordinatorProtocol) {
        childCoordinators[coordinator.coordinatableScreen.screenID] = coordinator
        print("Child coordinator count (add): \(childCoordinators.count)")
    }
    
    func removeChild(withId id: UUID) {
        childCoordinators.removeValue(forKey: id)
        print("Child coordinator count (remove): \(childCoordinators.count)")
    }
}

protocol RootCoordinatorProtocol: AnyObject {
    var navigationController: UINavigationController { get }
}

protocol ViewControllerNavigationBinding {
    var nextNavigationStepPublisher: AnyPublisher<NavigationStep?, Never> { get }
}

// MARK: - Coordinator Implementation
enum NavigationStepsFromHome: CaseIterable, NavigationStep {
    case chromecast
    case stationList
    case settings
}

//MARK: - RootCoordinator
final class HomeRootCoordinator: CoordinatorProtocol, RootCoordinatorProtocol {
    typealias NavigationStepType = NavigationStepsFromHome
    
    let coordinatableScreen: CoordinatableScreen = {
        let viewModel = ReusableDemoViewModel(
            name: "Root",
            backgroundColor: .gray
        )
        return ReusableDemoViewController(withViewModel: viewModel)
    }()
    
    var childCoordinators = [UUID: Any]()
    var navigationBindings: ViewControllerNavigationBinding? { coordinatableScreen.viewController as? ViewControllerNavigationBinding }
    let navigationController: UINavigationController
    let navigationRouter: NavigationStackRouter
    var subscriptions = Set<AnyCancellable>()
    
    init() {
        navigationController = UINavigationController(rootViewController: coordinatableScreen.viewController)
        navigationRouter = NavigationStackRouter(navigationController: navigationController)
        /// cleanup subscribtion
        navigationRouter
            .$poppedViewControllerID
            .compactMap { $0 }
            .sink { [unowned self] screenID in
                self.removeChild(withId: screenID)
            }
            .store(in: &subscriptions)
        setupFlowLogicBinding()
    }
    
    func handleFlow(forNavigationStep navigationStep: NavigationStepsFromHome) {
        let childCoordinator: any CoordinatorProtocol
        switch navigationStep {
            case.chromecast:
                childCoordinator = ChromeCastCoordinator()
            case .settings:
                childCoordinator = SettingsCoordinator()
            case .stationList:
                childCoordinator = StationListCoordinator()
        }
        addChild(coordinator: childCoordinator)
        navigationController.pushViewController(childCoordinator.coordinatableScreen.viewController, animated: true)
    }
}

//MARK: - Navigation Stack for Routing
final class NavigationStackRouter: NSObject, UINavigationControllerDelegate {
    
    weak var navigationController: UINavigationController?
    @Published
    var poppedViewControllerID: UUID? = nil
    
    init(navigationController: UINavigationController? = nil) {
        self.navigationController = navigationController
        super.init()
        self.navigationController?.delegate = self
    }
    
//    func push(screen: CoordinatableScreen) {
//        navigationController?.pushViewController(
//            screen.viewController,
//            animated: true
//        )
//    }
//
//    func pop(screen: CoordinatableScreen) {
//        navigationController?.popViewController(animated: true)
//    }
    
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        guard
            let fromViewController = navigationController.transitionCoordinator?.viewController(forKey: .from),
            navigationController.viewControllers.contains(fromViewController) == false,
            let poppedCoordinatableScreen = fromViewController as? CoordinatableScreen
        else {
            return
        }
        /// let the co-ordinator perform the clean up
        poppedViewControllerID = poppedCoordinatableScreen.screenID
    }
}

//MARK: - Coordinators
final class ChromeCastCoordinator: CoordinatorProtocol {
    
    var subscriptions = Set<AnyCancellable>()
    var childCoordinators = [UUID: Any]()
    typealias NavigationStepType = NavigationStepsFromHome
    let coordinatableScreen: CoordinatableScreen = {
        let viewModel = ReusableDemoViewModel(
            name: "Chromecast",
            backgroundColor: .green
        )
        return ReusableDemoViewController(withViewModel: viewModel)
    }()
    
    var navigationBindings: ViewControllerNavigationBinding? { coordinatableScreen.viewController as? ViewControllerNavigationBinding }
    init() {
        setupFlowLogicBinding()
    }
    deinit {
        print("deallocation: chromecast coordinator")
    }
    
    func handleFlow(forNavigationStep: NavigationStepsFromHome) {
        
    }
}

final class SettingsCoordinator: CoordinatorProtocol {
    var subscriptions = Set<AnyCancellable>()
    var childCoordinators = [UUID: Any]()
    typealias NavigationStepType = NavigationStepsFromHome
    let coordinatableScreen: CoordinatableScreen = {
        let viewModel = ReusableDemoViewModel(
            name: "Settings",
            backgroundColor: .green
        )
        return ReusableDemoViewController(withViewModel: viewModel)
    }()
    
    var navigationBindings: ViewControllerNavigationBinding? { coordinatableScreen.viewController as? ViewControllerNavigationBinding }
    
    deinit {
        print("deallocation: Settings coordinator")
    }
    
    func handleFlow(forNavigationStep: NavigationStepsFromHome) {
        
    }
}

final class StationListCoordinator: CoordinatorProtocol {
    var subscriptions = Set<AnyCancellable>()
    typealias NavigationStepType = NavigationStepsFromHome
    var childCoordinators = [UUID: Any]()
    let coordinatableScreen: CoordinatableScreen = {
        let viewModel = ReusableDemoViewModel(
            name: "StationList",
            backgroundColor: .green
        )
        return ReusableDemoViewController(withViewModel: viewModel)
    }()
    init() {
        setupFlowLogicBinding()
    }
    var navigationBindings: ViewControllerNavigationBinding? { coordinatableScreen.viewController as? ViewControllerNavigationBinding }
    
    deinit {
        print("deallocation: Station list coordinator")
    }
    
    func handleFlow(forNavigationStep navigationStep: NavigationStepsFromHome) {
        let childCoordinator: any CoordinatorProtocol
        switch navigationStep {
            case.chromecast:
                childCoordinator = ChromeCastCoordinator()
            case .settings:
                childCoordinator = SettingsCoordinator()
            case .stationList:
                childCoordinator = StationListCoordinator()
        }
        addChild(coordinator: childCoordinator)
        coordinatableScreen.viewController.navigationController?.pushViewController(childCoordinator.coordinatableScreen.viewController, animated: true)
    }
}
