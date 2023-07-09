import UIKit

class CanvasView: UIView {
    // MARK: Properties

    var usePreciseLocations = false {
        didSet {
            needsFullRedraw = true
            setNeedsDisplay()
        }
    }
    var isDebuggingEnabled = false {
        didSet {
            needsFullRedraw = true
            setNeedsDisplay()
        }
    }
    private var needsFullRedraw = true

    /// Array containing all line objects that need to be drawn in `drawRect(_:)`.
    private var lines = [Line]()

    /// Array containing all line objects that have been completely drawn into the frozenContext.
    private var finishedLines = [Line]()

    /**
        Holds a map of `UITouch` objects to `Line` objects whose touch has not ended yet.

        Use `NSMapTable` to handle association as `UITouch` doesn't conform to `NSCopying`. There is no value
        in accessing the properties of the touch used as a key in the map table. `UITouch` properties should
        be accessed in `NSResponder` callbacks and methods called from them.
    */
    private let activeLines: NSMapTable<UITouch, Line> = NSMapTable.strongToStrongObjects() // UITouch의 주소값을 Key로 설정

    /**
        Holds a map of `UITouch` objects to `Line` objects whose touch has ended but still has points awaiting
        updates.

        Use `NSMapTable` to handle association as `UITouch` doesn't conform to `NSCopying`. There is no value
        in accessing the properties of the touch used as a key in the map table. `UITouch` properties should
        be accessed in `NSResponder` callbacks and methods called from them.
    */
    private let pendingLines: NSMapTable<UITouch, Line> = NSMapTable.strongToStrongObjects()

    /// A `CGContext` for drawing the last representation of lines no longer receiving updates into.
    private lazy var frozenContext: CGContext = {
        let scale = self.window!.screen.scale
        var size = self.bounds.size

        size.width *= scale
        size.height *= scale
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let context: CGContext = CGContext(data: nil,
                                           width: Int(size.width),
                                           height: Int(size.height),
                                           bitsPerComponent: 8,
                                           bytesPerRow: 0,
                                           space: colorSpace,
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

        context.setLineCap(.round)
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        context.concatenate(transform)

        return context
    }()

    /// An optional `CGImage` containing the last representation of lines no longer receiving updates.
    private var frozenImage: CGImage?

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!

        context.setLineCap(.round)

        if needsFullRedraw {
            setFrozenImageNeedsUpdate()
            frozenContext.clear(bounds)
            for array in [finishedLines, lines] {
                for line in array {
                    line.drawCommitedPoints(in: frozenContext, isDebuggingEnabled: isDebuggingEnabled, usePreciseLocation: usePreciseLocations)
                }
            }
            needsFullRedraw = false
        }

        frozenImage = frozenImage ?? frozenContext.makeImage()

        if let frozenImage = frozenImage {
            context.draw(frozenImage, in: bounds)
        }

        for line in lines {
            line.drawInContext(context, isDebuggingEnabled: isDebuggingEnabled, usePreciseLocation: usePreciseLocations)
        }
    }

    private func setFrozenImageNeedsUpdate() {
        frozenImage = nil
    }

    // MARK: Actions

    func clear() {
        activeLines.removeAllObjects()
        pendingLines.removeAllObjects()
        lines.removeAll()
        finishedLines.removeAll()
        needsFullRedraw = true
        setNeedsDisplay()
    }

    // MARK: Convenience

    func drawTouches(_ touches: Set<UITouch>, withEvent event: UIEvent?) {
        var updateRect = CGRect.null

        for touch in touches {
            //  Retrieve a line from `activeLines`. If no line exists, create one.
            //  터치가 종료되지 않은 터치의 경우 생성하고 이동하고 제거될 때까지 동일한 주소값을 가지므로, 해당 주소값을 activeLines의 Key값으로 활용
            let line: Line = activeLines.object(forKey: touch) ?? addActiveLineForTouch(touch)

            /*
                Remove prior predicted points and update the `updateRect` based on the removals. The touches
                used to create these points are predictions provided to offer additional data. They are stale
                by the time of the next event for this touch.
            */
            updateRect = updateRect.union(line.removePointsWithType(.predicted))

            /*
                Incorporate coalesced touch data. The data in the last touch in the returned array will match
                the data of the touch supplied to `coalescedTouchesForTouch(_:)`
            */
            /**
                애플펜슬은 터치이벤트에 대한 정보를 240Hz의 주기로 전송하지만, UIKit은 아이패드를 프로를 제외한 기기에서 터치이벤트를
                60Hz의 주기로 수신함 따라서, 애플펜슬에서 240번 데이터를 보내면, UIKit에서는 60번 밖에 받지 못하므로, 나머지
                손실된 포인트들을 coalescedTouches()를 통해 가져와, 정밀한 드로잉 데이터가 필요할 때 해당 기능을 사용하여 손실을 보완함.
                `대신 이를 처리하기 위한 오버헤드가 발생할 수 있음`
                https://velog.io/@panther222128/Getting-High-Fidelity-Input-with-Coalesced-Touches
             **/
            let coalescedTouches = event?.coalescedTouches(for: touch) ?? []
            let coalescedRect = addPointsOfType(.coalesced, for: coalescedTouches, to: line, in: updateRect)
            updateRect = updateRect.union(coalescedRect)

            /*
                Incorporate predicted touch data. This sample draws predicted touches differently; however,
                you may want to use them as inputs to smoothing algorithms rather than directly drawing them.
                Points derived from predicted touches should be removed from the line at the next event for
                this touch.
            */
            /*
                필기 레이턴시를 줄이기 위한 필기 예측 함수 사용. 계속되는 직선이나 곡선에 대한 예측을 할 수 있지만 갑자기 회전이
                변경되는 부분은 예측 정확도가 떨어질 수 밖에 없음. 따라서 예측 후 실제 펜슬이 지나간 후에는 예측한 포인트들을
                삭제해야 함.
                http://yoonbumtae.com/?p=4009 - 레이턴시 줄이기 참고
             */
            let predictedTouches = event?.predictedTouches(for: touch) ?? []
            let predictedRect = addPointsOfType(.predicted, for: predictedTouches, to: line, in: updateRect)
            updateRect = updateRect.union(predictedRect)
        }

        setNeedsDisplay(updateRect)
    }

