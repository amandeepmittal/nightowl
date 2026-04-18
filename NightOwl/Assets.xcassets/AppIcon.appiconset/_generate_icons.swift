#!/usr/bin/env swift
//
// NightOwl icon generator (v2 minimal). Run once:
//   swift NightOwl/Assets.xcassets/AppIcon.appiconset/_generate_icons.swift
//
// Writes the 10 macOS AppIcon PNGs and the 3 MenuBarIcon PNGs. Outputs are
// resolved relative to this file's own path (#filePath), so cwd does not matter.
//
// Concept: "glowing eyes in the dark." The icon is a flat deep-indigo squircle
// with two amber eyes and small dark pupils. That is the entire composition.
// Menu bar icon is two small solid template dots.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: Palette

func hex(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    let r = CGFloat((h >> 16) & 0xFF) / 255
    let g = CGFloat((h >> 8) & 0xFF) / 255
    let b = CGFloat(h & 0xFF) / 255
    return CGColor(red: r, green: g, blue: b, alpha: a)
}

let bgIndigo  = hex(0x1A1038)   // squircle background AND pupil fill
let eyeAmber  = hex(0xF5C15A)
let black     = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

// MARK: Bitmap helpers

func newContext(_ size: Int) -> CGContext {
    let cs = CGColorSpaceCreateDeviceRGB()
    let info = CGImageAlphaInfo.premultipliedLast.rawValue
    return CGContext(data: nil, width: size, height: size,
                     bitsPerComponent: 8, bytesPerRow: 0,
                     space: cs, bitmapInfo: info)!
}

func savePNG(_ cg: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     UTType.png.identifier as CFString,
                                                     1, nil) else {
        FileHandle.standardError.write("cannot open \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    CGImageDestinationAddImage(dest, cg, nil)
    if !CGImageDestinationFinalize(dest) {
        FileHandle.standardError.write("finalize failed \(path)\n".data(using: .utf8)!)
        exit(1)
    }
}

// Superellipse path: |x|^n + |y|^n = r^n, approximating macOS Big Sur squircle.
func squirclePath(center: CGPoint, radius: CGFloat, n: Double = 5) -> CGPath {
    let path = CGMutablePath()
    let steps = 720
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = copysign(pow(abs(ct), 2.0/n), ct) * Double(radius) + Double(center.x)
        let y = copysign(pow(abs(st), 2.0/n), st) * Double(radius) + Double(center.y)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
        else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

// MARK: App icon (v2 minimal: flat indigo squircle + two amber eyes)

func drawAppIcon(at size: CGFloat) -> CGImage {
    let ctx = newContext(Int(size))
    let s = size

    // Big Sur grid: inner icon occupies 824/1024 of canvas.
    let iconRadius = s * 0.402
    let center = CGPoint(x: s/2, y: s/2)

    // Squircle fill (flat indigo).
    ctx.addPath(squirclePath(center: center, radius: iconRadius, n: 5))
    ctx.setFillColor(bgIndigo)
    ctx.fillPath()

    // Proportions matched to 1024 spec:
    //   eye diameter 240 → radius 120 (0.1172 * s)
    //   gap between inner edges 80 → eye center offset 160 from canvas center (0.1563 * s)
    //   pupil diameter 60 → radius 30 (0.0293 * s)
    // Eyes sit 2% above canvas center for a subtle face-like placement.
    let eyeR  = s * 0.1172
    let eyeDX = s * 0.1563
    let eyeCy = s * 0.52

    // Two amber eyes.
    ctx.setFillColor(eyeAmber)
    for sign: CGFloat in [-1, 1] {
        let cx = s/2 + sign * eyeDX
        ctx.fillEllipse(in: CGRect(x: cx - eyeR, y: eyeCy - eyeR,
                                   width: eyeR*2, height: eyeR*2))
    }

    // Small dark pupils. Skip at 16/32 where they'd be subpixel.
    if s >= 64 {
        let pupilR = s * 0.0293
        ctx.setFillColor(bgIndigo)
        for sign: CGFloat in [-1, 1] {
            let cx = s/2 + sign * eyeDX
            ctx.fillEllipse(in: CGRect(x: cx - pupilR, y: eyeCy - pupilR,
                                       width: pupilR*2, height: pupilR*2))
        }
    }

    return ctx.makeImage()!
}

// MARK: Menu bar icon (v2 minimal: two solid template dots)

func drawMenuBar(at size: Int) -> CGImage {
    let ctx = newContext(size)
    let s = CGFloat(size)

    // At 18 px: diameter 6, radius 3 (0.1667 * s).
    //          horizontal gap 2 → centers at ±4 from middle (0.2222 * s).
    let dotR  = s * 0.1667
    let dotDX = s * 0.2222
    let dotCy = s / 2

    ctx.setFillColor(black)
    for sign: CGFloat in [-1, 1] {
        let cx = s/2 + sign * dotDX
        ctx.fillEllipse(in: CGRect(x: cx - dotR, y: dotCy - dotR,
                                   width: dotR*2, height: dotR*2))
    }

    return ctx.makeImage()!
}

// MARK: Downsampler

func downsample(_ master: CGImage, to size: Int) -> CGImage {
    let ctx = newContext(size)
    ctx.interpolationQuality = .high
    ctx.draw(master, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()!
}

// MARK: Main

let scriptURL = URL(fileURLWithPath: #filePath)
let appIconDir = scriptURL.deletingLastPathComponent()
let menuBarDir = appIconDir.deletingLastPathComponent()
    .appendingPathComponent("MenuBarIcon.imageset")

func ai(_ name: String) -> String {
    appIconDir.appendingPathComponent(name).path
}
func mb(_ name: String) -> String {
    menuBarDir.appendingPathComponent(name).path
}

// 1024 master → downsamples for 512, 256, 128, 64.
let master1024 = drawAppIcon(at: 1024)
savePNG(master1024,                       to: ai("icon_512x512@2x.png")) // 1024
savePNG(downsample(master1024, to: 512),  to: ai("icon_512x512.png"))
savePNG(downsample(master1024, to: 512),  to: ai("icon_256x256@2x.png"))
savePNG(downsample(master1024, to: 256),  to: ai("icon_256x256.png"))
savePNG(downsample(master1024, to: 256),  to: ai("icon_128x128@2x.png"))
savePNG(downsample(master1024, to: 128),  to: ai("icon_128x128.png"))
savePNG(downsample(master1024, to: 64),   to: ai("icon_32x32@2x.png"))

// 32 and 16 render natively (no pupils — they'd be subpixel).
let master32 = drawAppIcon(at: 32)
savePNG(master32, to: ai("icon_32x32.png"))
savePNG(master32, to: ai("icon_16x16@2x.png"))
let master16 = drawAppIcon(at: 16)
savePNG(master16, to: ai("icon_16x16.png"))

// Menu bar: three native sizes.
savePNG(drawMenuBar(at: 18), to: mb("menu_bar_icon.png"))
savePNG(drawMenuBar(at: 36), to: mb("menu_bar_icon@2x.png"))
savePNG(drawMenuBar(at: 54), to: mb("menu_bar_icon@3x.png"))

print("OK")
