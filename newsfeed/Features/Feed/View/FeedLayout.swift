//
//  FeedLayout.swift
//  newsfeed
//

import UIKit

enum FeedLayout {

    static func make(containerWidth: CGFloat, trait: UITraitCollection) -> UICollectionViewCompositionalLayout {
        let isRegularWidth = trait.horizontalSizeClass == .regular
        let isPhone = trait.userInterfaceIdiom == .phone

        // Количество колонок
        let columns: Int = {
            if isRegularWidth && containerWidth >= 980 { return 3 }
            if isRegularWidth && containerWidth >= 680 { return 2 }
            if containerWidth >= 750 { return 2 } // крупные iPhone в landscape
            return 1
        }()

        let interItem: CGFloat = 12

        // Убираем боковые отступы на iPhone
        let sectionInsets = NSDirectionalEdgeInsets(
            top: 8,
            leading: isPhone ? 0 : 16,
            bottom: 8,
            trailing: isPhone ? 0 : 16
        )

        let layout = UICollectionViewCompositionalLayout { _, _ in

            let item = NSCollectionLayoutItem(
                layoutSize: .init(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: (columns == 1) ? .estimated(400) : .fractionalHeight(1.0)
                )
            )

            let section: NSCollectionLayoutSection

            if columns == 1 {
                // Одна колонка
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: .init(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(400)
                    ),
                    subitems: [item]
                )
                let s = NSCollectionLayoutSection(group: group)
                s.interGroupSpacing = interItem
                s.contentInsets = sectionInsets
                section = s
            } else {
                // Несколько колонок
                let colWidth = columnWidth(
                    containerWidth: containerWidth,
                    sectionInsets: sectionInsets,
                    interItem: interItem,
                    columns: columns
                )
                let imageHeight = floor(colWidth * (2.0/3.0)) // ratio 2:3
                let rowHeight = imageHeight + textBlockHeight

                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: .init(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(rowHeight)
                    ),
                    subitem: item,
                    count: columns
                )
                group.interItemSpacing = .fixed(interItem)

                let s = NSCollectionLayoutSection(group: group)
                s.interGroupSpacing = interItem
                s.contentInsets = sectionInsets
                section = s
            }

            return section
        }

        return layout
    }

    private static func columnWidth(containerWidth: CGFloat,
                                    sectionInsets: NSDirectionalEdgeInsets,
                                    interItem: CGFloat,
                                    columns: Int) -> CGFloat {
        let totalHInsets = sectionInsets.leading + sectionInsets.trailing
        let totalInter = interItem * CGFloat(max(columns - 1, 0))
        let contentWidth = containerWidth - totalHInsets - totalInter
        return max(1, contentWidth / CGFloat(columns))
    }

    /// Приблизительная высота текстового блока (ограниченные строки + отступы).
    static var textBlockHeight: CGFloat {
        let title  = UIFont.boldSystemFont(ofSize: 17).lineHeight * 2
        let date   = UIFont.systemFont(ofSize: 13).lineHeight * 1
        let desc   = UIFont.systemFont(ofSize: 15).lineHeight * 3
        let button = UIFont.boldSystemFont(ofSize: 15).lineHeight * 1

        let top: CGFloat = 12
        let between1: CGFloat = 8
        let between2: CGFloat = 8
        let bottom: CGFloat = 12

        let categoryMin: CGFloat = 24 + 12 + 12
        let padding: CGFloat = 6

        return top + title + date + between1 + desc + between2 + button + bottom + categoryMin + padding
    }
}
