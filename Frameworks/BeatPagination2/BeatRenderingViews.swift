//
//  BeatRenderingViews.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

import BeatCore
//import BeatPagination2
import UXKit

// MARK: - Basic page view for rendering the screenplay

@objc public class BeatPagePrintView:UXView {
    #if os(macOS)
        override public var isFlipped: Bool { return true }
    #endif
	weak public var previewController:BeatPreviewManager?
}

@objc open class BeatPaginationPageView:UXView {
    #if os(macOS)
        override public var isFlipped: Bool { return true }
    #endif
	weak public var previewController:BeatPreviewManager?
	
	public var attributedString:NSAttributedString?
    public var page:BeatPaginationPage?
    public var textView:BeatPageTextView?
    
    var pageStyle:RenderStyle
    var settings:BeatExportSettings
    
	var linePadding = 0.0
	var size:CGSize
	
	var fonts = BeatFonts.shared()
	
	var paperSize:BeatPaperSize
	var isTitlePage = false
	
	@objc public init(page:BeatPaginationPage?, content:NSAttributedString?, settings:BeatExportSettings, previewController: BeatPreviewManager?, titlePage:Bool = false) {
		self.size = BeatPaperSizing.size(for: settings.paperSize)

		self.attributedString = content
		self.previewController = previewController
		self.settings = settings
		self.paperSize = settings.paperSize
				
		self.page = page
		if (page != nil) {
			self.attributedString = page!.attributedString()
		} else {
			self.attributedString = content
		}
		
		let styles = self.settings.styles as? BeatStylesheet
		self.pageStyle = styles?.page() ?? RenderStyle(rules: [:])
		
		super.init(frame: CGRectMake(0, 0, size.width, size.height))
		
        #if os(macOS)
		self.canDrawConcurrently = true
		self.wantsLayer = true
		self.layer?.backgroundColor = .white
		
		// Force light appearance to get highlights show up correctly
		self.appearance = NSAppearance(named: .aqua)
        #else
        self.backgroundColor = .white
        #endif
		
		// Create text views and set attributed string
		createTextView()
        if let textStorage = self.textView?.textStorage {
            textStorage.setAttributedString(self.attributedString ?? NSAttributedString(string: ""))
        }
	}
	
	@objc func setContent(attributedString:NSAttributedString, settings:BeatExportSettings) {
        guard let textStorage = self.textView?.textStorage else { return }
		textStorage.setAttributedString(attributedString)
	}
	
	func createTextView() {
		self.textView = BeatPageTextView(frame: self.textViewFrame())
		
		self.textView?.previewController = self.previewController
		
		self.textView?.isEditable = false
        textView?.backgroundColor = .white

        #if os(macOS)
            self.textView?.linkTextAttributes = [
                NSAttributedString.Key.font: fonts.regular,
                NSAttributedString.Key.cursor: NSCursor.pointingHand
            ]
        #else
            self.textView?.linkTextAttributes = [NSAttributedString.Key.font: fonts.regular]
        #endif
        
        #if os(macOS)
            self.textView?.displaysLinkToolTips = false
            self.textView?.isAutomaticLinkDetectionEnabled = false
            self.textView?.textContainer?.lineFragmentPadding = linePadding
            self.textView?.textContainerInset = NSSize(width: 0, height: 0)
            self.textView?.drawsBackground = true
        #endif
		        
		self.textView?.font = fonts.regular
				
		let layoutManager = BeatRenderLayoutManager()
		layoutManager.pageView = self
		
        // We have to have a conditional check here because of differing optionality on macOS/iOS
        if let textContainer = self.textView?.textContainer {
            textContainer.replaceLayoutManager(layoutManager)
            textContainer.lineFragmentPadding = linePadding
        }
				
		self.addSubview(textView!)
	}
	
