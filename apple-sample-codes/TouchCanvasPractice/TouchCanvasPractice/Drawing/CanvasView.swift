import UIKit

class CanvasView: UIView {
    
    private let lines: NSMapTable<UITouch, Line> = NSMapTable.strongToStrongObjects()
    
    var needFullRedraw = false
                                            
    private func addLine(_ touch: UITouch) -> Line {
        let line = Line()
        lines.setObject(line, forKey: touch)
        return line
    }
    
    func drawTouches(_ touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let line: Line = lines.object(forKey: touch) ?? addLine(touch)
            line.addPoint(for: touch, in: self)
        }
        
        setNeedsDisplay()
    }
    
    func endTouches(_ touches: Set<UITouch>, withEvent event: UIEvent?) {
        drawTouches(touches, withEvent: event)
        
        for touch in touches {
            let line: Line = lines.object(forKey: touch) ?? addLine(touch)
        }
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        
        context.setLineCap(.round)
        
        if needFullRedraw {
            context.clear(bounds)
            needFullRedraw = false
        }
        
        for line in lines.objectEnumerator() ?? NSEnumerator() {
            (line as! Line).drawWithContext(context)
        }
    }
    
    func clear() {
        lines.removeAllObjects()
        needFullRedraw = true
        setNeedsDisplay()
    }
}
