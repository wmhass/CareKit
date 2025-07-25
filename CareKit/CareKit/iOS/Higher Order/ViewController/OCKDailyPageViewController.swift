/*
 Copyright (c) 2016-2025, Apple Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3. Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#if !os(watchOS)

import CareKitStore
import CareKitUI
import UIKit

/// A protocol that provides callbacks when important events occur in a page view controller.
public protocol OCKDailyPageViewControllerDelegate: AnyObject {
    /// This method will be called anytime an unhandled error is encountered.
    ///
    /// - Parameters:
    ///   - dailyPageViewController: The daily page view controller in which the error occurred.
    ///   - error: The error that occurred
    func dailyPageViewController(_ dailyPageViewController: OCKDailyPageViewController, didFailWithError error: Error)
}

public extension OCKDailyPageViewControllerDelegate {
    /// This method will be called anytime an unhandled error is encountered.
    ///
    /// - Parameters:
    ///   - dailyPageViewController: The daily page view controller in which the error occurred.
    ///   - error: The error that occurred
    func dailyPageViewController(_ dailyPageViewController: OCKDailyPageViewController, didFailWithError error: Error) {}
}

/// A protocol for classes that provides content to a page view controller.
public protocol OCKDailyPageViewControllerDataSource: AnyObject {
    /// - Parameters:
    ///   - dailyPageViewController: The daily page view controller for which content should be provided.
    ///   - listViewController: The list view controller that should be populated with content.
    ///   - date: A date that should be used to determine what content to insert into the list view controller.
    func dailyPageViewController(_ dailyPageViewController: OCKDailyPageViewController,
                                 prepare listViewController: OCKListViewController, for date: Date)
}

/// A view controller that displays a calendar page view controller in the header and a view controller in the body.
///
/// Manually query these view controllers and set them from outside of the class.
open class OCKDailyPageViewController: UIViewController,
OCKDailyPageViewControllerDataSource, OCKDailyPageViewControllerDelegate, OCKWeekCalendarPageViewControllerDelegate,
UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    // MARK: Properties

    public weak var dataSource: OCKDailyPageViewControllerDataSource?
    public weak var delegate: OCKDailyPageViewControllerDelegate?

    public var selectedDate: Date {
        return weekCalendarPageViewController.selectedDate
    }

    /// The store manager the view controller uses for synchronization.
    @available(*, unavailable, renamed: "store")
    public var storeManager: OCKSynchronizedStoreManager! {
        fatalError("Property is unavailable")
    }

    /// The store the view controller uses for synchronization.
    public let store: OCKAnyStoreProtocol

    /// Page view managing ListViewControllers.
    private let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)

    /// The calendar view controller in the header.
    private let weekCalendarPageViewController: OCKWeekCalendarPageViewController

    // MARK: - Life cycle

    /// Create an instance of the view controller. Will hook up the calendar to the tasks collection,
    /// and query and display the tasks.
    ///
    /// - Parameter storeManager: The store from which to query the tasks.
    /// - Parameter adherenceAggregator: An aggregator that will be used to compute the adherence values shown at the top of the view.
    @available(*, unavailable, renamed: "init(store:computeProgress:)")
    public convenience init(
        storeManager: OCKSynchronizedStoreManager,
        adherenceAggregator: OCKAdherenceAggregator = .compareTargetValues
    ) {
        fatalError("Unavailable")
    }

    /// Create an instance of the view controller. Will hook up the calendar to the tasks collection,
    /// and query and display the tasks.
    ///
    /// - Parameter store: The store from which to query the tasks.
    /// - Parameter computeProgress: Used to compute the combined progress for a series of CareKit events.
    public init(
        store: OCKAnyStoreProtocol,
        computeProgress: @escaping (OCKAnyEvent) -> CareTaskProgress = { event in
            event.computeProgress(by: .checkingOutcomeExists)
        }
    ) {
        self.store = store

        self.weekCalendarPageViewController = OCKWeekCalendarPageViewController(
            store: store,
            computeProgress: computeProgress
        )

        super.init(nibName: nil, bundle: nil)

        self.weekCalendarPageViewController.dataSource = self
        self.pageViewController.dataSource = self
        self.pageViewController.delegate = self
        self.dataSource = self
        self.delegate = self
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The page that is currently being displayed.
    open var currentPage: OCKListViewController? {
        pageViewController.viewControllers?.first as? OCKListViewController
    }

    /// Reload the contents at the currently selected date.
    open func reload() {
        guard let current = currentPage else {
            return
        }
        preparePage(current, date: selectedDate)
    }

    /// Selects the given date, updating both the calendar view and the daily content.
    ///
    /// - Parameters:
    ///   - date: The date to be selected.
    ///   - animated: A flag that determines if the selection will be animated or not.
    open func selectDate(_ date: Date, animated: Bool) {
        guard !Calendar.current.isDate(selectedDate, inSameDayAs: date) else { return }

        // Load the page of tasks for the new date. This must be done before selecting the date in the calendar so that
        // the `selectedDate` is correct.
        showPage(forDate: date, previousDate: selectedDate, animated: animated)

        // Select the correct ring in the calendar
        weekCalendarPageViewController.selectDate(date, animated: animated)
    }

    override open func viewSafeAreaInsetsDidChange() {
        updateScrollViewInsets()
    }

    override open func loadView() {
        [weekCalendarPageViewController, pageViewController].forEach { addChild($0) }
        view = OCKHeaderBodyView(headerView: weekCalendarPageViewController.view, bodyView: pageViewController.view)
        [weekCalendarPageViewController, pageViewController].forEach { $0.didMove(toParent: self) }
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        let now = Date()
        weekCalendarPageViewController.calendarDelegate = self
        weekCalendarPageViewController.selectDate(now, animated: false)
        pageViewController.setViewControllers([makePage(date: now)], direction: .forward, animated: false, completion: nil)
        pageViewController.accessibilityHint = loc("THREE_FINGER_SWIPE_DAY")
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: loc("TODAY"), style: .plain, target: self, action: #selector(pressedToday(sender:)))
    }

    private func makePage(date: Date) -> OCKDatedListViewController {
        let listViewController = OCKDatedListViewController(date: date)

        let refresher = UIRefreshControl()
        refresher.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        listViewController.listView.scrollView.refreshControl = refresher

        preparePage(listViewController, date: date)
        return listViewController
    }

    private func preparePage(_ list: OCKListViewController, date: Date) {
        list.clear()

        let dateLabel = OCKDateLabel(textStyle: .title2, weight: .bold)
        dateLabel.setDate(date)
        dateLabel.accessibilityTraits = .header
        list.insertView(dateLabel, at: 0, animated: false)

        setInsets(for: list)
        dataSource?.dailyPageViewController(self, prepare: list, for: date)
    }

    @objc
    private func handleRefresh(_ control: UIRefreshControl) {
        control.endRefreshing()
        reload()
    }

    @objc
    private func pressedToday(sender: UIBarButtonItem) {
        selectDate(Date(), animated: true)
    }

    private func updateScrollViewInsets() {
        pageViewController.viewControllers?.forEach({ child in
            guard let listVC = child as? OCKListViewController else { fatalError("Unexpected type") }
            setInsets(for: listVC)
        })
    }

    private func setInsets(for listViewController: OCKListViewController) {
        guard let listView = listViewController.view as? OCKListView else { fatalError("Unexpected type") }
        guard let headerView = view as? OCKHeaderBodyView else { fatalError("Unexpected type") }
        let insets = UIEdgeInsets(top: headerView.headerInset, left: 0, bottom: OCKHeaderBodyView.Constants.margin, right: 0)
        listView.scrollView.contentInset = insets
        listView.scrollView.scrollIndicatorInsets = UIEdgeInsets(top: headerView.headerHeight, left: 0, bottom: 0, right: 0)
    }

    /// Show the page for a particular date.
    private func showPage(forDate date: Date, previousDate: Date, animated: Bool) {
        let moveLeft = date < previousDate
        let listViewController = makePage(date: date)
        pageViewController.setViewControllers([listViewController], direction: moveLeft ? .reverse : .forward, animated: animated, completion: nil)
    }

    // MARK: - OCKCalendarPageViewControllerDelegate

    public func weekCalendarPageViewController(_ viewController: OCKWeekCalendarPageViewController, didSelectDate date: Date, previousDate: Date) {
        showPage(forDate: date, previousDate: previousDate, animated: true)
    }

    public func weekCalendarPageViewController(_ viewController: OCKWeekCalendarPageViewController, didChangeDateInterval interval: DateInterval) {}

    public func weekCalendarPageViewController(_ viewController: OCKWeekCalendarPageViewController, didEncounterError error: Error) {
        if delegate == nil {
            log(.error, "An error occurred in the calendar, but no delegate was set to forward it to!", error: error)
        }
        delegate?.dailyPageViewController(self, didFailWithError: error)
    }

    // MARK: OCKDailyPageViewControllerDataSource & Delegate

    open func dailyPageViewController(_ dailyPageViewController: OCKDailyPageViewController,
                                      prepare listViewController: OCKListViewController, for date: Date) {}

    open func dailyPageViewController(_ dailyPageViewController: OCKDailyPageViewController, didFailWithError error: Error) {}

    // MARK: - UIPageViewControllerDelegate

    open func pageViewController(_ pageViewController: UIPageViewController,
                                 viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentViewController = viewController as? OCKDatedListViewController else { fatalError("Unexpected type") }
        let targetDate = Calendar.current.date(byAdding: .day, value: -1, to: currentViewController.date)!
        return makePage(date: targetDate)
    }

    open func pageViewController(_ pageViewController: UIPageViewController,
                                 viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentViewController = viewController as? OCKDatedListViewController else { fatalError("Unexpected type") }
        let targetDate = Calendar.current.date(byAdding: .day, value: 1, to: currentViewController.date)!
        return makePage(date: targetDate)
    }

    // MARK: - UIPageViewControllerDataSource

    open func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                 previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed else { return }
        guard let listViewController = pageViewController.viewControllers?.first as? OCKDatedListViewController else { fatalError("Unexpected type") }
        weekCalendarPageViewController.selectDate(listViewController.date, animated: true)
    }
}

// This is private subclass of the list view controller that imbues it with a date that can be used by the page view controller to determine
// which direction was just swiped.
private class OCKDatedListViewController: OCKListViewController {
    let date: Date

    init(date: Date) {
        self.date = date
        super.init(nibName: nil, bundle: nil)
//        listView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class OCKDateLabel: OCKLabel {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    func setDate(_ date: Date) {
        text = OCKDateLabel.dateFormatter.string(from: date)
    }

    override init(textStyle: UIFont.TextStyle, weight: UIFont.Weight) {
        super.init(textStyle: textStyle, weight: weight)
        styleDidChange()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func styleDidChange() {
        super.styleDidChange()
        textColor = style().color.label
    }
}

extension OCKDailyPageViewController {
    open func reloadAllPages() {
        pageViewController.setViewControllers(
            [makePage(date: weekCalendarPageViewController.selectedDate)],
            direction: .forward,
            animated: false,
            completion: nil
        )
    }
}

#endif
