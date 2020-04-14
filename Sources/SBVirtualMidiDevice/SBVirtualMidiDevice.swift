//
//  HUIConnection.swift
//  REC Link
//
//  Created by Stefan Schaflitzel on 26.03.20.
//  Copyright © 2020 Stefan Schaflitzel. All rights reserved.
//

import Foundation
import CoreMIDI


public protocol SBVirtualMidiDeviceDelegate {
    
    func receivedNoteOff(channel: UInt8, note: UInt8, velocity: UInt8)
    func receivedNoteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    func receivedPolyAftertouch(channel: UInt8, note: UInt8, pressure: UInt8)
    func receivedControlChange(channel: UInt8, controller: UInt8, value: UInt8)
    func receivedProgramChange(channel: UInt8, program: UInt8)
    func receivedMonoAftertouch(channel: UInt8, pressure: UInt8)
    func receivedPitchbend(channel: UInt8, data1: UInt8, data2: UInt8)
    func receivedSysEx(data: [UInt8], length: Int)
    
    
    /// optional method for debugging
    ///
    /// example:
    ///
    ///     var msg: String = ""
    ///     for byte in data {
    ///     msg.append(String(format: "%02X", byte) + " ")
    ///     }
    ///     print("MIDI received: \(msg) length: \(length)")
    ///
    func logIncomingRawMidiData(data: [UInt8], length: Int)
}

/// contains optional methods which doesn't need to be implemented
extension SBVirtualMidiDeviceDelegate {
    
   
    func logIncomingRawMidiData(data: [UInt8], length: Int) {
        
    }
}

public class SBVirtualMidiDevice {
    
    let midiChannelRange: ClosedRange<UInt8> = 1...16
    let midiValueRange: ClosedRange<UInt8> = 0...127
    
    public var delegate: SBVirtualMidiDeviceDelegate?
    var theMidiClient: MIDIClientRef = 0
    
    var midiOut: MIDIEndpointRef = 0
    var midiIn: MIDIEndpointRef = 0
    
    
    public init() {
        
        let name = "SBMidi"
        
        MIDIClientCreate(name as CFString, nil, nil, &theMidiClient)
        MIDISourceCreate(theMidiClient, name + " Out" as CFString, &midiOut)
        MIDIDestinationCreateWithBlock(theMidiClient, name + " In" as CFString, &midiIn, processIncomingMidi)
    }
    
    public init(_ name: String) {
        
        MIDIClientCreate(name as CFString, nil, nil, &theMidiClient)
        MIDISourceCreate(theMidiClient, name + " Out" as CFString, &midiOut)
        MIDIDestinationCreateWithBlock(theMidiClient, name + " In" as CFString, &midiIn, processIncomingMidi)
    }
    
    
    
    
    public func sendRawMidiMessage(_ statusByte:UInt8, _ dataByte1: UInt8, _ dataByte2: UInt8? = nil) {
        
        var midiPacket = MIDIPacket()
        midiPacket.timeStamp = 0
        midiPacket.length = dataByte2 != nil ? 3 : 2
        midiPacket.data.0 = statusByte
        midiPacket.data.1 = dataByte1
        
        if dataByte2 != nil {
        midiPacket.data.2 = dataByte2!
        }
        
        var packetList = MIDIPacketList(numPackets: 1, packet: midiPacket)
        MIDIReceived(midiOut, &packetList)
    }
    
    
    
    public func sendNoteOff(_ channel: UInt8, _ note: UInt8, _ velocity: UInt8) {
//        if midiChannelRange.contains(channel) { sendRawMidiMessage(0x80 + (channel - 1), note, velocity) }
        guard midiChannelRange.contains(channel) else { return }
        guard midiValueRange.contains(note) else { return }
        guard midiValueRange.contains(velocity) else { return }
        sendRawMidiMessage(0x80 + (channel - 1), note, velocity)
    }
    
    public func sendNoteOn(_ channel: UInt8, _ note: UInt8, _ velocity: UInt8) {
        guard midiChannelRange.contains(channel) else { return }
        guard midiValueRange.contains(note) else { return }
        guard midiValueRange.contains(velocity) else { return }
        sendRawMidiMessage(0x90 + (channel - 1), note, velocity)
    }

    public func sendPolyAftertouch(_ channel: UInt8, _ note: UInt8, _ value: UInt8) {
        guard midiChannelRange.contains(channel) else { return }
        guard midiValueRange.contains(note) else { return }
        guard midiValueRange.contains(value) else { return }
        sendRawMidiMessage(0xA0 + (channel - 1), note, value)
    }

    public func sendControlChange(_ channel: UInt8, _ controller: UInt8, _ value: UInt8) {
        guard midiChannelRange.contains(channel) else { return }
        guard midiValueRange.contains(controller) else { return }
        guard midiValueRange.contains(velocity) else { return }
        sendRawMidiMessage(0xB0 + (channel - 1), controller, value)
    }
    
