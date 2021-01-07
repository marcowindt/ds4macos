//
//  DSUController.swift
//  ds4macos
//

import Foundation
import GameController


class DSUController {
    
    static let GRAVITY: Double = 1.0
    var slot: UInt8 = 0x00
    var model: UInt8 = 0x02 // (with gyro, according to specs)
    var connectionType: UInt8 = 0x02 // 0x01: USB, 0x02: Bluetooth
    var battery: UInt8 = 0x05
    static let macAddress: [UInt8] = [0xFA, 0xCE, 0xB0, 0x0C, 0x00, 0x00]
    
    var buttons1: UInt8 = 0x00
    var buttons2: UInt8 = 0x00
    var psButton: UInt8 = 0x00
    var touchBtn: UInt8 = 0x00
    
    var leftStickXplusRightward: UInt8 = 0x00
    var leftStickYplusUpward: UInt8 = 0x00
    
    var rightStickXplusRightward: UInt8 = 0x00
    var rightStickYplusUpward: UInt8 = 0x00
    
    var dpadLeft: UInt8 = 0x00
    var dpadDown: UInt8 = 0x00
    var dpadRight: UInt8 = 0x00
    var dpadUp: UInt8 = 0x00
    
    var buttonSquare: UInt8 = 0x00
    var buttonCross: UInt8 = 0x00
    var buttonCircle: UInt8 = 0x00
    var buttonTriangle: UInt8 = 0x00
    
    var buttonR1: UInt8 = 0x00
    var buttonL1: UInt8 = 0x00
    var buttonR2: UInt8 = 0x00
    var buttonL2: UInt8 = 0x00
    
    var touchPad: [UInt8] = [
        0x00,   // trackpad 1 active
        0x00,   // trackpad 1 id
        0x00, 0x00, // x
        0x00, 0x00, // y
        0x00,   // trackpad 2 active
        0x00,   // trackpad 2 id
        0x00, 0x00, // x
        0x00, 0x00  // y
    ]
    var timeStamp: UInt64 = 0x0000000000000000
    
    let empty: [UInt8] = [0x00, 0x00, 0x00, 0x00]
    
    var accX: [UInt8] = [0x00, 0x00, 0x00, 0x00]
    var accY: [UInt8] = [0x00, 0x00, 0x00, 0x00]
    var accZ: [UInt8] = [0x00, 0x00, 0x00, 0x00]
    
    var gyroX: [UInt8] = [0x00, 0x00, 0x00, 0x00]
    var gyroY: [UInt8] = [0x00, 0x00, 0x00, 0x00]
    var gyroZ: [UInt8] = [0x00, 0x00, 0x00, 0x00]
    