	func textViewFrame() -> CGRect {
		let size = BeatPaperSizing.size(for: settings.paperSize)
		let marginOffset = (settings.paperSize == .A4) ? pageStyle.marginLeftA4 : pageStyle.marginLeftLetter
		
		let textFrame = CGRect(x: self.pageStyle.marginLeft - linePadding + marginOffset,
							   y: self.pageStyle.marginTop,
							   width: size.width - self.pageStyle.marginLeft - self.pageStyle.marginRight,
							   height: size.height - self.pageStyle.marginTop)
		
		return textFrame
	}
	
	func updateContainerSize() {
		paperSize = settings.paperSize
		self.textView?.frame = self.textViewFrame()
	}
	
	// Update content
	public func update(page:BeatPaginationPage, settings:BeatExportSettings) {
		self.settings = settings
		self.page = page
		
		// Update container frame if paper size has changed
		if (self.settings.paperSize != self.paperSize) {
			updateContainerSize()
			page.invalidateRender()
		}
        if let textStorage = self.textView?.textStorage {
            textStorage.setAttributedString(page.attributedString())
        }
	}
	
    #if os(macOS)
	override public func cancelOperation(_ sender: Any?) {
		superview?.cancelOperation(sender)
	}
    #endif
	
	required public init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Custom text view

@objc open class BeatPageTextView:UXTextView {
	weak var previewController:BeatPreviewManager?
	
#if os(macOS)
	/// The user clicked on a link, which direct to `Line` objects
	override public func clicked(onLink link: Any, at charIndex: Int) {
		guard
			let line = link as? Line,
			let previewController = self.previewController
		else { return }
		
		previewController.closeAndJumpToRange(line.textRange())
	}
	
	override public func cancelOperation(_ sender: Any?) {
		superview?.cancelOperation(sender)
	}
#endif
}


// MARK: - Title page

@objc public class BeatTitlePageView:BeatPaginationPageView {
	var leftColumn:UXTextView?
	var rightColumn:UXTextView?
	var titlePageLines:[[String:[Line]]]
	
