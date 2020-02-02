//
//  PathCommand.swift
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


internal enum PathType {
    case absolute, relative
}

/**
 A protocol that describes an instance that can process an individual SVG Element
 */
internal protocol PathCommand: PreviousCommand {
    
    /**
     An array that stores processed coordinates values
     */
    var coordinateBuffer: [Double] { get set }
    
    /**
     The minimum number of coordinates needed to process the path command
     */
    var numberOfRequiredParameters: Int { get }
    
    /**
     The path type, relative or absolute
     */
    var pathType: PathType { get }
    
    /**
     Designated initializer that creates a relative or absolute `PathCommand`
     */
    init(pathType: PathType)
    
    /**
     Once the `numberOfRequiredParameters` has been met, this method will append new path to the passed path
     - Parameter path: The path to append a new path to
     - Parameter previousCommand: An optional previous command. Used primarily with the shortcut cubic and quadratic Bezier types
     */
    func execute(on path: CGMutablePath, previousCommand: PreviousCommand?)
}

/**
 A protocol that describes an instance that represents an SVGElement right before the current one
 */
internal protocol PreviousCommand {
    
    /**
     An array that stores processed coordinates values
     */
    var coordinateBuffer: [Double] { get }
    
    /**
     The path type, relative or absolute
     */
    var pathType: PathType { get }
}

internal extension PathCommand {
    
    /**
     Default implementation for any `PathCommand` indicating where there are enough coordinates stored to be able to process the `SVGElement`
     */
    var canPushCommand: Bool {
        if self.numberOfRequiredParameters == 0 {
            return true
        }
        if self.coordinateBuffer.count == 0 {
            return false
        }
        if self.coordinateBuffer.count % self.numberOfRequiredParameters == 0 {
            return true
        }
        return false
    }
    
    /**
     Function that clears the current number buffer
     */
    mutating func clearBuffer() {
        self.coordinateBuffer.removeAll()
    }
    
    /**
     Adds a new coordinate to the buffer
     */
    mutating func pushCoordinate(_ coordinate: Double) {
        self.coordinateBuffer.append(coordinate)
    }
    
    /**
     Based on the `PathType` of this PathCommand, this function returns the relative or absolute point
     */
    func pointForPathType(_ point: CGPoint, relativeTo: CGPoint) -> CGPoint {
        switch self.pathType {
        case .absolute:
            return point
        case .relative:
            return CGPoint(x: point.x + relativeTo.x, y: point.y + relativeTo.y)
        }
    }
    
}



/////////////////////////////////////////////////////
//
// MARK: - Implementations

/**
 The `PathCommand` that corresponds to the SVG `M` or `m` command
 */
internal struct MoveTo: PathCommand {
    
    /// :nodoc:
    internal var coordinateBuffer = [Double]()
    
    /// :nodoc:
    internal let numberOfRequiredParameters = 2
    
    /// :nodoc:
    internal let pathType: PathType
    
    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }
    
    /**
     This will move the current point to `CGPoint(self.coordinateBuffer[0], self.coordinateBuffer[1])`.
     
     Sequential MoveTo commands should be treated as LineTos.
     
     From Docs (https://www.w3.org/TR/SVG2/paths.html#PathDataMovetoCommands):
     
     ```
     Start a new sub-path at the given (x,y) coordinates. M (uppercase) indicates that absolute coordinates will follow; m (lowercase) indicates that relative coordinates will follow. If a moveto is followed by multiple pairs of coordinates, the subsequent pairs are treated as implicit lineto commands. Hence, implicit lineto commands will be relative if the moveto is relative, and absolute if the moveto is absolute.
     ```
     */
    internal func execute(on path: CGMutablePath, previousCommand: PreviousCommand? = nil) {
        
        if previousCommand is MoveTo {
            var implicitLineTo = LineTo(pathType: self.pathType)
            implicitLineTo.coordinateBuffer = [self.coordinateBuffer[0], self.coordinateBuffer[1]]
            implicitLineTo.execute(on: path)
            return
        }
        
        let point = self.pointForPathType(CGPoint(x: self.coordinateBuffer[0], y: self.coordinateBuffer[1]), relativeTo: path.currentPoint)
        path.move(to: point)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `Z` or `z` command
 */
internal struct ClosePath: PathCommand {
    
    /// :nodoc:
    internal var coordinateBuffer = [Double]()
    
    /// :nodoc:
    internal let numberOfRequiredParameters = 0
    
    /// :nodoc:
    internal var pathType: PathType = .absolute
    
    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }
    
    /**
     Closes the current path
     */
    internal func execute(on path: CGMutablePath, previousCommand: PreviousCommand? = nil) {
        path.closeSubpath()
    }
    
}

