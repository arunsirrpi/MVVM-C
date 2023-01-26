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
                print("Coordinator: Routing from coordinator \(coordinatableScreen.screenID) - Addrs: \(Unmanaged.passUnretained(self).toOpaque())")
                self.handleFlow(forNavigationStep: navigationStep)
            }
            .store(in: &subscriptions)
    }
    
    /// We need to perform this addition on the root coordinator level.
    func addChild(coordinator: any CoordinatorProtocol) {
        childCoordinators[coordinator.coordinatableScreen.screenID] = coordinator
        print(" Coordinatore parent:(\(coordinatableScreen.screenID)) :Child coordinator (id: \(coordinator.coordinatableScreen.screenID)) count (add) \(Unmanaged.passUnretained(self).toOpaque()): \(childCoordinators.count)")
    }
    
    ///
    func removeChild(withId id: UUID) {
        let result = childCoordinators.removeValue(forKey: id) as? any CoordinatorProtocol
        /// WE ARE NOT REMOVING FROM THE RIGHT COORDINATOR THIS IS THE ISSUE
        /// What's happening is, we are pushing the viewcontroller from the relevant
        /// co-ordinator
        print("Removed \(result?.coordinatableScreen.screenID)")
        print("Coordinatore parent:(\(coordinatableScreen.screenID)) :Child coordinator count (remove)\(Unmanaged.passUnretained(self).toOpaque()): \(childCoordinators.count)")
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
    
    private var onNewChildAdded = PassthroughSubject<(any CoordinatorProtocol)?, Never>()
    
    init() {
        navigationController = UINavigationController(rootViewController: coordinatableScreen.viewController)
        navigationRouter = NavigationStackRouter(navigationController: navigationController)
        /// cleanup subscribtion
        navigationRouter
            .$poppedViewControllerID
            .compactMap { $0 }
            .sink { [unowned self] screenID in
                print("popping Viewcontroller with id \(screenID)")
                self.removeChild(withId: screenID)
                print("Home Root coordinator (\(self.coordinatableScreen.screenID)): Child coordinators with count \(childCoordinators.count)")
            }
            .store(in: &subscriptions)
        onNewChildAdded
            .compactMap { $0 }
            .sink { [unowned self] childCoordinator in
                self.addChild(coordinator: childCoordinator)
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
                childCoordinator = StationListCoordinator(withChildCoordinatorAdded: onNewChildAdded)
        }
        addChild(coordinator: childCoordinator)
        navigationController.pushViewController(childCoordinator.coordinatableScreen.viewController, animated: true)
    }
    
    deinit {
        print("Deallocation home root coordinator \(Unmanaged.passUnretained(self).toOpaque())")
    }
}

//MARK: - Navigation Stack for Routing
final class NavigationStackRouter: NSObject, UINavigationControllerDelegate {
    
    private(set) weak var navigationController: UINavigationController?
    @Published
    var poppedViewControllerID: UUID? = nil
    
    init(navigationController: UINavigationController? = nil) {
        self.navigationController = navigationController
        super.init()
        self.navigationController?.delegate = self
    }
    
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

//MARK: - Child Coorodinators
final class StationListCoordinator: CoordinatorProtocol {
    
    var subscriptions = Set<AnyCancellable>()
    typealias NavigationStepType = NavigationStepsFromHome
    var childCoordinators = [UUID: Any]()
    
    weak var pushedNewChildCoordinator: PassthroughSubject<(any CoordinatorProtocol)?, Never>?
    
    let coordinatableScreen: CoordinatableScreen = {
        let viewModel = ReusableDemoViewModel(
            name: "StationList",
            backgroundColor: .blue
        )
        return ReusableDemoViewController(withViewModel: viewModel)
    }()
    init(withChildCoordinatorAdded onChildCoordinatorAdded: PassthroughSubject<(any CoordinatorProtocol)?, Never>?) {
        pushedNewChildCoordinator = onChildCoordinatorAdded
        setupFlowLogicBinding()
    }
    var navigationBindings: ViewControllerNavigationBinding? { coordinatableScreen.viewController as? ViewControllerNavigationBinding }
    
    deinit {
        print("deallocation: Station list coordinator \(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    func handleFlow(forNavigationStep navigationStep: NavigationStepsFromHome) {
        let childCoordinator: any CoordinatorProtocol
        switch navigationStep {
            case.chromecast:
                childCoordinator = ChromeCastCoordinator()
            case .settings:
                childCoordinator = SettingsCoordinator()
            case .stationList:
                let result = StationListCoordinator(withChildCoordinatorAdded: pushedNewChildCoordinator)
                childCoordinator = result
                print("pushing: Station list coordinator \(Unmanaged.passUnretained(result).toOpaque())")
        }
        /// Instead of add, let's perform a publush
        // addChild(coordinator: childCoordinator)
        pushedNewChildCoordinator?.send(childCoordinator)
        coordinatableScreen.viewController.navigationController?.pushViewController(childCoordinator.coordinatableScreen.viewController, animated: true)
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
        print("deallocation: chromecast coordinator \(Unmanaged.passUnretained(self).toOpaque())")
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
            backgroundColor: .red
        )
        return ReusableDemoViewController(withViewModel: viewModel)
    }()
    
    var navigationBindings: ViewControllerNavigationBinding? { coordinatableScreen.viewController as? ViewControllerNavigationBinding }
    
    deinit {
        print("deallocation: Settings coordinator \(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    func handleFlow(forNavigationStep: NavigationStepsFromHome) {
        
    }
}