    var counter: UInt32 = 0x00000000
    
    
    init(gameController: GCController, slot: UInt8, counter: UInt32) {
        self.slot = slot
        self.counter = counter
        
        // BUTTONS
        let gamePad = gameController.extendedGamepad!
        
        if gamePad.buttonOptions!.isPressed { // SHARE BUTTON
            buttons1 |= 0x01
        }
        if gamePad.leftThumbstickButton!.isPressed { // L3
            buttons1 |= 0x01 << 1
        }
        if gamePad.rightThumbstickButton!.isPressed { // L3
            buttons1 |= 0x01 << 2
        }
        if gamePad.buttonMenu.isPressed { // OPTIONS BUTTON
            buttons1 |= 0x01 << 3
        }
        if gamePad.dpad.up.isPressed {
            buttons1 |= 0x01 << 4
        }
        if gamePad.dpad.right.isPressed {
            buttons1 |= 0x01 << 5
        }
        if gamePad.dpad.down.isPressed {
            buttons1 |= 0x01 << 6
        }
        if gamePad.dpad.left.isPressed {
            buttons1 |= 0x01 << 7
        }
        
        if gamePad.leftTrigger.isPressed {
            buttons2 |= 0x01
        }
        if gamePad.rightTrigger.isPressed {
            buttons2 |= 0x01 << 1
        }
        if gamePad.leftShoulder.isPressed {
            buttons2 |= 0x01 << 2
        }
        if gamePad.rightShoulder.isPressed {
            buttons2 |= 0x01 << 3
        }
        if gamePad.buttonX.isPressed {
            buttons2 |= 0x01 << 4
        }
        if gamePad.buttonA.isPressed {
            buttons2 |= 0x01 << 5
        }
        if gamePad.buttonB.isPressed {
            buttons2 |= 0x01 << 6
        }
        if gamePad.buttonX.isPressed {
            buttons2 |= 0x01 << 7
        }
        
        if gamePad.buttonHome!.isPressed { // PS BUTTON
            psButton = 0xFF
        }
        
        leftStickXplusRightward = getUInt8fromFloat(num: gamePad.leftThumbstick.xAxis.value)
        leftStickYplusUpward = getUInt8fromFloat(num: gamePad.leftThumbstick.yAxis.value)

        rightStickXplusRightward = getUInt8fromFloat(num: gamePad.rightThumbstick.xAxis.value)
        rightStickYplusUpward = getUInt8fromFloat(num: gamePad.rightThumbstick.yAxis.value)

        dpadLeft = UInt8(gamePad.dpad.left.value * 255)
        dpadDown = UInt8(gamePad.dpad.down.value * 255)
        dpadRight = UInt8(gamePad.dpad.right.value * 255)
        dpadUp = UInt8(gamePad.dpad.up.value * 255)

        buttonSquare = UInt8(gamePad.buttonX.value * 255)
        buttonCross = UInt8(gamePad.buttonA.value * 255)
        buttonCircle = UInt8(gamePad.buttonB.value * 255)
        buttonTriangle = UInt8(gamePad.buttonY.value * 255)
        
        buttonR1 = UInt8(gamePad.rightShoulder.value * 255)
        buttonL1 = UInt8(gamePad.leftShoulder.value * 255)
        
        buttonR2 = UInt8(gamePad.rightTrigger.value * 255)
        buttonL2 = UInt8(gamePad.leftTrigger.value * 255)
        
        // skipping touchpad for now
        
        // MOTION
        timeStamp = UInt64(Date.init().timeIntervalSince1970 * 1000000)
        
        let motion = gameController.motion!
        
        // acceleration
        accX = getUInt8arrayFromDouble(num: motion.acceleration.x)
        accY = getUInt8arrayFromDouble(num: motion.acceleration.z)
        accZ = getUInt8arrayFromDouble(num: motion.acceleration.y)
        
        // gyroscope
        gyroX = getUInt8arrayFromDouble(num: self.radiansToDegree(num: motion.rotationRate.x))
        gyroY = getUInt8arrayFromDouble(num: -self.radiansToDegree(num: motion.rotationRate.z))
        gyroZ = getUInt8arrayFromDouble(num: self.radiansToDegree(num: motion.rotationRate.y))
    }
    
    private func getUInt8fromFloat(num: Float) -> UInt8 {
        if num < 0 {
            return UInt8(bitPattern: Int8((num + 1) * 127))
        } else {
            return UInt8(num * 127 + 128)
        }
    }
    
    private func radiansToDegree(num: Double) -> Double {
        return num * (180.0 / Double.pi)
    }
    
    private func getUInt8arrayFromDouble(num: Double) -> [UInt8] {
        return self.toByteArray(Float(num))
    }
    
    private func getTimestampUInt8array(timeStamp: UInt64) -> [UInt8] {
        return [
            UInt8(truncatingIfNeeded: timeStamp) & 0xFF,
            UInt8(truncatingIfNeeded: timeStamp >> 8) & 0xFF,
            UInt8(truncatingIfNeeded: timeStamp >> 16) & 0xFF,
            UInt8(truncatingIfNeeded: timeStamp >> 24) & 0xFF,
            UInt8(truncatingIfNeeded: timeStamp >> 32) & 0xFF,
            UInt8(truncatingIfNeeded: timeStamp >> 40) & 0xFF,
            UInt8(truncatingIfNeeded: timeStamp >> 48) & 0xFF,
            UInt8(truncatingIfNeeded: timeStamp >> 56) & 0xFF,
        ]
    }
    
