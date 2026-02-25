import Foundation

/// General string for unknown or unavailable data.
let kUnknown = "Unknown"

/// Font face used for technical/monospaced data display.
let kMonoFontName = "JetBrains Mono Regular"
/// Standard font size for monospaced technical labels.
let kMonoFontSize: CGFloat = 12

/// Standard padding/spacing for UI layouts.
let kSpacing: CGFloat = 12

/// Endpoint for IPv4 public address lookup.
let kIpifyV4Url = "https://api.ipify.org?format=json"
/// Endpoint for dual-stack/IPv6 public address lookup.
let kIpifyV6Url = "https://api64.ipify.org?format=json"

/// Base URL for the MAC vendor lookup API.
/// Used for mapping OUI (Organizationally Unique Identifier) to vendor names.
let kMacVendorsBaseUrl = "https://api.macvendors.com/"

/// Fallback string when vendor lookup fails or return no results.
let kUnknownVendor = "Unknown Vendor"
/// Error message string for failed vendor API calls.
let kVendorLookupFailed = "Lookup failed"

// MARK: - SystemConfiguration Keys

/// SC Dynamic Store key for global IPv4 network state.
/// Reference: SystemConfiguration framework.
let kSCDynamicStoreGlobalIPv4 = "State:/Network/Global/IPv4"

/// Dictionary key for the primary interface name in SCDynamicStore.
let kSCKeyPrimaryInterface = "PrimaryInterface"

/// Dictionary key for the default gateway/router address in SCDynamicStore.
let kSCKeyRouter = "Router"
