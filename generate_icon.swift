#!/usr/bin/env swift
// generate_icon.swift  –  Draws DockClick's app icon at 1024×1024 and writes it to the path given as argv[1].
import Foundation
import CoreGraphics
import CoreText
import ImageIO

let S = 1024
let s = CGFloat(S)
let cs = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(
    data: nil, width: S, height: S,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("CGContext creation failed") }

// ── Rounded-rect clip (macOS app-icon shape) ──────────────────────────────
let corner = s * 0.22
let bgPath = CGMutablePath()
bgPath.addRoundedRect(in: CGRect(x: 0, y: 0, width: s, height: s),
                       cornerWidth: corner, cornerHeight: corner)
ctx.addPath(bgPath)
ctx.clip()

// ── Gradient background: deep navy → indigo ───────────────────────────────
let gradColors = [
    CGColor(red: 0.05, green: 0.05, blue: 0.26, alpha: 1),   // navy  (bottom-left)
    CGColor(red: 0.20, green: 0.07, blue: 0.44, alpha: 1)    // indigo (top-right)
] as CFArray
if let grad = CGGradient(colorsSpace: cs, colors: gradColors, locations: [0, 1] as [CGFloat]) {
    ctx.drawLinearGradient(grad,
        start: CGPoint(x: 0, y: 0), end: CGPoint(x: s, y: s), options: [])
}

// ── Subtle inner glow at top ──────────────────────────────────────────────
let glowColors = [
    CGColor(red: 0.55, green: 0.40, blue: 1.0, alpha: 0.18),
    CGColor(red: 0.55, green: 0.40, blue: 1.0, alpha: 0.0)
] as CFArray
if let glowGrad = CGGradient(colorsSpace: cs, colors: glowColors, locations: [0, 1] as [CGFloat]) {
    ctx.drawRadialGradient(glowGrad,
        startCenter: CGPoint(x: s * 0.5, y: s * 0.92), startRadius: 0,
        endCenter:   CGPoint(x: s * 0.5, y: s * 0.92), endRadius: s * 0.7,
        options: [])
}

// ── Dock bar ──────────────────────────────────────────────────────────────
let dH = s * 0.095
let dY = s * 0.085
let dockRect = CGRect(x: s * 0.09, y: dY, width: s * 0.82, height: dH)
let dockPath = CGMutablePath()
dockPath.addRoundedRect(in: dockRect, cornerWidth: dH / 2, cornerHeight: dH / 2)
ctx.addPath(dockPath)
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
ctx.fillPath()

// Mini app icons inside the dock bar
typealias RGB = (CGFloat, CGFloat, CGFloat)
let dotColors: [RGB] = [
    (0.30, 0.65, 1.00),   // blue
    (0.35, 0.88, 0.55),   // green
    (1.00, 0.42, 0.38),   // red
    (1.00, 0.72, 0.20),   // yellow
    (0.78, 0.48, 1.00)    // purple
]
let dotR = dH * 0.26
for (i, c) in dotColors.enumerated() {
    let cx = s * (0.215 + CGFloat(i) * 0.152)
    let cy = dY + dH / 2
    ctx.addEllipse(in: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))
    ctx.setFillColor(CGColor(red: c.0, green: c.1, blue: c.2, alpha: 0.92))
    ctx.fillPath()
}

// ── Helper: draw text centred at a point ─────────────────────────────────
func drawCentred(_ text: String, font: CTFont, color: CGColor, at centre: CGPoint) {
    let attrs: NSDictionary = [
        kCTFontAttributeName: font,
        kCTForegroundColorFromContextAttributeName: kCFBooleanTrue!
    ]
    let attrStr = CFAttributedStringCreate(kCFAllocatorDefault, text as CFString, attrs)!
    let line = CTLineCreateWithAttributedString(attrStr)
    let b = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
    ctx.setFillColor(color)
    ctx.textPosition = CGPoint(
        x: centre.x - b.width / 2 - b.origin.x,
        y: centre.y - b.height / 2 - b.origin.y
    )
    CTLineDraw(line, ctx)
}

// ── ⌘ symbol ─────────────────────────────────────────────────────────────
let cmdFont = CTFontCreateWithName("Helvetica" as CFString, s * 0.46, nil)
drawCentred("⌘", font: cmdFont,
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.93),
            at: CGPoint(x: s * 0.48, y: s * 0.50))

// ── Orange + badge ────────────────────────────────────────────────────────
let bR  = s * 0.135
let bCX = s * 0.725
let bCY = s * 0.725

// Circle fill
ctx.addEllipse(in: CGRect(x: bCX - bR, y: bCY - bR, width: bR * 2, height: bR * 2))
ctx.setFillColor(CGColor(red: 1.0, green: 0.48, blue: 0.0, alpha: 1.0))
ctx.fillPath()

// Thin white border
ctx.addEllipse(in: CGRect(x: bCX - bR, y: bCY - bR, width: bR * 2, height: bR * 2))
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.55))
ctx.setLineWidth(s * 0.010)
ctx.strokePath()

// "+" glyph
let plusFont = CTFontCreateWithName("Helvetica-Bold" as CFString, bR * 1.1, nil)
drawCentred("+", font: plusFont,
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
            at: CGPoint(x: bCX, y: bCY + bR * 0.05))

// ── Write PNG ─────────────────────────────────────────────────────────────
guard let image = ctx.makeImage() else { fatalError("makeImage failed") }
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let outURL  = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil)
else { fatalError("Cannot create image destination") }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("CGImageDestinationFinalize failed") }
print("✓ Icon written to \(outPath)")
