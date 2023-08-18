//
//  TonChartTonChartPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 15/08/2023.
//

import UIKit
import WalletCore
import DGCharts

final class TonChartPresenter {
  
  // MARK: - Module
  
  weak var viewInput: TonChartViewInput?
  weak var output: TonChartModuleOutput?
  
  // MARK: - Dependencies
  
  private let chartController: ChartController
  
  // MARK: - State
  
  private var selectedPeriod: ChartController.Period = .week
  private var reloadTask: Task<Void, Error>?
  
  init(chartController: ChartController) {
    self.chartController = chartController
  }
}

// MARK: - TonChartPresenterIntput

extension TonChartPresenter: TonChartPresenterInput {
  func viewDidLoad() {
    setupButtons()
    reloadChartDataAndHeader()
  }
  
  func didSelectButton(at index: Int) {
    viewInput?.selectButton(at: index)
    selectedPeriod = ChartController.Period.allCases[index]
    reloadChartDataAndHeader()
  }
  
  func didSelectChartValue(at index: Int) {
    Task {
      await showSelectedHeader(index: index)
    }
  }
  
  func didDeselectChartValue() {
    Task {
      await showUnselectedHeader()
    }
  }
}

// MARK: - TonChartModuleInput

extension TonChartPresenter: TonChartModuleInput {
  func reload() {
    Task {
      reloadChartDataAndHeader()
    }
  }
}

// MARK: - Private

private extension TonChartPresenter {
  func setupButtons() {
    let buttons = ChartController.Period.allCases.map {
      TKButton.Model(title: $0.title)
    }
    let model = TonChartButtonsView.Model(buttons: buttons)
    viewInput?.updateButtons(with: model)
    viewInput?.selectButton(at: ChartController.Period.allCases.firstIndex(of: selectedPeriod) ?? 0)
  }
  
  func reloadChartDataAndHeader() {
    Task {
      do {
        try await reloadChartData()
        await showUnselectedHeader()
      } catch {
        await MainActor.run {
          showError(error: error)
          showErrorHeader()
        }
      }
    }
  }
  
  func reloadChartData() async throws {
    let coordinates = try await chartController.getChartData(period: selectedPeriod)
    let chartData = prepareChartData(coordinates: coordinates, period: selectedPeriod)
    await MainActor.run {
      viewInput?.updateChart(with: chartData)
    }
  }
  
  func showUnselectedHeader() async {
    guard await !chartController.coordinates.isEmpty else { return }
    let pointInformation = await chartController.getInformation(at: chartController.coordinates.count - 1, period: selectedPeriod)
    let headerModel = prepareHeaderModel(pointInformation: pointInformation, date: "Price")
    await MainActor.run {
      viewInput?.updateHeader(with: headerModel)
    }
  }
  
  func showSelectedHeader(index: Int) async {
    let pointInformation = await chartController.getInformation(at: index, period: selectedPeriod)
    let headerModel = prepareHeaderModel(pointInformation: pointInformation, date: pointInformation.date)
    await MainActor.run {
      viewInput?.updateHeader(with: headerModel)
    }
  }

  func prepareChartData(coordinates: [Coordinate],
                        period: ChartController.Period) -> LineChartData {
    let chartEntries = coordinates.map { coordinate in
      ChartDataEntry(x: coordinate.x, y: coordinate.y)
    }

    let gradient = CGGradient.with(
      easing: Cubic.easeIn,
      between: UIColor.Background.page,
      and: UIColor.Accent.blue)

    let dataSet = LineChartDataSet(entries: chartEntries)
    dataSet.circleRadius = 0
    dataSet.setColor(.Accent.blue)
    dataSet.drawValuesEnabled = false
    dataSet.lineWidth = 2
    dataSet.fillAlpha = 1
    dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
    dataSet.drawFilledEnabled = true
    dataSet.drawHorizontalHighlightIndicatorEnabled = false
    dataSet.highlightColor = .Accent.blue
    dataSet.highlightLineWidth = 1

    switch period {
    case .hour:
      dataSet.mode = .stepped
    default:
      dataSet.mode = .linear
    }

    return LineChartData(dataSet: dataSet)
  }

  func prepareHeaderModel(pointInformation: ChartPointInformationViewModel,
                          date: String) -> TonChartHeaderView.Model {
    let amount = pointInformation.amount.attributed(
      with: .amountTextStyle,
      color: .Text.primary
    )

    let date = date.attributed(
      with: .otherTextStyle,
      color: .Text.secondary
    )

    let diffColor: UIColor
    switch pointInformation.diff.direction {
    case .down: diffColor = .Accent.red
    case .none: diffColor = .Text.secondary
    case .up: diffColor = .Accent.green
    }

    let percentDiff = pointInformation
        .diff
        .percent
        .attributed(
          with: .otherTextStyle,
          color: diffColor)
    let fiatDiff = pointInformation
        .diff
        .fiat
        .attributed(
          with: .otherTextStyle,
          color: diffColor.withAlphaComponent(0.44))

      return .init(amount: amount, percentDiff: percentDiff, fiatDiff: fiatDiff, date: date)
  }

  func showError(error: Error) {
    let title: String
    let subtitle: String
    if error.isNoConnectionError {
      title = "No internet connection"
      subtitle = "Please check your connection and try again."
    } else {
      title = "Failed to load chart data"
      subtitle = "Please try again"
    }
    let model = TonChartErrorView.Model(
      title: title,
      subtitle: subtitle
    )
    viewInput?.showError(with: model)
  }

  func showErrorHeader() {
    let amount = "0".attributed(
      with: .amountTextStyle,
      color: .Text.primary
    )

    let date = "Price".attributed(
      with: .otherTextStyle,
      color: .Text.secondary
    )

    let percentDiff = "0%"
        .attributed(
          with: .otherTextStyle,
          color: .Text.secondary)
    let fiatDiff = "0,00"
        .attributed(
          with: .otherTextStyle,
          color: .Text.secondary.withAlphaComponent(0.44))


    let headerModel = TonChartHeaderView.Model.init(amount: amount, percentDiff: percentDiff, fiatDiff: fiatDiff, date: date)
    viewInput?.updateHeader(with: headerModel)
  }
}

private extension TextStyle {
  static var amountTextStyle: TextStyle {
    TextStyle(font: .monospacedSystemFont(ofSize: 20, weight: .bold),
                    lineHeight: 28)
  }
  
  static var otherTextStyle: TextStyle {
    TextStyle(font: .monospacedSystemFont(ofSize: 14, weight: .medium),
                    lineHeight: 20)
  }
}
