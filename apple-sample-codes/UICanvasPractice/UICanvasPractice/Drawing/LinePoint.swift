import UIKit

class LinePoint: NSObject {
    var sequenceNumber: Int                // 시퀀스 내 포인트 인덱스 번호
    let timestamp: TimeInterval            // 해당 포인트의 생성 시간
    var force: CGFloat                     // 필압 (애플펜슬만 해당)
    var location: CGPoint                  // 위치
    var preciseLocation: CGPoint           // 정밀 위치
    let type: UITouch.TouchType            // 포인팅 디바이스 종류 (손, 애플펜슬...)
    var altitudeAngle: CGFloat             // 펜슬의 기울기
    var azimuthAngle: CGFloat              // 펜슬의 방위각도
    var magnitude: CGFloat {               // 펜슬의 최소필압 설정 (0.025 이하의 필압의 굵기는 0.025 필압과 같음)
        return max(force, 0.025)
    }
    
    /**
     애플펜슬로부터 데이터를 수신할 때 전송 지연으로 인해 해당 포인트의 펜슬의 필압과 같은 프로퍼티 데이터가 누락될 수 있음.
     따라서, 어떤 프로퍼티를 받지 못하였는지 `estimatedPropertiesExpectingUpdates`에 저장한 뒤 나중에 데이터가 들어오면
     그때 현재 포인트의 프로퍼티의 값을 수정함
     */
    var estimatedPropertiesExpectingUpdates: UITouch.Properties // 데이터 수신중 전송지연으로 누락된 프로퍼티 이름
    
    /**
     누락된 데이터 포인트에 대한 실제값이 수신되었을 때에는 아래의 변수들에 누락된 포인트의 프로퍼티에 대한 실제 프로퍼티에 대한 정보를 저장함
     */
    var estimatedProperties: UITouch.Properties // 누락된 실제 프로퍼티 이름
    let estimationUpdateIndex: NSNumber? // 누락된 데이터 포인트에 대한 인덱스 값 (해당 인덱스를 참고하여 estimated 값을 실제 값으로 변경해야 함)
    
    
    init(touch: UITouch, sequenceNumber: Int, locatedIn view: UIView) {
        type = touch.type
        
        self.sequenceNumber = sequenceNumber
        timestamp = touch.timestamp
        force = (type == .pencil || touch.force > 0) ? touch.force : 1.0
        location = touch.location(in: view)
        preciseLocation = touch.location(in: view)
        altitudeAngle = touch.altitudeAngle
        azimuthAngle = touch.azimuthAngle(in: view)
        
        estimatedPropertiesExpectingUpdates = touch.estimatedPropertiesExpectingUpdates
        estimatedProperties = touch.estimatedProperties
        estimationUpdateIndex = touch.estimationUpdateIndex
    }
    
    /**
     누락된 프로퍼티에 대한 실제값을 `touch` 파라미터로 받아 누락된 데이터를 업데이트함
     */
    func updateEstimatedProperties(_ touch: UITouch) -> Bool {
        // 해당 touch가 누락된 프로퍼티에 대한 touch인지 확인
        guard let estimationUpdateIndex = touch.estimationUpdateIndex else { return false }
        
        let touchProperties: [UITouch.Properties] = [.altitude, .azimuth, .force, .location]
        
        touchProperties.forEach { touchProperty in
            // 누락된 프로퍼티에 해당하는 경우에만 아래의 코드들을 실행하도록 함
            guard estimatedPropertiesExpectingUpdates.contains(touchProperty) else { return }
            
            // 값 업데이트
            switch touchProperty {
            case .force:
                force = touch.force
            case .azimuth:
                azimuthAngle = touch.azimuthAngle(in: touch.view)
            case .altitude:
                altitudeAngle = touch.altitudeAngle
            case .location:
                location = touch.location(in: touch.view)
                preciseLocation = touch.preciseLocation(in: touch.view)
            default:
                ()
            }
            
            /**
             이전에 데이터가 누락되어 전달받은 `touch`의 프로퍼티에서 포함되지 않은 프로퍼티(이전에 전달받은 프로퍼티)는
             최종값으로 판단하고 `estimatedProperties`에서 제외
             -> 이전에 데이터가 전달되었음에도 불구하고 `estimatedProperties`에 등록된 프로퍼티 삭제
             */
            if !touch.estimatedProperties.contains(touchProperty) {
                estimatedProperties.subtract(touchProperty)
            }
            
            /**
             
             */
        }
        
        return true
    }
}
