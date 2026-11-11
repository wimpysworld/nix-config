// render_midi_macos.swift
// Render a Standard MIDI File to a WAV using macOS's built-in General MIDI
// synthesiser (the Apple DLS soundbank that GarageBand / QuickTime use).
//
// WHY THIS EXISTS
// ---------------
// When the live REAPER MCP bridge is unavailable or flaky, you can still turn
// MIDI into *real-instrument* audio with zero downloads. fluidsynth needs an
// .sf2 soundfont (and fetching one is often blocked on locked-down machines).
// macOS already ships a GM soundbank at:
//   /System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls
// fluidsynth can't read .dls, but CoreAudio's DLSMusicDevice plays it natively.
// This tool drives that synth offline (faster than real time) and writes a WAV.
//
// It is multi-timbral GM: program changes select instruments per channel, and
// MIDI channel 10 (index 9) is the drum kit. So a single GM MIDI file with
// program changes + a drum channel renders as a full band.
//
// BUILD & RUN
// -----------
//   swiftc -O render_midi_macos.swift -o render_midi_macos
//   ./render_midi_macos input.mid output.wav
//
// Then mix / master with ffmpeg, e.g. add a fade and normalise loudness:
//   ffmpeg -i output.wav -af "loudnorm=I=-14:TP=-1.0,afade=t=out:st=68:d=3" final.wav
//
// macOS only (uses AudioToolbox). Tested on macOS with Swift 6.x.

import Foundation
import AudioToolbox

func check(_ status: OSStatus, _ label: String) {
    if status != noErr {
        FileHandle.standardError.write("ERROR \(label): \(status)\n".data(using: .utf8)!)
        exit(1)
    }
}

guard CommandLine.arguments.count >= 3 else {
    FileHandle.standardError.write("usage: render_midi_macos input.mid output.wav\n".data(using: .utf8)!)
    exit(2)
}
let midiPath = CommandLine.arguments[1]
let outPath  = CommandLine.arguments[2]
let sampleRate = 44100.0

// 1. Load the MIDI file into a MusicSequence.
var sequence: MusicSequence!
check(NewMusicSequence(&sequence), "NewMusicSequence")
check(MusicSequenceFileLoad(sequence, URL(fileURLWithPath: midiPath) as CFURL,
                            .midiType, MusicSequenceLoadFlags(rawValue: 0)), "FileLoad")

// 2. Build an AUGraph: Apple DLS GM synth -> GenericOutput (offline pull render).
var graph: AUGraph!
check(NewAUGraph(&graph), "NewAUGraph")

var synthDesc = AudioComponentDescription(
    componentType: kAudioUnitType_MusicDevice,
    componentSubType: kAudioUnitSubType_DLSSynth,
    componentManufacturer: kAudioUnitManufacturer_Apple,
    componentFlags: 0, componentFlagsMask: 0)
var synthNode = AUNode()
check(AUGraphAddNode(graph, &synthDesc, &synthNode), "AddSynth")

var outDesc = AudioComponentDescription(
    componentType: kAudioUnitType_Output,
    componentSubType: kAudioUnitSubType_GenericOutput,
    componentManufacturer: kAudioUnitManufacturer_Apple,
    componentFlags: 0, componentFlagsMask: 0)
var outNode = AUNode()
check(AUGraphAddNode(graph, &outDesc, &outNode), "AddOut")

check(AUGraphOpen(graph), "GraphOpen")
check(AUGraphConnectNodeInput(graph, synthNode, 0, outNode, 0), "Connect")

var synthUnit: AudioUnit!
check(AUGraphNodeInfo(graph, synthNode, nil, &synthUnit), "SynthInfo")
var outUnit: AudioUnit!
check(AUGraphNodeInfo(graph, outNode, nil, &outUnit), "OutInfo")

// 3. Float32, non-interleaved, stereo on both ends of the connection.
var fmt = AudioStreamBasicDescription(
    mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
    mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
    mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
    mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0)
let fsz = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
check(AudioUnitSetProperty(synthUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &fmt, fsz), "SynthFmt")
check(AudioUnitSetProperty(outUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &fmt, fsz), "OutFmt")

check(MusicSequenceSetAUGraph(sequence, graph), "SetAUGraph")
check(AUGraphInitialize(graph), "GraphInit")

// 4. Work out the length (longest track), in seconds, plus a release tail.
var nTracks: UInt32 = 0
check(MusicSequenceGetTrackCount(sequence, &nTracks), "TrackCount")
var maxBeats: MusicTimeStamp = 0
for i in 0..<nTracks {
    var tr: MusicTrack!
    MusicSequenceGetIndTrack(sequence, i, &tr)
    var len: MusicTimeStamp = 0
    var sz = UInt32(MemoryLayout<MusicTimeStamp>.size)
    MusicTrackGetProperty(tr, kSequenceTrackProperty_TrackLength, &len, &sz)
    if len > maxBeats { maxBeats = len }
}
var endSec: Float64 = 0
MusicSequenceGetSecondsForBeats(sequence, maxBeats, &endSec)
let totalFrames = Int((endSec + 3.0) * sampleRate)

// 5. A MusicPlayer drives the sequence; because the output is GenericOutput,
//    its sample-time (which we advance manually below) becomes the clock, so
//    rendering runs as fast as the CPU allows.
var player: MusicPlayer!
check(NewMusicPlayer(&player), "NewPlayer")
check(MusicPlayerSetSequence(player, sequence), "SetSeq")
check(MusicPlayerPreroll(player), "Preroll")
check(MusicPlayerStart(player), "Start")

// 6. Output: 16-bit stereo WAV. ExtAudioFile converts from our float client format.
var fileFmt = AudioStreamBasicDescription(
    mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
    mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
    mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
    mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0)
var extFile: ExtAudioFileRef!
check(ExtAudioFileCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, kAudioFileWAVEType,
                                &fileFmt, nil, AudioFileFlags.eraseFile.rawValue, &extFile), "CreateFile")
check(ExtAudioFileSetProperty(extFile, kExtAudioFileProperty_ClientDataFormat, fsz, &fmt), "ClientFmt")

// 7. Pull/render loop.
let block = 512
let bufL = UnsafeMutableRawPointer.allocate(byteCount: block*4, alignment: 16)
let bufR = UnsafeMutableRawPointer.allocate(byteCount: block*4, alignment: 16)
let abl = AudioBufferList.allocate(maximumBuffers: 2)
abl[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(block*4), mData: bufL)
abl[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(block*4), mData: bufR)

var ts = AudioTimeStamp()
ts.mFlags = .sampleTimeValid
ts.mSampleTime = 0

var rendered = 0
while rendered < totalFrames {
    let n = min(block, totalFrames - rendered)
    abl[0].mDataByteSize = UInt32(n*4)
    abl[1].mDataByteSize = UInt32(n*4)
    var flags = AudioUnitRenderActionFlags()
    check(AudioUnitRender(outUnit, &flags, &ts, 0, UInt32(n), abl.unsafeMutablePointer), "Render@\(rendered)")
    check(ExtAudioFileWrite(extFile, UInt32(n), abl.unsafeMutablePointer), "Write@\(rendered)")
    rendered += n
    ts.mSampleTime += Float64(n)
}

bufL.deallocate(); bufR.deallocate(); free(abl.unsafeMutablePointer)
MusicPlayerStop(player)
ExtAudioFileDispose(extFile)
DisposeMusicPlayer(player)
DisposeAUGraph(graph)
DisposeMusicSequence(sequence)
print("rendered \(rendered) frames (\(Double(rendered)/sampleRate)s) -> \(outPath)")