    public func sendProgramChange(_ channel: UInt8, _ program: UInt8) {
        guard midiChannelRange.contains(channel) else { return }
        guard midiValueRange.contains(program) else { return }
        sendRawMidiMessage(0xC0 + (channel - 1), program)
    }
    
    public func sendMonoAftertouch(_ channel: UInt8, _ value: UInt8) {
        guard midiChannelRange.contains(channel) else { return }
        guard midiValueRange.contains(value) else { return }
        sendRawMidiMessage(0xD0 + (channel - 1), value)
    }
    
    
    public func sendPitchbend(_ channel: UInt8, _ data1: UInt8, _ data2: UInt8) {
        guard midiChannelRange.contains(channel) else { return }
        guard midiValueRange.contains(data1) else { return }
        guard midiValueRange.contains(data2) else { return }
        sendRawMidiMessage(0xE0 + (channel - 1), data1, data2)
    }
    
    public func sendSysEx(_ bytes: [UInt8]) {

        if bytes.count <= 256 {
            
            var midiPacket = MIDIPacket()
            midiPacket.timeStamp = 0
            midiPacket.length = UInt16(bytes.count)
            convertByteArrayToMidiPacketTuple(array: bytes, tuple: &midiPacket.data)
            var packetList = MIDIPacketList(numPackets: 1, packet: midiPacket)
            MIDIReceived(midiOut, &packetList)
            
        } else {
            print("SysEx message exceeded maximum packet size of 256 bytes")
        }
    }
    
    
    
    
    /// internal processing function. Converts the MIDIPacketList data into Midi messages and executes the corresponding delegate methods
    /// - Parameters:
    ///   - packetList: pointer to the midi data
    ///   - whatever: I don't know, where this pointer is pointing to. The CoreMidi docs are not very clear about that...
    private func processIncomingMidi(_ packetList: UnsafePointer<MIDIPacketList>, _ whatever: UnsafeMutableRawPointer? ) {
        
        
        var packet: MIDIPacket = packetList.pointee.packet
        
        for _ in 1...packetList.pointee.numPackets
        {
            
            // bytes mirror contains all the zero values in the packet data tuple ( = C-Array conversion)
            // so use the packet length to iterate.
            let bytes = Mirror(reflecting: packet.data).children
            var midiMsgString = ""
            
            var midiMsgArray = [UInt8]()
            midiMsgArray.reserveCapacity(Int(packet.length))
            
            var i = packet.length
            for (index, byte) in bytes.enumerated()
            {
                
                midiMsgArray.append(byte.value as! UInt8)
                midiMsgString.append(String(format:"%02X ", midiMsgArray[index]))
                
                
                i -= 1
                if (i <= 0)
                {
                    break
                }
                
            }
            
            
            delegate?.logIncomingRawMidiData(data: midiMsgArray, length: midiMsgArray.count)
            
            switch midiMsgArray[0] {
            case 0x80:
                let channel = (midiMsgArray[0] % 0x80) + 1
                delegate?.receivedNoteOff(channel: channel, note: midiMsgArray[1], velocity: midiMsgArray[2])
            case 0x90:
                let channel = (midiMsgArray[0] % 0x90) + 1
                delegate?.receivedNoteOn(channel: channel, note: midiMsgArray[1], velocity: midiMsgArray[2])
            case 0xA0:
                let channel = (midiMsgArray[0] % 0xA0) + 1
                delegate?.receivedPolyAftertouch(channel: channel, note: midiMsgArray[1], pressure: midiMsgArray[2])
            case 0xB0:
                let channel = (midiMsgArray[0] % 0xB0) + 1
                delegate?.receivedControlChange(channel: channel, controller: midiMsgArray[1], value: midiMsgArray[2])
            case 0xC0:
                let channel = (midiMsgArray[0] % 0xC0) + 1
                delegate?.receivedProgramChange(channel: channel, program: midiMsgArray[1])
            case 0xD0:
                let channel = (midiMsgArray[0] % 0xD0) + 1
                delegate?.receivedMonoAftertouch(channel: channel, pressure: midiMsgArray[1])
            case 0xE0:
                let channel = (midiMsgArray[0] % 0xE0) + 1
                delegate?.receivedPitchbend(channel: channel, data1: midiMsgArray[1], data2: midiMsgArray[2])
            case 0xF0:
                delegate?.receivedSysEx(data: midiMsgArray, length: midiMsgArray.count)
            default:
                break
            }
            
            // if more than one midi message has been sent in one packetList, load the next one
            packet = MIDIPacketNext(&packet).pointee
        }
    }

    
//    see https://forums.swift.org/t/convert-an-array-of-known-fixed-size-to-a-tuple/31432/14
    private func convertByteArrayToMidiPacketTuple<U>(array: [UInt8], tuple: UnsafeMutablePointer<U>) {
        tuple.withMemoryRebound(to: UInt8.self, capacity: array.count) {
            $0.assign(from: array, count: array.count)
        }
    }
    
    
}
