//
//  BeatTemplates.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 28.9.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

public struct BeatTemplateFile {
	var filename:String
	var title:String
	var description:String
	var icon:String?
	var url:URL?
}

/// Singleton class which provides templates
@objc public final class BeatTemplates:NSObject {
	var _allTemplates:[String:[BeatTemplateFile]]?
	
	private static var sharedTemplates:BeatTemplates = {
		return BeatTemplates()
	}()
	
	class public func shared() -> BeatTemplates {
		return sharedTemplates
	}
	
	/// Returns the full template data
	public func getTemplates() -> [String:[BeatTemplateFile]] {
		if _allTemplates != nil { return _allTemplates! }
		
		// get the plist file
		guard let url = Bundle.main.url(forResource: "Templates And Tutorials", withExtension: "plist") else { return [:] }
		do {
			// Get the template plist file
			let data = try Data(contentsOf: url)
			guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String:[[String:String]]] else { return [:] }
			
			var templateData:[String:[BeatTemplateFile]] = [:]
			
			for key in plist.keys {
				guard let templates = plist[key] else { continue }
				
				// Initialize array for different template types if needed
				if templateData[key] == nil { templateData[key] = [] }
				
				for template in templates {
					// First check if the file actually exists.
					let url = Bundle.main.url(forResource: template["filename"], withExtension: nil)
					if (url != nil) {
						// Add the localized template to array
						let t = BeatTemplateFile(filename: template["filename"] ?? "", title: BeatLocalization.localizedString(forKey: template["title"] ?? ""), description: BeatLocalization.localizedString(forKey: template["description"] ?? ""), icon: template["icon"] ?? "", url: url)
						templateData[key]?.append(t)
					}
				}
			}
		
			return templateData
			
		} catch {
			print("Template data could not be loaded.")
			return [:]
		}
	}
	
	public class func forFamily(_ family:String) -> [BeatTemplateFile] {
		return BeatTemplates.shared().forFamily(family)
	}
	public func forFamily(_ family:String) -> [BeatTemplateFile] {
		if _allTemplates == nil { _allTemplates = self.getTemplates() }
		
		return _allTemplates?[family] ?? []
	}
	
	public class func families() -> [String] {
		return BeatTemplates.shared().families()
	}
	public func families() -> [String] {
		let templates = getTemplates()
		let keys:[String] = templates.keys.map({ $0 })
		return keys
	}
}

#if os(macOS)

// MARK: - Menu provider and item for macOS

public final class BeatTemplateMenuProvider:NSObject, NSMenuDelegate {

	var items:[NSMenuItem] = []
	
	public func menuWillOpen(_ menu: NSMenu) {
		menu.items = templateItems()
	}
	
	func templateItems() -> [NSMenuItem] {
		if self.items.count > 0 {
			return self.items
		}
		
		let families = BeatTemplates.families()
		
		var items:[NSMenuItem] = []
		
		for f in families {
			let templates = BeatTemplates().forFamily(f)

			for template in templates {
				let item = BeatTemplateMenuItem(title: template.title, action: #selector(showTemplate), keyEquivalent: "")
				item.target = self
				item.template = template
				
				items.append(item)
			}
		}
		
		self.items = items
		return self.items
	}
	
	@objc public func showTemplate(sender:AnyObject?) {
		guard let item = sender as? BeatTemplateMenuItem else { return }
		
		guard let delegate = NSApp.delegate as? BeatAppDelegate,
			  let template = item.template
		else { return }
		
		delegate.showTemplate(template.filename)
	}
}

class BeatTemplateMenuItem:NSMenuItem {
	var template:BeatTemplateFile?
}

#endif
