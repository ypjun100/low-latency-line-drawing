import UIKit

class CanvasView: UIView {
    private let activeLines: NSMapTable<UITouch, Line> = NSMapTable.strongToStrongObjects()
                                            
    private func addActiveLine(_ touch: UITouch) -> Line {
        let line = Line()
        activeLines.setObject(line, forKey: touch)
        return line
    }
    
    func drawTouches(_ touches: Set<UITouch>, withEvent event: UIEvent?) {
        var newRect = CGRect.null
        
        for touch in touches {
            let line: Line = activeLines.object(forKey: touch) ?? addActiveLine(touch)
            
            let coalescedTouches = event?.coalescedTouches(for: touch) ?? []
            
        }
        
        setNeedsDisplay(newRect)
    }
    
    override func draw(_ rect: CGRect) {
        print("d")
    }
}