	@objc public init(previewController: BeatPreviewManager? = nil, titlePage:[[String:[Line]]], settings:BeatExportSettings) {
		self.titlePageLines = titlePage
		super.init(page: nil, content: NSMutableAttributedString(string: ""), settings: settings, previewController: previewController, titlePage: true)
			
		createViews()
		createTitlePage()
		
		isTitlePage = true
	}
		
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	/// Creates title page content and places the text snippets into correct spots
	public func createTitlePage() {

		guard let leftColumn = self.leftColumn,
			  let rightColumn = self.rightColumn,
			  let textView = self.textView,
              let textStorage = self.textView?.textStorage,
              let leftTextStorage = self.leftColumn?.textStorage,
              let rightTextStorage = self.rightColumn?.textStorage
		else {
			print("ERROR: No text views found, returning empty page")
			return
		}
		
		textView.string = "\n" // Add one extra line break to make title top margin have effect
		leftColumn.string = ""
		rightColumn.string = ""
        
        let renderer = BeatRenderer(settings: self.settings)
		
		var top:[Line] = []
		
		if let title = titlePageElement("title") { top.append(contentsOf: title) }
		if let credit = titlePageElement("credit") { top.append(contentsOf: credit) }
		if let authors = titlePageElement("authors") { top.append(contentsOf: authors) }
		if let source = titlePageElement("source") { top.append(contentsOf: source) }
		
		// Title, credit, author, source on top
		let topContent = NSMutableAttributedString(string: "")
		for el in top {
			let attrStr = renderer.renderLine(el, of: nil, dualDialogueElement: false, firstElementOnPage: false)
			
			topContent.append(attrStr)
		}
		textStorage.append(topContent)
		
		// Draft date on right side
		if let draftDate = titlePageElement("draft date") {
			let attrStr = NSMutableAttributedString()
			_ = draftDate.map { attrStr.append(renderer.renderLine($0)) }
			rightTextStorage.append(attrStr)
		}
		
		if let contact = titlePageElement("contact") {
			let attrStr = NSMutableAttributedString()
			_ = contact.map { attrStr.append(renderer.renderLine($0)) }
			leftTextStorage.append(attrStr)
		}
				
		// Add the rest of the elements on left side
		for d in self.titlePageLines {
			let dict = d
			
			if let element = titlePageElement(dict.keys.first ?? "") {
				let attrStr = NSMutableAttributedString()
				_ = element.map { attrStr.append(renderer.renderLine($0)) }
				leftTextStorage.append(attrStr)
			}
		}
		
		// Remove backgrounds
        #if os(macOS)
		leftColumn.drawsBackground = false
		rightColumn.drawsBackground = false
		textView.drawsBackground = false
        #endif
		
		// Layout manager doesn't handle newlines too well, so let's trim the column content
		leftTextStorage.setAttributedString(leftTextStorage.trimmedAttributedString(set: .newlines))
		rightTextStorage.setAttributedString(rightTextStorage.trimmedAttributedString(set: .newlines))

		// Once we've set the content, let's adjust top inset to align text to bottom
        #if os(macOS)
            leftColumn.textContainerInset = CGSize(width: 0, height: 0)
            rightColumn.textContainerInset = CGSize(width: 0, height: 0)
        #else
            leftColumn.textContainerInset = UIEdgeInsets.zero
            rightColumn.textContainerInset = UIEdgeInsets.zero
        #endif
		
        #if os(macOS)
            _ = leftColumn.layoutManager!.glyphRange(for: leftColumn.textContainer!)
            _ = rightColumn.layoutManager!.glyphRange(for: rightColumn.textContainer!)
            let leftRect = leftColumn.layoutManager!.usedRect(for: leftColumn.textContainer!)
            let rightRect = rightColumn.layoutManager!.usedRect(for: rightColumn.textContainer!)
        #else
            _ = leftColumn.layoutManager.glyphRange(for: leftColumn.textContainer)
            _ = rightColumn.layoutManager.glyphRange(for: rightColumn.textContainer)
            let leftRect = leftColumn.layoutManager.usedRect(for: leftColumn.textContainer)
            let rightRect = rightColumn.layoutManager.usedRect(for: rightColumn.textContainer)
        #endif
				
		// We'll calculate correct insets for the boxes, so the content will be bottom-aligned
		let insetLeft = leftColumn.frame.height - leftRect.height
		let insetRight = rightColumn.frame.height - rightRect.height
		
        #if os(macOS)
            leftColumn.textContainerInset = CGSize(width: 0, height: insetLeft)
            rightColumn.textContainerInset = CGSize(width: 0, height: insetRight)
        #else
            leftColumn.textContainerInset = UIEdgeInsets(top: insetLeft, left: 0.0, bottom: 0.0, right: 0.0)
            rightColumn.textContainerInset = UIEdgeInsets(top: insetRight, left: 0.0, bottom: 0.0, right: 0.0)
        #endif
	}
	
	/// Gets **and removes** a title page element from title page array. The array looks like `[ [key: value], [key: value], ...]` to keep the title page elements organized.
	func titlePageElement(_ key:String) -> [Line]? {
		var lines:[Line] = []

		for i in 0..<titlePageLines.count {
			let dict = titlePageLines[i]
			
			if (dict[key] != nil) {
				lines = dict[key] ?? []
				titlePageLines.remove(at: i)
				break
			}
		}
		
		// No title page element was found, return nil
		if lines.count == 0 { return nil }
	
		var type:LineType = .empty
		switch key {
			case "title":
				type = .titlePageTitle
			case "authors":
				type = .titlePageAuthor
			case "credit":
				type = .titlePageCredit
			case "source":
				type = . titlePageSource
			case "draft date":
				type = .titlePageDraftDate
			case "contact":
				type = .titlePageContact
			default:
				type = .titlePageUnknown
		}
		
		var elementLines:[Line] = []
				
		for i in 0..<lines.count {
			let l = lines[i]
			l.type = type
			elementLines.append(l)
		}
				
		return elementLines
	}
	
