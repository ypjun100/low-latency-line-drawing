import UIKit

class ViewController: UIViewController, UIPencilInteractionDelegate {
    
    @IBOutlet private weak var canvasView: CanvasView!
    
    @IBOutlet weak var tepsLabel: UILabel! // Touch Event Per Second
    
    var tepsCounter = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 12.1, *) {
            let pencilInteraction = UIPencilInteraction()
            pencilInteraction.delegate = self
            view.addInteraction(pencilInteraction)
        }
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            self.tepsLabel.text = "TEPS : " + String(self.tepsCounter)
            self.tepsCounter = 0
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        canvasView.drawTouches(touches, withEvent: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        canvasView.drawTouches(touches, withEvent: event)
        
        tepsCounter += 1
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        canvasView.endTouches(touches, withEvent: event)
    }
    
    @IBAction func onClear(_: UIButton) {
        canvasView.clear()
    }
}

