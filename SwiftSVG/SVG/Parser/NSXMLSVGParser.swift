//
//  NSXMLSVGParserSync.swift
//  SwiftSVG
//
//
//  Copyright (c) 2020 Grigory Markin
//  http://www.github.com/gr-markin
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

import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif


/**
 `NSXMLSVGParser` conforms to `SVGParser`
 */
extension NSXMLSVGParser: SVGParser {
    
}

/**
 Concrete implementation of `SVGParser` that uses Foundation's `XMLParser` to parse a given SVG file.
 In contrast to the `NSXMLSVGParser`it operates in synchronous mode
 */

open class NSXMLSVGParser: XMLParser, XMLParserDelegate {
    /**
     Error type used when a fatal error has occured
     */
    enum SVGParserError {
        case invalidSVG
        case invalidURL
    }
    
    /// :nodoc:
    var elementStack = Stack<SVGElement>()
    
    /// :nodoc:
    open var supportedElements: SVGParserSupportedElements? = nil
    
    /// The `SVGLayer` that will contain all of the SVG's sublayers
    open var containerLayer = SVGLayer()
    
    
    public init(svgData: Data,
                supportedElements: SVGParserSupportedElements? = SVGParserSupportedElements.allSupportedElements) {
        
        super.init(data: svgData)
        self.delegate = self
        self.supportedElements = supportedElements
    }
    
    internal func createElement(name: String) -> SVGElement? {
        guard let elementType = self.supportedElements?.tags[name] else {
            print("\(name) is unsupported. For a complete list of supported elements, see the `allSupportedElements` variable in the `SVGParserSupportedElements` struct. Click through on the `elementName` variable name to see the SVG tag name.")
            return nil
        }
        return elementType()
    }
    
    /**
     Starts parsing the SVG document
     */
    open func startParsing() {
        self.parse()
    }
    
    /**
     The `XMLParserDelegate` method called when the parser has started parsing an SVG element. This implementation will loop through all supported attributes and dispatch the attribiute value to the given curried function.
     */
    open func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        guard let svgElement = createElement(name: elementName) else { return }
        
        for (attributeName, attributeClosure) in svgElement.supportedAttributes {
            if let attributeValue = attributeDict[attributeName] {
                attributeClosure(attributeValue)
            }
        }
        
        self.elementStack.push(svgElement)
    }
    
    /**
     The `XMLParserDelegate` method called when the parser has ended parsing an SVG element. This methods pops the last element parsed off the stack and checks if there is an enclosing container layer. Every valid SVG file is guaranteed to have at least one container layer (at a minimum, a `SVGRootElement` instance).
     
     If the parser has finished parsing a `SVGShapeElement`, it will resize the parser's `containerLayer` bounding box to fit all subpaths
     
     If the parser has finished parsing a `<svg>` element, that `SVGRootElement`'s container layer is added to this parser's `containerLayer`.
     */
    open func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        guard let last = self.elementStack.last else {
            return
        }
        
        guard elementName == type(of: last).elementName else {
            return
        }
        
        guard let lastElement = self.elementStack.pop() else {
            return
        }
        
        if let rootItem = lastElement as? SVGRootElement {
            DispatchQueue.main.safeAsync {
                self.containerLayer.viewBox = rootItem.viewBox
                self.containerLayer.addSublayer(rootItem.containerLayer)
            }
            return
        }
        
        guard let containerElement = self.elementStack.last as? SVGContainerElement else {
            return
        }
        
        lastElement.didProcessElement(in: containerElement)
    }
    
    /**
     The `XMLParserDelegate` method called when the parser has reached a fatal error in parsing. Parsing is stopped if an error is reached and you may want to check that your SVG file passes validation.
     - SeeAlso: `XMLParserDelegate` (`parser(_:parseErrorOccurred:)`)[https://developer.apple.com/documentation/foundation/xmlparserdelegate/1412379-parser]
     - SeeAlso: (SVG Validator)[https://validator.w3.org/]
     */
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("Parse Error: \(parseError)")
        let code = (parseError as NSError).code
        switch code {
        case 76:
            print("Invalid XML: \(SVGParserError.invalidSVG)")
        default:
            break
        }
    }
    
}
