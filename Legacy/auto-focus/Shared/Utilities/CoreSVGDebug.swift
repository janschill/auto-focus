import Foundation
import os.log

/// Utility for debugging CoreSVG issues
struct CoreSVGDebugger {
    private static let logger = AppLogger.ui
    
    /// Enable CoreSVG verbose logging by setting environment variable
    static func enableVerboseLogging() {
        setenv("CORESVG_VERBOSE", "1", 1)
        logger.info("CoreSVG verbose logging enabled", metadata: [
            "environment_variable": "CORESVG_VERBOSE=1"
        ])
    }
    
    /// Check for common CoreSVG issues and log diagnostics
    static func performDiagnostics() {
        logger.info("Performing CoreSVG diagnostics")
        
        // Check for SVG files in bundle
        let bundle = Bundle.main
        let svgFiles = bundle.paths(forResourcesOfType: "svg", inDirectory: nil)
        
        logger.info("Found SVG files in bundle", metadata: [
            "svg_count": String(svgFiles.count),
            "svg_files": svgFiles.joined(separator: ", ")
        ])
        
        // Check for system SVG resources that might be causing issues
        checkSystemImageUsage()
    }
    
    private static func checkSystemImageUsage() {
        // Log system image usage patterns that commonly cause CoreSVG errors
        logger.info("Checking system image usage patterns", metadata: [
            "recommendation": "Use SF Symbols when possible instead of custom SVG"
        ])
        
        // Check for common problematic patterns
        logger.info("Common CoreSVG error sources", metadata: [
            "app_icons": "NSWorkspace.shared.icon() can return SVG-based icons",
            "custom_images": "Image(nsImage:) with dynamic content may cause issues",
            "solution": "Cache and validate NSImage content before creating SwiftUI Images"
        ])
    }
    
    /// Call this in your app delegate to set up CoreSVG debugging
    static func setupDebugging() {
        #if DEBUG
        enableVerboseLogging()
        performDiagnostics()
        #endif
    }
}