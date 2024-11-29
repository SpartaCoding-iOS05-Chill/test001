//
//  MainViewController.swift
//  ChioskApp
//
//  Created on 2024-11-25.
//
//  Description:
//  - 이 파일은 MainViewController의 구현을 포함하며, 앱의 주요 UI를 관리합니다.
//  - MenuCategoryView와 OrderSummaryView를 조합하여 메뉴 선택, 주문 요약, 직원 호출, 주문 취소 등의 기능을 제공합니다.
//  - NotificationCenter를 활용하여 주문 데이터 변경 시 뷰를 업데이트합니다.
//

import UIKit
import SnapKit
import Then

// MARK: - MainViewController
class MainViewController: UIViewController {
    
    // MARK: - Properties
    let menuCategoryController = MenuCategoryController() // 메뉴 카테고리 뷰
    let orderSummaryView = OrderSummaryView()  // 주문 요약 뷰
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureUI()
        segmentChanged(menuCategoryController.segmentControl) // 초기 SegmentedControl 선택
        setupMenuDelegates()
        
        setupNotifications()
        setupOrderSummaryActions()
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .orderLimitExceeded, object: nil)
        NotificationCenter.default.removeObserver(self, name: .orderUpdated, object: nil)
    }
}

// MARK: - UI Configuration
extension MainViewController {
    func configureUI() {
        view.backgroundColor = .white
        
        // MARK: 상단 로고 추가
        view.addSubview(menuCategoryController.logo)
        menuCategoryController.logo.snp.makeConstraints {
            $0.top.height.equalTo(60)
            $0.leading.trailing.equalToSuperview()
        }
        
        // MARK: SegmentedControl 추가
        view.addSubview(menuCategoryController.segmentControl)
        menuCategoryController.segmentControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        menuCategoryController.segmentControl.snp.makeConstraints {
            $0.top.equalTo(menuCategoryController.logo.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(58)
        }
        
        // MARK: Place Holder 뷰들 레이아웃
        [menuCategoryController.chickenView, menuCategoryController.sidedishView, menuCategoryController.drinkView, menuCategoryController.etcView].forEach {
            view.addSubview($0)
            $0.snp.makeConstraints {
                $0.width.equalToSuperview()
                $0.height.equalTo(352)
                $0.top.equalTo(menuCategoryController.segmentControl.snp.bottom)
            }
        }
        
        // MARK: 주문 요약 뷰 추가
        view.addSubview(orderSummaryView)
        orderSummaryView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview() // 화면 하단에 고정
            $0.height.equalTo(342) // 주문 요약 뷰 높이 설정
        }
    }
}

// MARK: - Segmented Control Logic
extension MainViewController {
    @objc func segmentChanged(_ sender: UISegmentedControl) {
        [menuCategoryController.chickenView, menuCategoryController.sidedishView, menuCategoryController.drinkView, menuCategoryController.etcView].forEach {
            $0.isHidden = true // 해당 뷰 제외 나머지는 안보이게 숨김
        }
        
        switch sender.selectedSegmentIndex {
        case 0:
            menuCategoryController.chickenView.isHidden = false
        case 1:
            menuCategoryController.sidedishView.isHidden = false
        case 2:
            menuCategoryController.drinkView.isHidden = false
        case 3:
            menuCategoryController.etcView.isHidden = false
        default:
            break
        }
    }
}

// MARK: - Menu Delegates Setup
extension MainViewController {
    private func setupMenuDelegates() {
        menuCategoryController.chickenMenu.delegate = self
        menuCategoryController.sidedishMenu.delegate = self
        menuCategoryController.drinkMenu.delegate = self
        menuCategoryController.etcMenu.delegate = self
    }
}

// MARK: - Notifications
extension MainViewController {
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateOrderData),
            name: .orderUpdated,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orderLimitExceeded),
            name: .orderLimitExceeded,
            object: nil
        )
    }
    
    @objc private func updateOrderData() {
        orderSummaryView.reloadOrderCollectionView()
        orderSummaryView.updateItemQuantityLabel(with: OrderManager.shared.totalQuantity)
        orderSummaryView.updateAmountValueLabel(with: OrderManager.shared.totalAmount)
    }
}

// MARK: - Button Actions Setup
extension MainViewController {
    private func setupOrderSummaryActions() {
        // MARK: 직원 호출 Alert 버튼 액션 설정
        orderSummaryView.setEmployeeCallButtonAction(target: self, action: #selector(callAlert))
        // MARK: 주문 취소 Alert 버튼 액션 설정
        orderSummaryView.setCancelButtonAction(target: self, action: #selector(handleCancelOrder))
        // MARK: 주문 결제 Alert 버튼 액션 설정
        orderSummaryView.setPaymentButtonAction(target:self, action: #selector(handlePayment))
    }
}

// MARK: - Alert Handlers
extension MainViewController {
    // MARK: 주문 한도 초과 Alert
    @objc private func orderLimitExceeded(notification: Notification) {
        if let message = notification.object as? String {
            let alert = UIAlertController(title: "경고", message: message, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "확인", style: .default, handler: nil)
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: 직원 호출 Alert
    @objc func callAlert() {
        let alert = UIAlertController(title: "직원 호출", message: "직원을 호출하시겠습니까?", preferredStyle: .alert)
        let yes = UIAlertAction(title: "호출", style: .default, handler: nil)
        let cancel = UIAlertAction(title: "취소", style: .destructive, handler: nil)
        
        alert.addAction(cancel)
        alert.addAction(yes)
        
        present(alert, animated: true)
    }
    
    // MARK: 주문 취소 Alert
    @objc private func handleCancelOrder() {
        guard !OrderManager.shared.orders.isEmpty else {
            print("취소할 주문 내역이 없습니다.")
            return
        }
        
        let alert = UIAlertController(
            title: "주문 취소",
            message: "주문 내역을 모두 취소할까요?",
            preferredStyle: .alert
        )
        
        let confirmAction = UIAlertAction(title: "주문 취소", style: .destructive) { _ in
            OrderManager.shared.resetOrders()
            NotificationCenter.default.post(name: .orderUpdated, object: nil)
            print("주문이 취소되었습니다.")
        }
        
        let cancelAction = UIAlertAction(title: "돌아가기", style: .cancel, handler: nil)
        
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: 주문 결제 Alert
    @objc private func handlePayment() {
        guard !OrderManager.shared.orders.isEmpty else {
            print("주문 내역이 없습니다.")
            return
        }
        
        // 결제 확인 Alert 표시
        let alert = UIAlertController(
            title: "결제 확인",
            message: "총 결제 금액: \(OrderManager.shared.totalAmount)원",
            preferredStyle: .alert
        )
        
        let confirmAction = UIAlertAction(title: "결제하기", style: .default) { _ in
            let totalAmount = OrderManager.shared.totalAmount
            print("결제 완료: \(totalAmount)원")
            
            OrderManager.shared.resetOrders()
            NotificationCenter.default.post(name: .orderUpdated, object: nil)
        }
        
        let cancelAction = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - Menu Selection Logic
extension MainViewController: MenuListViewDelegate {
    func menuListView(_ menuListView: MenuListView, didSelectMenu menu: (image: String, title: String, price: Int)) {
        let success = OrderManager.shared.addMenu(menu)
        if !success {
            let alert = UIAlertController(title: "경고", message: "주문 금액 한도는 1,000,000원 입니다.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "확인", style: .default, handler: nil)
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
        }

        NotificationCenter.default.post(name: .orderUpdated, object: nil)
        print("선택된 메뉴: \(menu.title), 가격: \(menu.price)")
    }
}