    private func addActiveLineForTouch(_ touch: UITouch) -> Line {
        let newLine = Line()

        activeLines.setObject(newLine, forKey: touch)

        lines.append(newLine)

        return newLine
    }

    private func addPointsOfType(_ type: LinePoint.PointType, for touches: [UITouch], to line: Line, in updateRect: CGRect) -> CGRect {
        var accumulatedRect = CGRect.null
        var type = type

        for (idx, touch) in touches.enumerated() {
            let isPencil = touch.type == .pencil

            // The visualization displays non-`.pencil` touches differently.
            if !isPencil {
                type.formUnion(.finger)
            }

            // Touches with estimated properties require updates; add this information to the `PointType`.
            if !touch.estimatedProperties.isEmpty {
                type.formUnion(.needsUpdate)
            }

            // The last touch in a set of `.coalesced` touches is the originating touch. Track it differently.
            if type.contains(.coalesced) && idx == touches.count - 1 {
                type.subtract(.coalesced)
                type.formUnion(.standard)
            }

            let touchRect = line.addPointOfType(type, for: touch, in: self)
            accumulatedRect = accumulatedRect.union(touchRect)

            commitLine(line)
        }

        return updateRect.union(accumulatedRect)
    }

    func endTouches(_ touches: Set<UITouch>, cancel: Bool) {
        var updateRect = CGRect.null

        for touch in touches {
            // Skip over touches that do not correspond to an active line.
            guard let line = activeLines.object(forKey: touch) else { continue }

            // If this is a touch cancellation, cancel the associated line.
            if cancel { updateRect = updateRect.union(line.cancel()) }

            // If the line is complete (no points needing updates) or updating isn't enabled, move the line to the `frozenImage`.
            if line.isComplete {
                finishLine(line)
            }
            // Otherwise, add the line to our map of touches to lines pending update.
            else {
                pendingLines.setObject(line, forKey: touch)
            }

            // This touch is ending, remove the line corresponding to it from `activeLines`.
            activeLines.removeObject(forKey: touch)
        }

        setNeedsDisplay(updateRect)
    }

    func updateEstimatedPropertiesForTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            var isPending = false

            // Look to retrieve a line from `activeLines`. If no line exists, look it up in `pendingLines`.
            let possibleLine: Line? = activeLines.object(forKey: touch) ?? {
                let pendingLine = pendingLines.object(forKey: touch)
                isPending = pendingLine != nil
                return pendingLine
            }()

            // If no line is related to the touch, return as there is no additional work to do.
            guard let line = possibleLine else { return }

            switch line.updateWithTouch(touch) {
                case (true, let updateRect):
                    setNeedsDisplay(updateRect)
                default:
                    ()
            }

            // If this update updated the last point requiring an update, move the line to the `frozenImage`.
            if isPending && line.isComplete {
                finishLine(line)
                pendingLines.removeObject(forKey: touch)
            }
            // Otherwise, have the line add any points no longer requiring updates to the `frozenImage`.
            else {
                commitLine(line)
            }

        }
    }

    private func commitLine(_ line: Line) {
        // Have the line draw any segments between points no longer being updated into the `frozenContext` and remove them from the line.
        line.drawFixedPointsInContext(frozenContext, isDebuggingEnabled: isDebuggingEnabled, usePreciseLocation: usePreciseLocations)
        setFrozenImageNeedsUpdate()
    }

    private func finishLine(_ line: Line) {
        // Have the line draw any remaining segments into the `frozenContext`. All should be fixed now.
        line.drawFixedPointsInContext(frozenContext, isDebuggingEnabled: isDebuggingEnabled, usePreciseLocation: usePreciseLocations, commitAll: true)
        setFrozenImageNeedsUpdate()

        // Cease tracking this line now that it is finished.
        lines.remove(at: lines.index(of: line)!)

        // Store into finished lines to allow for a full redraw on option changes.
        finishedLines.append(line)
    }
}