    func getDataPacket() -> [UInt8] {
        let macAddress = DSUController.macAddress
        var packet: [UInt8] = [
            slot,   // Only SLOT 0 for now
            0x02,
            model,
            0x02,
            macAddress[0], macAddress[1], macAddress[2], // Mac part 1
            macAddress[3], macAddress[4], macAddress[5], // Mac part 2
            battery,
            0x01,   // Controller ACTIVE state
            UInt8(truncatingIfNeeded: counter) & 0xFF,
            UInt8(truncatingIfNeeded: counter >> 8) & 0xFF,
            UInt8(truncatingIfNeeded: counter >> 16) & 0xFF,
            UInt8(truncatingIfNeeded: counter >> 24) & 0xFF,
            
            buttons1,
            buttons2,
            
            psButton,
            touchBtn,
            
            leftStickXplusRightward,
            leftStickYplusUpward,
            rightStickXplusRightward,
            rightStickYplusUpward,
            
            dpadLeft,
            dpadDown,
            dpadRight,
            dpadUp,
            
            buttonSquare,
            buttonCross,
            buttonCircle,
            buttonTriangle,
            
            buttonR1,
            buttonL1,
            
            buttonR2,
            buttonL2,
        ]
        
        packet.append(contentsOf: touchPad)
        packet.append(contentsOf: getTimestampUInt8array(timeStamp: timeStamp))
        packet.append(contentsOf: accX)
        packet.append(contentsOf: accY)
        packet.append(contentsOf: accZ)
        packet.append(contentsOf: gyroX)
        packet.append(contentsOf: gyroY)
        packet.append(contentsOf: gyroZ)
        
        return DSUMessage.make(type: DSUMessage.TYPE_DATA, data: packet)
    }
    
    func getInfoPacket() -> [UInt8] {
        let macAddress = DSUController.macAddress
        let packet: [UInt8] = [
            slot,   // Only SLOT 0 for now
            0x02,
            model,
            connectionType,
            macAddress[0], macAddress[1], macAddress[2], // Mac part 1
            macAddress[3], macAddress[4], macAddress[5], // Mac part 2
            battery,
            0x01,   // Controller ACTIVE state
        ]
        
        return packet
    }
    
    static func defaultInfoPacket(index: UInt8) -> [UInt8] {
        let packet: [UInt8] = [
            index, // pad id
            0x00, // state (disconnected)
            0x01, // model (generic)
            0x01, // Connection type USB
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Mac
            0x00, // Battery
            0x00, // ? (Needs to be a zero byte according to specs)
        ]
        
        return packet
    }
    
    private func toByteArray<T>(_ value: T) -> [UInt8] {
        var value = value
        return withUnsafeBytes(of: &value) { Array($0) }
    }
    
}

extension GCMotion {
    
    func radiansToDegree(num: Double) -> Double {
        return num * (180.0 / Double.pi)
    }
    
    func eulerAngles() -> GCEulerAngles {
        let x = self.attitude.x
        let y = self.attitude.y
        let z = self.attitude.z
        let w = self.attitude.w
        let roll  = self.radiansToDegree(num: atan2(2 * y * w - 2 * x * z, 1 - 2 * y * y - 2 * z * z))
        let pitch = self.radiansToDegree(num: atan2(2 * x * w - 2 * y * z, 1 - 2 * x * x - 2 * z * z))
        let yaw   = self.radiansToDegree(num: asin(2 * x * y + 2 * z * w))
        return GCEulerAngles(pitch: pitch, yaw: yaw, roll: roll)
    }
    
}