	/// Updates title page content 
	@objc public func updateTitlePage(_ titlePageContent: [[String:[Line]]]) {
		self.titlePageLines = titlePageContent
		createTitlePage()
	}
	
	/// Override page render method for title pages
	func createViews() {
		let frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
		let textViewFrame = CGRect(x: pageStyle.marginLeft,
								   y: pageStyle.marginTop,
								   width: frame.size.width - pageStyle.marginLeft * 2,
								   height: 400)
		textView?.frame = frame
		
		let columnFrame = CGRect(x: pageStyle.marginLeft,
								 y: textViewFrame.origin.y + textViewFrame.height,
								 width: textViewFrame.width / 2 - 10,
								 height: frame.height - textViewFrame.size.height - pageStyle.marginBottom - BeatPagination.lineHeight() * 2)
		
		if (leftColumn == nil) {
			leftColumn = UXTextView(frame: columnFrame)
			leftColumn?.isEditable = false
            #if os(macOS)
            leftColumn?.drawsBackground = false
            #else
            leftColumn?.backgroundColor = .clear
            #endif
			
			leftColumn?.isSelectable = false
			
			self.addSubview(leftColumn!)
		}

		if (rightColumn == nil) {
			let rightColumnFrame = CGRect(x: frame.width - pageStyle.marginLeft - columnFrame.width,
										  y: columnFrame.origin.y, width: columnFrame.width, height: columnFrame.height)
			
			rightColumn = UXTextView(frame: rightColumnFrame)
			rightColumn?.isEditable = false
            #if os(macOS)
			rightColumn?.drawsBackground = false
            #else
            rightColumn?.backgroundColor = .clear
            #endif
			
			rightColumn?.isSelectable = false
			
			self.addSubview(rightColumn!)
		}
	}
}

// MARK: - Custom layout manager for text views in rendered page view

public class BeatRenderLayoutManager:NSLayoutManager {
	weak var pageView:BeatPaginationPageView?
	
	override public func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
		super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
		
		let container = self.textContainers.first!
		let revisions = pageView?.settings.revisions as? [String] ?? []
		
		if ((pageView?.isTitlePage ?? false)) {
			return
		}
		
        #if os(macOS)
		NSGraphicsContext.saveGraphicsState()
        #endif
		
		self.enumerateLineFragments(forGlyphRange: glyphsToShow) { rect, usedRect, textContainer, originalRange, stop in
			let markerRect = CGRectMake(container.size.width - 10 - (self.pageView?.pageStyle.marginRight ?? 0.0), usedRect.origin.y - 3.0, 15, usedRect.size.height)
			
			var highestRevision = ""
			var range = originalRange
			
			// This is a fix for some specific languages. Sometimes you might have more characters in range than what are stored in text storage.
			if (NSMaxRange(range) > self.textStorage!.string.count) {
				let len = max(self.textStorage!.string.count - NSMaxRange(range), 0)
				range = NSMakeRange(range.location, len)
				
				if (range.length == 0) {
					return
				}
			}
			
			self.textStorage?.enumerateAttribute(NSAttributedString.Key(BeatRevisions.attributeKey()), in: range, using: { obj, attrRange, stop in
				if (obj == nil) { return }
				let revision = obj as! String
				
				// If the revision is not included in settings, just skip it.
				if (!revisions.contains(where: { $0 == revision })) {
					return
				}
				
				if highestRevision == "" {
					highestRevision = revision
				}
				else if BeatRevisions.isNewer(revision, than: highestRevision) {
					highestRevision = revision
				}
			})
			
			if highestRevision == "" { return }
			
			let marker:NSString = BeatRevisions.revisionMarkers()[highestRevision]! as NSString
			let font = BeatFonts.shared().regular
			marker.draw(at: markerRect.origin, withAttributes: [
				NSAttributedString.Key.font: font,
				NSAttributedString.Key.foregroundColor: UXColor.black
			])
		}
		
        #if os(macOS)
		NSGraphicsContext.restoreGraphicsState()
        #endif
	}
	
	override public func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
		super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
	}
}

