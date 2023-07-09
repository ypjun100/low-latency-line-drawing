import UIKit

class Line: NSObject {
    private var points = [LinePoint]()
    
    func addPoint(for touch: UITouch, in view: UIView) -> CGRect {
        let point = LinePoint(touch: touch, locatedIn: view)
        
        return CGRect.zero
    }
}
