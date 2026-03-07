import AppKit
import SwiftUI
import os.log

/// Utility for safely loading NSImages that might cause CoreSVG issues
struct SafeImageLoader {
    private static let logger = AppLogger.ui
    private static var imageCache: [String: NSImage] = [:]
    private static var cacheOrder: [String] = []
    private static let maxCacheSize = 50

    /// Safely load an app icon, with fallback and caching
    static func loadAppIcon(for bundleIdentifier: String) -> NSImage? {
        // Check cache first
        if let cachedImage = imageCache[bundleIdentifier] {
            return cachedImage
        }

        guard let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return createFallbackIcon()
        }

        let appIcon = NSWorkspace.shared.icon(forFile: appUrl.path)

        // Validate the image to prevent CoreSVG issues
        let safeIcon = validateAndProcessIcon(appIcon, bundleIdentifier: bundleIdentifier)

        // Evict oldest entry if at capacity
        if imageCache.count >= maxCacheSize, let oldest = cacheOrder.first {
            imageCache.removeValue(forKey: oldest)
            cacheOrder.removeFirst()
        }

        // Cache the processed image
        imageCache[bundleIdentifier] = safeIcon
        cacheOrder.append(bundleIdentifier)

        return safeIcon
    }
    
    /// Validate and process an NSImage to prevent CoreSVG issues
    private static func validateAndProcessIcon(_ icon: NSImage, bundleIdentifier: String) -> NSImage {
        // Check if the image might be SVG-based (common source of CoreSVG errors)
        if icon.representations.contains(where: { $0 is NSPDFImageRep }) {
            logger.warning("App icon contains PDF representation (possible SVG source)", metadata: [
                "bundle_identifier": bundleIdentifier,
                "representations": String(icon.representations.count)
            ])
            
            // Convert to bitmap to avoid SVG rendering issues
            return convertToBitmap(icon) ?? createFallbackIcon()
        }
        
        // Check for unusually large images that might indicate SVG
        if icon.size.width > 512 || icon.size.height > 512 {
            logger.warning("App icon is unusually large (possible SVG)", metadata: [
                "bundle_identifier": bundleIdentifier,
                "size": "\(icon.size.width)x\(icon.size.height)"
            ])
            
            // Resize to prevent issues
            return resizeIcon(icon, to: NSSize(width: 64, height: 64)) ?? createFallbackIcon()
        }
        
        return icon
    }
    
    /// Convert an NSImage to bitmap format to avoid SVG issues
    private static func convertToBitmap(_ image: NSImage) -> NSImage? {
        let size = NSSize(width: 64, height: 64)
        
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            logger.error("Failed to create bitmap representation")
            return nil
        }
        
        let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        
        image.draw(in: NSRect(origin: .zero, size: size))
        
        NSGraphicsContext.restoreGraphicsState()
        
        let bitmapImage = NSImage(size: size)
        bitmapImage.addRepresentation(bitmapRep)
        
        logger.debug("Converted image to bitmap format")
        return bitmapImage
    }
    
    /// Resize an icon to a safe size
    private static func resizeIcon(_ image: NSImage, to size: NSSize) -> NSImage? {
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        resizedImage.unlockFocus()
        
        logger.debug("Resized image", metadata: [
            "new_size": "\(size.width)x\(size.height)"
        ])
        
        return resizedImage
    }
    
    /// Create a fallback icon when app icons can't be loaded safely
    private static func createFallbackIcon() -> NSImage {
        logger.debug("Creating fallback icon")
        
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Draw a simple rounded rectangle as fallback
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        
        NSColor.systemBlue.setFill()
        path.fill()
        
        // Add a simple app-like icon
        NSColor.white.setFill()
        let innerRect = rect.insetBy(dx: 6, dy: 6)
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 2, yRadius: 2)
        innerPath.fill()
        
        image.unlockFocus()
        
        return image
    }
    
    /// Clear the image cache (useful for memory management)
    static func clearCache() {
        imageCache.removeAll()
        cacheOrder.removeAll()
    }
}