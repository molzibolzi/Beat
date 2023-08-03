//
//  BeatDocumentViewController Extensions.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 7.7.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatCore

extension BeatDocumentViewController {
	@objc func setupTitleMenu() {
		let documentProperties = UIDocumentProperties(url: document.fileURL)
		if let itemProvider = NSItemProvider(contentsOf: document.fileURL) {
			documentProperties.dragItemsProvider = { _ in
				[UIDragItem(itemProvider: itemProvider)]
			}
			documentProperties.activityViewControllerProvider = {
				UIActivityViewController(activityItems: [itemProvider], applicationActivities: nil)
			}
		}
		
		navigationItem.documentProperties = documentProperties
	}
		
	@objc func setupScreenplayMenu(button:UIBarButtonItem) {
		button.menu = UIMenu(title: "Screenplay", identifier: nil, options: [], children: [
			UIAction(title: "Add title page", image: UIImage(systemName: "info"), handler: { (_) in
				self.formattingActions.addTitlePage(self)
			}),
			UIMenu(options: .displayInline, children: [
				UIAction(title: "Lock scene numbers", image: UIImage(systemName: "lock"), handler: { (_) in
					self.formattingActions.lockSceneNumbers(self)
				}),
				UIAction(title: "Remove locked scene numbers", image: UIImage(systemName: "lock.open"), handler: { (_) in
					self.formattingActions.unlockSceneNumbers(self)
				}),
			]),
			UIMenu(title:"Force element...", children: [
				UIAction(title: "Scene heading", handler: { (_) in
					self.formattingActions.forceHeading(self)
				}),
				UIAction(title: "Action", handler: { (_) in
					self.formattingActions.forceAction(self)
				}),
				UIAction(title: "Character", handler: { (_) in
					self.formattingActions.forceCharacter(self)
				}),
				UIAction(title: "Transition", handler: { (_) in
					self.formattingActions.forceTransition(self)
				}),
				UIAction(title: "Lyrics", handler: { (_) in
					self.formattingActions.forceLyrics(self)
				}),
			])
		])
		button.primaryAction = nil
	}
}