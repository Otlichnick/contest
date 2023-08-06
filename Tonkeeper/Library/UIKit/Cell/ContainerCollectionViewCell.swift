//
//  ContainerCollectionViewCell.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

protocol ContainerCollectionViewCellContent: ConfigurableView {
  func prepareForReuse()
}

class ContainerCollectionViewCell<CellContentView: ContainerCollectionViewCellContent>: UICollectionViewCell, ConfigurableView, Selectable {

  let cellContentView = CellContentView()
  
  override var isHighlighted: Bool {
    didSet {
      updateHighlightApperance()
    }
  }
  
  override var isSelected: Bool {
    didSet {
      updateHighlightApperance()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: CellContentView.Model) {
    cellContentView.configure(model: model)
  }
  
  override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
    let cellContentViewSize = cellContentView.sizeThatFits(.init(width: targetSize.width, height: 0))
    let modifiedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
    modifiedAttributes.frame.size = cellContentViewSize
    return modifiedAttributes
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    cellContentView.frame = contentView.bounds
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    cellContentView.prepareForReuse()
    deselect()
  }
  
  func updateHighlightApperance() {
    let isHighlighted = isSelected || isHighlighted
    isHighlighted ? select() : deselect()
  }
  
  func select() {
    let color = UIColor.clear
    contentView.backgroundColor = color
  }
  
  func deselect() {
    let color = UIColor.Background.content
    contentView.backgroundColor = color
  }
}

private extension ContainerCollectionViewCell {
  func setup() {
    contentView.backgroundColor = .Background.content
    contentView.addSubview(cellContentView)
    
    let selectedView = UIView()
    selectedView.backgroundColor = .Background.highlighted
    selectedBackgroundView = selectedView
  }
}
