//
//  NSXMLSVGParser.swift
//  SwiftSVG
//
//
//  Copyright (c) 2017 Michael Choe
//  http://www.github.com/mchoe
//  http://www.straussmade.com/
//  http://www.twitter.com/_mchoe
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.



#if os(iOS) || os(tvOS)
    import UIKit
#elseif os(OSX)
    import AppKit
#endif



/**
 `NSXMLSVGParser` conforms to `SVGParser`
 */
extension NSXMLSVGParserAsync: SVGParserAsync { }

/**
 Concrete implementation of `SVGParser` that uses Foundation's `XMLParser` to parse a given SVG file.
 */

open class NSXMLSVGParserAsync: NSXMLSVGParser {
    /// :nodoc:
    fileprivate var asyncParseCount: Int = 0
    
    /// :nodoc:
    fileprivate var didDispatchAllElements = true
        
    /// :nodoc:
    public var completionBlock: ((SVGLayer) -> ())?
    
    /// :nodoc:
    public var completionQueue: DispatchQueue?
        
    /// :nodoc:
    let asyncCountQueue = DispatchQueue(label: "com.straussmade.swiftsvg.asyncCountQueue.serial", qos: .userInteractive)
    
    
    /// :nodoc:
    private func finishedProcessing() {
        completionQueue?.safeAsync {
            self.completionBlock?(self.containerLayer)
            self.completionBlock = nil
        }
    }
    
    private init() {
        super.init(svgData: Data())
    }
    
    /**
     Convenience initializer that can initalize an `NSXMLSVGParser` using a local or remote `URL`
     - parameter svgURL: The URL of the SVG.
     - parameter supportedElements: Optional `SVGParserSupportedElements` struct that restrict the elements and attributes that this parser can parse.If no value is provided, all supported attributes will be used.
     - parameter completion: Optional completion block that will be executed after all elements and attribites have been parsed.
     */
    public convenience init(svgURL: URL, supportedElements: SVGParserSupportedElements? = nil, completion: ((SVGLayer) -> ())? = nil) {
        
        do {
            let urlData = try Data(contentsOf: svgURL)
            self.init(svgData: urlData, supportedElements: supportedElements, completion: completion)
        } catch {
            self.init()
            print("Couldn't get data from URL")
        }
    }
    
    /// :nodoc:
    @available(*, deprecated, renamed: "init(svgURL:supportedElements:completion:)")
    public convenience init(SVGURL: URL, supportedElements: SVGParserSupportedElements? = nil, completion: ((SVGLayer) -> ())? = nil) {
        self.init(svgURL: SVGURL, supportedElements: supportedElements, completion: completion)
    }
    
    /**
     Initializer that can initalize an `NSXMLSVGParser` using SVG `Data`
     - parameter svgURL: The URL of the SVG.
     - parameter supportedElements: Optional `SVGParserSupportedElements` struct that restricts the elements and attributes that this parser can parse. If no value is provided, all supported attributes will be used.
     - parameter completion: Optional completion block that will be executed after all elements and attribites have been parsed.
     */
    public required init(svgData: Data,
                         supportedElements: SVGParserSupportedElements? = SVGParserSupportedElements.allSupportedElements,
                         completionQueue: DispatchQueue? = DispatchQueue.main,
                         completion: ((SVGLayer) -> ())? = nil) {
        super.init(svgData: svgData, supportedElements: supportedElements)
        self.completionQueue = completionQueue
        self.completionBlock = completion
    }
    
    /// :nodoc:
    @available(*, deprecated, renamed: "init(svgData:supportedElements:completion:)")
    public convenience init(SVGData: Data, supportedElements: SVGParserSupportedElements? = SVGParserSupportedElements.allSupportedElements, completion: ((SVGLayer) -> ())? = nil) {
        self.init(svgData: SVGData, supportedElements: supportedElements, completion: completion)
    }
    
    /**
     Starts parsing the SVG document
     */
    public override func startParsing() {
        self.asyncCountQueue.sync {
            self.didDispatchAllElements = false
        }
        self.parse()
    }
    
    /**
     The `XMLParserDelegate` method called when the parser has started parsing an SVG element. This implementation will loop through all supported attributes and dispatch the attribiute value to the given curried function.
     */
    public override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        guard let svgElement = createElement(name: elementName) else { return }
        
        if var asyncElement = svgElement as? ParsesAsynchronously {
            self.asyncCountQueue.sync {
                self.asyncParseCount += 1
                asyncElement.asyncParseManager = self
            }
        }
        
        for (attributeName, attributeClosure) in svgElement.supportedAttributes {
            if let attributeValue = attributeDict[attributeName] {
                attributeClosure(attributeValue)
            }
        }
        
        self.elementStack.push(svgElement)
    }
        
    /**
     The `XMLParserDelegate` method called when the parser has finished parsing the SVG document. All supported elements and attributes are guaranteed to be dispatched at this point, but there's no guarantee that all elements have finished parsing.
     
     - SeeAlso: `CanManageAsychronousParsing` `finishedProcessing(shapeLayer:)`
     - SeeAlso: `XMLParserDelegate` (`parserDidEndDocument(_:)`)[https://developer.apple.com/documentation/foundation/xmlparserdelegate/1418172-parserdidenddocument]
     */
    public func parserDidEndDocument(_ parser: XMLParser) {
        
        self.asyncCountQueue.sync {
            self.didDispatchAllElements = true
        }
        if self.asyncParseCount <= 0 {
            finishedProcessing()
        }
    }
}

/**
 `NSXMLSVGParserAsync` conforms to the protocol `CanManageAsychronousParsing` that uses a simple reference count to see if there are any pending asynchronous tasks that have been dispatched and are still being processed. Once the element has finished processing, the asynchronous elements calls the delegate callback `func finishedProcessing(shapeLayer:)` and the delegate will decrement the count.
 */
extension NSXMLSVGParserAsync: CanManageAsychronousParsing {
    
    /**
     The `CanManageAsychronousParsing` callback called when an `ParsesAsynchronously` element has finished parsing
     */
    func finishedProcessing(_ shapeLayer: CAShapeLayer) {
        
        self.asyncCountQueue.sync {
            self.asyncParseCount -= 1
        }
              
        guard self.asyncParseCount <= 0 && self.didDispatchAllElements else {
            return
        }
        
        finishedProcessing()
    }
    
}
