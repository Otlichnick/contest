//
//  ActivityListCollectionController.swift
//  Tonkeeper
//
//  Created by Grigory on 6.6.23..
//

import UIKit

protocol ActivityListCollectionControllerDelegate: AnyObject {
  func activityListCollectionController(_ collectionController: ActivityListCollectionController,
                                        didSelectTransactionAt indexPath: IndexPath)
  func activityListCollectionControllerLoadNextPage(_ collectionController: ActivityListCollectionController)
  func activityListCollectionControllerEventViewModel(for eventId: String) -> ActivityListCompositionTransactionCell.Model?
  func activityListCollectionControllerDidPullToRefresh(_ collectionController: ActivityListCollectionController)
}

final class ActivityListCollectionController: NSObject {
  weak var delegate: ActivityListCollectionControllerDelegate?
  
  var headerView: UIView? {
    didSet {
      collectionView?.reloadData()
    }
  }
  
  private weak var collectionView: UICollectionView?
  private var dataSource: UICollectionViewDiffableDataSource<ActivityListSection, String>?
  private let collectionLayoutConfigurator = ActivityListCollectionLayoutConfigurator()
  private let imageLoader = NukeImageLoader()
  
  private var paginationSection: ActivityListSection?
  
  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    super.init()
    setupCollectionView()
  }
  
  func setSections(_ sections: [ActivityListSection]) {
    var snapshot = NSDiffableDataSourceSnapshot<ActivityListSection, String>()
    sections.forEach { section in
      snapshot.appendSections([section])
      switch section {
      case .events(let sectionData):
        snapshot.appendItems(sectionData.items, toSection: section)
      case .shimmer(let shimmers):
        snapshot.appendItems(shimmers, toSection: section)
      case .pagination:
        return
      }
    }
    dataSource?.apply(snapshot, animatingDifferences: false)
  }
  
  func showPagination(_ pagination: ActivityListSection.Pagination) {
    guard var snapshot = dataSource?.snapshot() else { return }
    if let paginationSection = paginationSection {
      snapshot.deleteSections([paginationSection])
    }
    let paginationSection = ActivityListSection.pagination(pagination)
    self.paginationSection = paginationSection
    snapshot.appendSections([paginationSection])
    dataSource?.apply(snapshot)
  }
  
  func hidePagination() {
    guard let paginationSection = paginationSection,
          var snapshot = dataSource?.snapshot() else { return }
    
    snapshot.deleteSections([paginationSection])
    dataSource?.apply(snapshot)
  }
}

private extension ActivityListCollectionController {
  func setupCollectionView() {
    guard let collectionView = collectionView else { return }
    let layout = collectionLayoutConfigurator.getLayout { [weak self] sectionIndex in
      guard let self = self, let snapshot = self.dataSource?.snapshot() else { return nil }
      return snapshot.sectionIdentifiers[sectionIndex]
    }
    collectionView.delegate = self
    collectionView.setCollectionViewLayout(layout, animated: false)
    collectionView.register(
      ActivityListCompositionTransactionCell.self,
      forCellWithReuseIdentifier: ActivityListCompositionTransactionCell.reuseIdentifier)
    collectionView.register(
      ActivityListShimmerCell.self,
      forCellWithReuseIdentifier: ActivityListShimmerCell.reuseIdentifier)
    collectionView.register(
      ActivityListSectionHeaderView.self,
      forSupplementaryViewOfKind: ActivityListSectionHeaderView.reuseIdentifier,
      withReuseIdentifier: ActivityListSectionHeaderView.reuseIdentifier)
    collectionView.register(
      ActivityListFooterView.self,
      forSupplementaryViewOfKind: ActivityListFooterView.reuseIdentifier,
      withReuseIdentifier: ActivityListFooterView.reuseIdentifier)
    collectionView.register(
      ActivityListShimmerSectionHeaderView.self,
      forSupplementaryViewOfKind: ActivityListShimmerSectionHeaderView.reuseIdentifier,
      withReuseIdentifier: ActivityListShimmerSectionHeaderView.reuseIdentifier)
    collectionView.register(
      ActivityListHeaderContainer.self,
      forSupplementaryViewOfKind: ActivityListHeaderContainer.reuseIdentifier,
      withReuseIdentifier: ActivityListHeaderContainer.reuseIdentifier
    )
    dataSource = createDataSource(collectionView: collectionView)
  }

  func createDataSource(collectionView: UICollectionView) -> UICollectionViewDiffableDataSource<ActivityListSection, String> {
    let dataSource = UICollectionViewDiffableDataSource<ActivityListSection, String>(collectionView: collectionView) { [weak self]
      collectionView, indexPath, itemIdentifier in
      guard let self = self,
            let cell = self.dequeueCell(collectionView: collectionView, indexPath: indexPath, itemIdentifier: itemIdentifier)
      else { return UICollectionViewCell() }
      return cell
    }
    
    dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath -> UICollectionReusableView? in
      guard let self = self else { return nil }
      return self.dequeueSupplementaryView(
        collectionView: collectionView,
        kind: kind,
        indexPath: indexPath)
    }
    