/**
 The `PathCommand` that corresponds to the SVG `L` or `l` command
 */
internal struct LineTo: PathCommand {
    
    /// :nodoc:
    internal var coordinateBuffer = [Double]()
    
    /// :nodoc:
    internal let numberOfRequiredParameters = 2
    
    /// :nodoc:
    internal let pathType: PathType
    
    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }
    
    /**
     Creates a line from the `path.currentPoint` to point `CGPoint(self.coordinateBuffer[0], coordinateBuffer[1])`
     */
    internal func execute(on path: CGMutablePath, previousCommand: PreviousCommand? = nil) {
        let point = self.pointForPathType(CGPoint(x: self.coordinateBuffer[0], y: self.coordinateBuffer[1]), relativeTo: path.currentPoint)
        path.addLine(to: point)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `H` or `h` command
 */
internal struct HorizontalLineTo: PathCommand {
    
    /// :nodoc:
    internal var coordinateBuffer = [Double]()
    
    /// :nodoc:
    internal let numberOfRequiredParameters = 1
    
    /// :nodoc:
    internal let pathType: PathType
    
    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }
    
    /**
     Adds a horizontal line from the currentPoint to `CGPoint(self.coordinateBuffer[0], path.currentPoint.y)`
     */
    internal func execute(on path: CGMutablePath, previousCommand: PreviousCommand? = nil) {
        let x = self.coordinateBuffer[0]
        let point = (self.pathType == .absolute ? CGPoint(x: CGFloat(x), y: path.currentPoint.y) : CGPoint(x: path.currentPoint.x + CGFloat(x), y: path.currentPoint.y))
        path.addLine(to: point)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `V` or `v` command
 */
internal struct VerticalLineTo: PathCommand {
    
    /// :nodoc:
    internal var coordinateBuffer = [Double]()
    
    /// :nodoc:
    internal let numberOfRequiredParameters = 1
    
    /// :nodoc:
    internal let pathType: PathType
    
    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }
    
    /**
     Adds a vertical line from the currentPoint to `CGPoint(path.currentPoint.y, self.coordinateBuffer[0])`
     */
    internal func execute(on path: CGMutablePath, previousCommand: PreviousCommand? = nil) {
        let y = self.coordinateBuffer[0]
        let point = (self.pathType == .absolute ? CGPoint(x: path.currentPoint.x, y: CGFloat(y)) : CGPoint(x: path.currentPoint.x, y: path.currentPoint.y + CGFloat(y)))
        path.addLine(to: point)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `C` or `c` command
 */
internal struct CurveTo: PathCommand {
    
    /// :nodoc:
    internal var coordinateBuffer = [Double]()
    
    /// :nodoc:
    internal let numberOfRequiredParameters = 6
    
    /// :nodoc:
    internal let pathType: PathType
    
    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }
    
    /**
     Adds a cubic Bezier curve to `path`. The path will end up at `CGPoint(self.coordinateBuffer[4], self.coordinateBuffer[5])`. The control point for `path.currentPoint` will be `CGPoint(self.coordinateBuffer[0], self.coordinateBuffer[1])`. Then controle point for the end point will be CGPoint(self.coordinateBuffer[2], self.coordinateBuffer[3])
     */
    internal func execute(on path: CGMutablePath, previousCommand: PreviousCommand? = nil) {
        let startControl = self.pointForPathType(CGPoint(x: self.coordinateBuffer[0], y: self.coordinateBuffer[1]), relativeTo: path.currentPoint)
        let endControl = self.pointForPathType(CGPoint(x: self.coordinateBuffer[2], y: self.coordinateBuffer[3]), relativeTo: path.currentPoint)
        let point = self.pointForPathType(CGPoint(x: self.coordinateBuffer[4], y: self.coordinateBuffer[5]), relativeTo: path.currentPoint)
        path.addCurve(to: point, control1: startControl, control2: endControl)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `S` or `s` command
 */
internal struct SmoothCurveTo: PathCommand {
    
    /// :nodoc:
    internal var coordinateBuffer = [Double]()
    
    /// :nodoc:
    internal let numberOfRequiredParameters = 4
    
    /// :nodoc:
    internal let pathType: PathType
    
    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }
    
    /**
     Shortcut cubic Bezier curve to that add a new path ending up at `CGPoint(self.coordinateBuffer[0], self.coordinateBuffer[1])` with a single control point in the middle.
     */
    internal func execute(on path: CGMutablePath, previousCommand: PreviousCommand? = nil) {
        
        let point = self.pointForPathType(CGPoint(x: self.coordinateBuffer[2], y: self.coordinateBuffer[3]), relativeTo: path.currentPoint)
        let controlEnd = self.pointForPathType(CGPoint(x: self.coordinateBuffer[0], y: self.coordinateBuffer[1]), relativeTo: path.currentPoint)
        
        let controlStart: CGPoint
        if let previousCurveTo = previousCommand as? CurveTo  {
            switch previousCurveTo.pathType {
            case .absolute:
                controlStart = CGPoint(
                    x: Double(2.0 * path.currentPoint.x) - previousCurveTo.coordinateBuffer[2],
                    y: Double(2.0 * path.currentPoint.y) - previousCurveTo.coordinateBuffer[3]
                )
            case .relative:
                let oldCurrentPoint = (
                    Double(path.currentPoint.x) - previousCurveTo.coordinateBuffer[4],
                    Double(path.currentPoint.y) - previousCurveTo.coordinateBuffer[5]
                )
                controlStart = CGPoint(
                    x: Double(2.0 * path.currentPoint.x) - (previousCurveTo.coordinateBuffer[2] + oldCurrentPoint.0),
                    y: Double(2.0 * path.currentPoint.y) - (previousCurveTo.coordinateBuffer[3] + oldCurrentPoint.1)
                )
            }
        } else if let previousSmoothCurveTo = previousCommand as? SmoothCurveTo{
            switch previousSmoothCurveTo.pathType {
            case .absolute:
                controlStart = CGPoint(
                    x: Double(2.0 * path.currentPoint.x) - previousSmoothCurveTo.coordinateBuffer[0],
                    y: Double(2.0 * path.currentPoint.y) - previousSmoothCurveTo.coordinateBuffer[1]
                )
            case .relative:
                let oldCurrentPoint = (
                    Double(path.currentPoint.x) - previousSmoothCurveTo.coordinateBuffer[2],
                    Double(path.currentPoint.y) - previousSmoothCurveTo.coordinateBuffer[3]
                )
                controlStart = CGPoint(
                    x: Double(2.0 * path.currentPoint.x) - (previousSmoothCurveTo.coordinateBuffer[0] + oldCurrentPoint.0),
                    y: Double(2.0 * path.currentPoint.y) - (previousSmoothCurveTo.coordinateBuffer[1] + oldCurrentPoint.1)
                )
            }
        } else {
            controlStart = path.currentPoint
        }
        path.addCurve(to: point, control1: controlStart, control2: controlEnd)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `Q` or `q` command
 */
internal struct QuadraticCurveTo: PathCommand {
    
    /// :nodoc:
    internal var coordinateBuffer = [Double]()
    
    /// :nodoc:
    internal let numberOfRequiredParameters = 4
    
    /// :nodoc:
    internal let pathType: PathType
    
    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }
    
    internal func execute(on path: CGMutablePath, previousCommand: PreviousCommand? = nil) {
        let controlPoint = self.pointForPathType(CGPoint(x: self.coordinateBuffer[0], y: self.coordinateBuffer[1]), relativeTo: path.currentPoint)
        let point = self.pointForPathType(CGPoint(x: self.coordinateBuffer[2], y: self.coordinateBuffer[3]), relativeTo: path.currentPoint)
        path.addQuadCurve(to: point, control: controlPoint)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `T` or `t` command
 */
internal struct SmoothQuadraticCurveTo: PathCommand {
    
    /// :nodoc:
    internal var coordinateBuffer = [Double]()
    
    /// :nodoc:
    internal let numberOfRequiredParameters = 2
    
    /// :nodoc:
    internal let pathType: PathType
    
    /// :nodoc:
    internal var previousControlPoint: CGPoint? = nil
    
    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }
    
    internal func execute(on path: CGMutablePath, previousCommand: PreviousCommand? = nil) {
        
        let point = self.pointForPathType(CGPoint(x: self.coordinateBuffer[0], y: self.coordinateBuffer[1]), relativeTo: path.currentPoint)
        
        var controlPoint: CGPoint
        if let previousQuadraticCurveTo = previousCommand as? QuadraticCurveTo  {
            switch previousQuadraticCurveTo.pathType {
            case .absolute:
                controlPoint = CGPoint(
                    x: Double(2.0 * path.currentPoint.x) - previousQuadraticCurveTo.coordinateBuffer[0],
                    y: Double(2.0 * path.currentPoint.y) - previousQuadraticCurveTo.coordinateBuffer[1]
                )
            case .relative:
                let oldCurrentPoint = (
                    Double(path.currentPoint.x) - previousQuadraticCurveTo.coordinateBuffer[2],
                    Double(path.currentPoint.y) - previousQuadraticCurveTo.coordinateBuffer[3]
                )
                controlPoint = CGPoint(
                    x: Double(2.0 * path.currentPoint.x) - previousQuadraticCurveTo.coordinateBuffer[0] + oldCurrentPoint.0,
                    y: Double(2.0 * path.currentPoint.y) - previousQuadraticCurveTo.coordinateBuffer[1] + oldCurrentPoint.1
                )
            }
        } else {
            controlPoint = path.currentPoint
        }
        path.addQuadCurve(to: point, control: controlPoint)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `A` or `a` command
 */
internal struct EllipticalArc: PathCommand {
    
    /// :nodoc:
    internal var coordinateBuffer = [Double]()
    
    /// :nodoc:
    internal let numberOfRequiredParameters = 7
    
    /// :nodoc:
    internal let pathType: PathType
    
    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }
    
    /// :nodoc:
    internal func execute(on path: CGMutablePath, previousCommand: PreviousCommand? = nil) {
        // Ported Swift implementation from: https://github.com/GenerallyHelpfulSoftware/Scalar2D
        
        // Notes to the original algorithm
        // implementation notes http://www.w3.org/TR/SVG/implnote.html#ArcConversionEndpointToCenter
        // general algorithm from MIT licensed http://code.google.com/p/svg-edit/source/browse/trunk/editor/canvg/canvg.js
        // Gabe Lerner (gabelerner@gmail.com)
        // first do first aid to the parameters to keep them in line
        
        let curPoint = path.currentPoint
        
        let degToRad = CGFloat.pi / 180.0
        
        var xRadius = CGFloat(self.coordinateBuffer[0])
        var yRadius = CGFloat(self.coordinateBuffer[1])
        var angle = CGFloat(self.coordinateBuffer[2])
        
        let largeArcFlag = (self.coordinateBuffer[3] == 1.0)
        let sweepFlag = (self.coordinateBuffer[4] == 1.0)
        
        let endPoint = self.pointForPathType(CGPoint(x: self.coordinateBuffer[5],
                                                     y: self.coordinateBuffer[6]), relativeTo: curPoint)
        
        guard curPoint != endPoint else { return }
        guard xRadius != 0.0, yRadius != 0.0 else {
            path.addLine(to: endPoint)
            return
        }
        
        xRadius = abs(xRadius)
        yRadius = abs(yRadius)
        
        angle = fmod(angle, 360.0)
        
        let angleRad = degToRad * angle
        let angleCos = cos(angleRad)
        let angleSin = sin(angleRad)
        
        let deltaX = path.currentPoint.x - endPoint.x
        let deltaY = path.currentPoint.y - endPoint.y
        
        let ½DeltaX = deltaX / 2.0
        let ½DeltaY = deltaY / 2.0
               
        var xRadius² = xRadius*xRadius
        var yRadius² = yRadius*yRadius
               
               
        // steps are from the implementation notes
        // F.6.5  Step 1: Compute (x1′, y1′)
        let translatedCurPoint = CGPoint(x: angleCos * ½DeltaX + angleSin * ½DeltaY,
                                         y: -angleSin * ½DeltaX + angleCos * ½DeltaY)
                   
               
        let translatedCurPointX² = translatedCurPoint.x * translatedCurPoint.x
        let translatedCurPointY² = translatedCurPoint.y * translatedCurPoint.y
               
        // (skipping to different section) F.6.6 Step 3: Ensure radii are large enough
        var shouldBeNoMoreThanOne = translatedCurPointX²/(xRadius²) + translatedCurPointY²/(yRadius²)
               
        if(shouldBeNoMoreThanOne > 1.0) {
            xRadius *= sqrt(shouldBeNoMoreThanOne)
            yRadius *= sqrt(shouldBeNoMoreThanOne)
                   
            xRadius² = xRadius*xRadius
            yRadius² = yRadius*yRadius
                   
            shouldBeNoMoreThanOne = translatedCurPointX²/(xRadius²) + translatedCurPointY²/(yRadius²)
            if(shouldBeNoMoreThanOne > 1.0) { // sometimes just a bit north of 1.0000000 after first pass
                shouldBeNoMoreThanOne += 0.000001 // making sure
                xRadius *= sqrt(shouldBeNoMoreThanOne)
                yRadius *= sqrt(shouldBeNoMoreThanOne)
                       
                xRadius² = xRadius*xRadius
                yRadius² = yRadius*yRadius
            }
        }
                       
        // back to  F.6.5   Step 2: Compute (cx′, cy′)
        let  centerScalingDivisor = xRadius²*translatedCurPointY² + yRadius²*translatedCurPointX²
        var centerScaling = CGFloat(0.0)
               
        if(centerScalingDivisor != 0.0) {
            let centerScaling² = (xRadius²*yRadius² - xRadius²*translatedCurPointY² - yRadius²*translatedCurPointX²) / centerScalingDivisor
            centerScaling = sqrt(centerScaling²)
            
            if(centerScaling.isNaN) {
                centerScaling = 0.0
            }
               
            if(sweepFlag == largeArcFlag) {
                centerScaling *= -1.0
            }
        }
               
        let translatedCenterPoint = CGPoint(x: centerScaling * xRadius * translatedCurPoint.y / yRadius,
                                            y: -centerScaling * yRadius * translatedCurPoint.x / xRadius)
               
        // F.6.5  Step 3: Compute (cx, cy) from (cx′, cy′)
               
               
        let averageX = (curPoint.x + endPoint.x) / 2.0
        let averageY = (curPoint.y + endPoint.y) / 2.0
        
        let centerPoint = CGPoint(x: averageX + angleCos * translatedCenterPoint.x - angleSin * translatedCenterPoint.y,
                                  y: averageY + angleSin * translatedCenterPoint.x + angleCos * translatedCenterPoint.y)
        
        // F.6.5   Step 4: Compute θ1 and Δθ
               
        // misusing CGPoint as a vector
        let vectorX = CGPoint(x: 1.0, y: 0.0)
        let vectorU = CGPoint(x: (translatedCurPoint.x - translatedCenterPoint.x) / xRadius,
                              y: (translatedCurPoint.y - translatedCenterPoint.y) / yRadius)
        
        let vectorV = CGPoint(x: (-translatedCurPoint.x - translatedCenterPoint.x) / xRadius,
                              y: (-translatedCurPoint.y - translatedCenterPoint.y) / yRadius)
               
        let startAngle = computeAngle(vectorX, vectorU)
        var angleDelta = computeAngle(vectorU, vectorV)
        let vectorRatio = ration(vectorU, vectorV)
        
               
        if(vectorRatio <= -1) {
            angleDelta = CGFloat.pi
        } else if(vectorRatio >= 1.0) {
            angleDelta = 0.0
        }
        
        if !sweepFlag, angleDelta > 0.0 {
            angleDelta = angleDelta - 2.0 * CGFloat.pi
        }
        
        if sweepFlag, angleDelta < 0.0 {
            angleDelta = angleDelta + 2.0 * CGFloat.pi
        }
        
        var transform = CGAffineTransform.identity
        
        transform = transform.translatedBy(x: centerPoint.x, y: centerPoint.y)
        transform = transform.rotated(by: angleRad)
        
        let radius = (xRadius > yRadius) ? xRadius : yRadius
        let scaleX = (xRadius > yRadius) ? 1.0 : xRadius / yRadius
        let scaleY = (xRadius > yRadius) ? yRadius / xRadius : 1.0
                
        transform = transform.scaledBy(x: scaleX, y: scaleY)
                
        path.addArc(center: CGPoint.zero, radius: radius, startAngle: startAngle, endAngle: startAngle + angleDelta, clockwise: !sweepFlag, transform: transform)
    }
    
    private func magnitude(_ v: CGPoint) -> CGFloat {
        return CGFloat(sqrt(v.x*v.x + v.y*v.y))
    }
    
    private func ration(_ v1: CGPoint, _ v2: CGPoint) -> CGFloat {
        return (v1.x*v2.x + v1.y*v2.y) / (magnitude(v1) * magnitude(v2))
    }
        
    private func computeAngle(_ v1: CGPoint, _ v2: CGPoint) -> CGFloat {
        let result = acos(ration(v1, v2))
        return (v1.x * v2.y < v1.y * v2.x) ? -result : result
    }
}
