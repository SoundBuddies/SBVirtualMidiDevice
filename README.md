# SBVirtualMidiDevice

This is a simple Swift package for creating a virtual midi device in macOS. This should als work for iOS but has not yet been tested. The usage is straight forward. Create an instance of the class, optionally name your virtual midi device with init(_ name:). Use the delegate protocol to receive and process incoming midi messages. 

Here is a full example:

    import Foundation
    import CoreMidi
    
    let midi devi
    