    return dataSource
  }
  
  func dequeueSupplementaryView(collectionView: UICollectionView,
                                kind: String,
                                indexPath: IndexPath) -> UICollectionReusableView? {
    if kind == ActivityListHeaderContainer.reuseIdentifier {
      return createHeaderView(collectionView: collectionView, kind: kind, indexPath: indexPath)
    }
    guard let snapshot = self.dataSource?.snapshot() else { return nil }
    let section = snapshot.sectionIdentifiers[indexPath.section]
    switch section {
    case .events(let sectionData):
      guard let headerView = collectionView
        .dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: ActivityListSectionHeaderView.reuseIdentifier,
          for: indexPath
        ) as? ActivityListSectionHeaderView else { return nil }
      headerView.configure(model: .init(date: sectionData.title))
      return headerView
    case .pagination(let pagination):
      guard let footerView = collectionView
        .dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: ActivityListFooterView.reuseIdentifier,
          for: indexPath
        ) as? ActivityListFooterView else { return nil }
      switch pagination {
      case .loading:
        footerView.state = .loading
      case .error(let title):
        footerView.state = .error(title: title)
      }
      footerView.didTapRetryButton = { [weak self] in
        guard let self = self else { return }
        self.delegate?.activityListCollectionControllerLoadNextPage(self)
      }
      return footerView
    case .shimmer:
      let headerView = collectionView.dequeueReusableSupplementaryView(
        ofKind: kind,
        withReuseIdentifier: ActivityListShimmerSectionHeaderView.reuseIdentifier,
        for: indexPath
      )
      (headerView as? ActivityListShimmerSectionHeaderView)?.startAnimation()
      return headerView
    }
  }
  
  func dequeueCell(collectionView: UICollectionView,
                   indexPath: IndexPath,
                   itemIdentifier: String) -> UICollectionViewCell? {
    guard let snapshot = dataSource?.snapshot() else { return nil }
    let section = snapshot.sectionIdentifiers[indexPath.section]
    switch section {
    case .events:
      guard let model = delegate?.activityListCollectionControllerEventViewModel(for: itemIdentifier) else { return UICollectionViewCell() }
      return getCompositionTransactionCell(collectionView: collectionView, indexPath: indexPath, model: model)
    case .shimmer:
      return getShimmerCell(collectionView: collectionView, indexPath: indexPath)
    case .pagination:
      return nil
    }
  }
  
  func getCompositionTransactionCell(collectionView: UICollectionView,
                                     indexPath: IndexPath,
                                     model: ActivityListCompositionTransactionCell.Model) -> UICollectionViewCell {
    guard let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: ActivityListCompositionTransactionCell.reuseIdentifier,
      for: indexPath) as? ActivityListCompositionTransactionCell else {
      return UICollectionViewCell()
    }
    
    cell.imageLoader = self.imageLoader
    cell.configure(model: model)
    return cell
  }
  
  func getShimmerCell(collectionView: UICollectionView,
                      indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: ActivityListShimmerCell.reuseIdentifier,
      for: indexPath
    )
    (cell as? ActivityListShimmerCell)?.startAnimation()
    return cell
  }
  
  func createHeaderView(collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView {
    let headerContainer = collectionView.dequeueReusableSupplementaryView(
      ofKind: kind,
      withReuseIdentifier: ActivityListHeaderContainer.reuseIdentifier,
      for: indexPath)
    if let headerContainer = headerContainer as? ActivityListHeaderContainer {
      headerContainer.setContentView(headerView)
    }
    return headerContainer
  }
  
  func fetchNextIfNeeded(collectionView: UICollectionView, indexPath: IndexPath) {
    let numberOfSections = collectionView.numberOfSections
    let numberOfItems = collectionView.numberOfItems(inSection: numberOfSections - 1)
    guard indexPath.item == numberOfItems - 1 else { return }
    delegate?.activityListCollectionControllerLoadNextPage(self)
  }
}

extension ActivityListCollectionController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    (collectionView.cellForItem(at: indexPath) as? Selectable)?.select()
    collectionView.deselectItem(at: indexPath, animated: true)
    delegate?.activityListCollectionController(self,
                                               didSelectTransactionAt: indexPath)
  }
  
  func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    (collectionView.cellForItem(at: indexPath) as? Selectable)?.deselect()
  }
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if scrollView.refreshControl?.isRefreshing == true {
      delegate?.activityListCollectionControllerDidPullToRefresh(self)
    }
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      willDisplay cell: UICollectionViewCell,
                      forItemAt indexPath: IndexPath) {
    fetchNextIfNeeded(collectionView: collectionView, indexPath: indexPath)
  }
}
