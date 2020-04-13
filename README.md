# SBVirtualMidiDevice

This is a simple Swift package for creating a virtual midi device in macOS. This should als work for iOS but has not yet been tested. The usage is straight forward. Create an instance of the class, optionally name your virtual midi device with init(_ name:). Use the delegate protocol to receive and process incoming midi messages. 

Here is an example:

In 'AppDelegate'

    let midi = SBVirtualMidiDevice("MyMidi")
 
to receive Midi data, you have to adopt the SBVirtualMidiDeviceDelegate protocol, eg

    extension AppDelegate: SBVirtualMidiDeviceDelegate {
        func receivedNoteOff(channel: UInt8, note: UInt8, velocity: UInt8) {
            print("receivedNoteOff")
        }
        
        func receivedNoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
            print("receivedNoteOn")
        }
        
        func receivedPolyAftertouch(channel: UInt8, note: UInt8, pressure: UInt8) {
            print("receivedPolyAftertouch")
        }
        
        func receivedControlChange(channel: UInt8, controller: UInt8, value: UInt8) {
            print("receivedControlChange")
        }
        
        func receivedProgramChange(channel: UInt8, program: UInt8) {
            print("receivedProgramChange")
        }
        
        func receivedMonoAftertouch(channel: UInt8, pressure: UInt8) {
            print("receivedMonoAftertouch")
        }
        
        func receivedPitchbend(channel: UInt8, data1: UInt8, data2: UInt8) {
            print("receivedPitchbend")
        }
        
        func receivedSysEx(data: [UInt8], length: Int) {
            print("receivedSysEx")
        }
        
        func logIncomingRawMidiData(data: [UInt8], length: Int) {
            
            var msg: String = ""
            for byte in data {
                msg.append(String(format: "%02X", byte) + " ")
            }
            print("MIDI received: \(msg) length: \(length)")
        }
        
    }
 
 
In 'func applicationDidFinishLaunching(_ aNotification: Notification)'

    midi.delegate = self
    
    
To send midi data, use the public send methods, eg

    midi.sendNoteOn(1, 64, 127)
    midi.sendNoteOff(1, 64, 0)
    midi.sendSysEx([0xF0, 0x01, 0x02, 0x03, 0xF7])
    
