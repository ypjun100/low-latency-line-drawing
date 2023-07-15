import UIKit

class Line: NSObject {
    
    var points = [LinePoint]() // 실제 Line에 대한 Point
    
    func addPoint(for touch: UITouch, in view: UIView) {
        let point = LinePoint(touch: touch, locatedIn: view)
        
        points.append(point)
    }
    
    func drawWithContext(_ context: CGContext) {
        var priorPoint: LinePoint?
        
        for point in points {
            guard let _priorPoint = priorPoint else {
                priorPoint = point
                continue
            }
            
            let color = UIColor.white
            let location = point.location
            let priorLocation = _priorPoint.location
            
            context.setStrokeColor(color.cgColor)
            
            context.beginPath()
            context.move(to: CGPoint(x: priorLocation.x, y: priorLocation.y))
            context.addLine(to: CGPoint(x: location.x, y: location.y))
            context.setLineWidth(point.force * 10)
            context.strokePath()
            
            priorPoint = point
        }
    }
}
