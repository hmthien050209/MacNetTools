import CoreWLAN
import Foundation

actor VendorCache {
  private var cache: [String: String] = [:]

  func get(_ bssid: String) -> String? {
    return cache[bssid]
  }

  func set(_ name: String, for bssid: String) {
    cache[bssid] = name
  }
}

private struct ScannedNetworkData: Sendable {
  let ssid: String
  let bssid: String
  let rssi: Int
  let channelNumber: Int
  let band: String
  let phyMode: String
  let informationElementData: Data?
}

class WiFiService: @unchecked Sendable {
  private let vendorCache = VendorCache()

  private var lastConnectedSSID: String?
  private var lastConnectedBSSID: String?

  func getWiFiModel(interfaceName: String? = nil) async -> WiFiModel? {
    guard let interface = getWiFiInterface(interfaceName: interfaceName) else {
      return nil
    }

    let rssi = interface.rssiValue()
    let noise = interface.noiseMeasurement()
    let signalNoiseRatio = rssi - noise
    let ssid = interface.ssid() ?? kUnknown
    let connectedBssid = interface.bssid()?.uppercased() ?? kUnknown
    let channel = interface.wlanChannel()
    let primaryChannelNumber = channel?.channelNumber ?? 0
    let phyMode = interface.activePHYMode()
    let security = interface.security()
    let countryCode = interface.countryCode() ?? kUnknown
    let txRate = interface.transmitRate()
    let ifName = interface.interfaceName

    let allScannedNetworks = await scanNetworksInBackground()
    let scannedNetworksWithSameSSID = allScannedNetworks.filter { $0.ssid == ssid }

    let connectionChanged = lastConnectedSSID != ssid || lastConnectedBSSID != connectedBssid
    let shouldParseIE = connectionChanged || lastConnectedSSID == nil
    
    var encryptionInfo: String? = nil
    var bssLoad: BSSLoadInfo? = nil
    var vendorSpecificIEs: [VendorSpecificIE] = []
    var secondaryChannelOffset: String? = nil
    var secondaryChannels: [Int] = []
    
    if shouldParseIE,
      let currentData = scannedNetworksWithSameSSID.first(where: { $0.bssid == connectedBssid }),
      let ieData = currentData.informationElementData
    {
      let ies = WiFiIEParser.parseInformationElements(ieData)
      
      if let securityInfo = WiFiIEParser.extractCipherInfo(from: ies) {
        let group = securityInfo.group ?? kUnknown
        let pairwise = securityInfo.pairwise.isEmpty ? "None" : securityInfo.pairwise.joined(separator: ", ")
        let akms = securityInfo.akms.isEmpty ? "None" : securityInfo.akms.joined(separator: ", ")
        encryptionInfo = "AKM: \(akms); Pairwise: \(pairwise); Group: \(group)"
      }
      
      bssLoad = WiFiIEParser.extractBSSLoad(from: ies)
      vendorSpecificIEs = WiFiIEParser.extractVendorSpecificIEs(from: ies)
      secondaryChannelOffset = WiFiIEParser.extractSecondaryChannelOffset(from: ies)
      secondaryChannels = WiFiIEParser.extractSecondaryChannels(
        primaryChannel: primaryChannelNumber,
        ies: ies
      )
    }

    lastConnectedSSID = ssid
    lastConnectedBSSID = connectedBssid

    async let fetchedNearbyNetworks = buildNearbyWiFiWithMetadata(
      from: allScannedNetworks,
      connectedBssid: connectedBssid
    )
    async let fetchedVendor = fetchVendorName(bssid: connectedBssid)
    async let fetchedAvailableBssidsWithVendors = buildBSSIDsWithMetadata(
      from: scannedNetworksWithSameSSID,
      connectedBssid: connectedBssid
    )
    
    let (vendor, availableBssidsWithVendors, nearbyNetworks) = await (
      fetchedVendor, fetchedAvailableBssidsWithVendors, fetchedNearbyNetworks
    )
    
    return WiFiModel(
      ssid: ssid,
      connectedBssid: connectedBssid,
      vendor: vendor,
      channelDescription: channel?.detailedDescription ?? kUnknown,
      phyModeDescription: phyMode.description,
      securityDescription: String(describing: security),
      rssi: rssi,
      noise: noise,
      signalNoiseRatio: signalNoiseRatio,
      countryCode: countryCode,
      availableBssidsWithVendors: availableBssidsWithVendors,
      txRateMbps: txRate,
      interfaceName: ifName,
      encryptionInfo: encryptionInfo ?? kUnknown,
      bssLoadStationCount: bssLoad?.stationCount ?? 0,
      bssLoadUtilization: bssLoad?.channelUtilization ?? 0,
      bssLoadCapacity: bssLoad?.availableCapacity ?? 0,
      vendorSpecificIEs: vendorSpecificIEs,
      secondaryChannelOffset: secondaryChannelOffset,
      secondaryChannels: secondaryChannels,
      nearbyNetworks: nearbyNetworks
    )
  }

  private func getWiFiInterface(interfaceName: String? = nil) -> CWInterface? {
    let client = CWWiFiClient.shared()
    return interfaceName.flatMap({ client.interface(withName: $0) }) ?? client.interface()
  }

  private func scanNetworksInBackground() async -> [ScannedNetworkData] {
    await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        guard let iface = CWWiFiClient.shared().interface(),
          let networks = try? iface.scanForNetworks(withSSID: nil)
        else {
          continuation.resume(returning: [])
          return
        }
        let results = networks.map { network in
          let phy = WiFiService.getPHYMode(for: network)
          return ScannedNetworkData(
            ssid: network.ssid ?? "",
            bssid: network.bssid?.uppercased() ?? "",
            rssi: network.rssiValue,
            channelNumber: network.wlanChannel?.channelNumber ?? 0,
            band: network.wlanChannel?.channelBand.description
              ?? kUnknown,
            phyMode: phy,
            informationElementData: network.informationElementData
          )
        }
        continuation.resume(returning: results)
      }
    }
  }

  private func buildNearbyWiFiWithMetadata(
    from scannedNetworks: [ScannedNetworkData],
    connectedBssid: String
  ) async -> [NearbyWiFiNetwork] {
    await withTaskGroup(of: (Int, NearbyWiFiNetwork).self) { group in
      let validNetworks = scannedNetworks.enumerated().filter {
        !$0.element.bssid.isEmpty && !$0.element.ssid.isEmpty
      }

      for (index, data) in validNetworks {
        group.addTask {
          let vendor = await self.fetchVendorName(
            bssid: data.bssid, staggerIndex: index
          )
          let network = NearbyWiFiNetwork(
            ssid: data.ssid,
            bssid: data.bssid,
            vendor: vendor,
            channel: data.channelNumber,
            band: data.band,
            phyMode: data.phyMode,
            rssi: data.rssi,
            isConnected: data.bssid == connectedBssid
          )
          return (index, network)
        }
      }

      var results = [(Int, NearbyWiFiNetwork)]()
      for await result in group {
        results.append(result)
      }
      return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
    }
  }

  private func buildBSSIDsWithMetadata(
    from scannedNetworks: [ScannedNetworkData],
    connectedBssid: String
  ) async -> [NearbyWiFiNetwork] {
    await withTaskGroup(of: (Int, NearbyWiFiNetwork).self) { group in
      let validNetworks = scannedNetworks.enumerated().filter {
        !$0.element.bssid.isEmpty
      }

      for (index, data) in validNetworks {
        group.addTask {
          let vendor = await self.fetchVendorName(bssid: data.bssid)
          let network = NearbyWiFiNetwork(
            ssid: data.ssid,
            bssid: data.bssid,
            vendor: vendor,
            channel: data.channelNumber,
            band: data.band,
            phyMode: data.phyMode,
            rssi: data.rssi,
            isConnected: data.bssid == connectedBssid
          )
          return (index, network)
        }
      }

      var results = [(Int, NearbyWiFiNetwork)]()
      for await result in group {
        results.append(result)
      }
      return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
    }
  }

  func fetchVendorName(bssid: String?, staggerIndex: Int = 0) async -> String {
    guard let bssid = bssid, !bssid.isEmpty else {
      return ""
    }

    if let cached = await vendorCache.get(bssid),
      cached != kVendorLookupFailed
    {
      return cached
    }

    guard let url = URL(string: "\(kMacVendorsBaseUrl)\(bssid)")
    else { return "" }

    var retryCount = 0
    let maxRetries = 2

    while retryCount <= maxRetries {
      do {
        if retryCount == 0 {
          let delayMs = UInt64(staggerIndex % 10) * 100_000_000
          try? await Task.sleep(nanoseconds: delayMs)
        }

        let (data, response) = try await URLSession.shared.data(
          from: url
        )
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 200 {
          let name =
            String(data: data, encoding: .utf8) ?? kUnknownVendor
          await vendorCache.set(name, for: bssid)
          return name
        } else if statusCode == 404 {
          await vendorCache.set(kUnknownVendor, for: bssid)
          return kUnknownVendor
        } else if statusCode == 429 {
          retryCount += 1
          if retryCount <= maxRetries {
            try? await Task.sleep(
              nanoseconds: UInt64(retryCount) * 1_000_000_000
            )
            continue
          }
        }

        return ""
      } catch {
        retryCount += 1
        if retryCount <= maxRetries {
          try? await Task.sleep(nanoseconds: 500_000_000)
          continue
        }
        return ""
      }
    }

    return ""
  }

  private static func getPHYMode(for network: CWNetwork) -> String {
    if network.supportsPHYMode(.mode11ax) {
      return CWPHYMode.mode11ax.description
    }
    if network.supportsPHYMode(.mode11ac) {
      return CWPHYMode.mode11ac.description
    }
    if network.supportsPHYMode(.mode11n) {
      return CWPHYMode.mode11n.description
    }
    if network.supportsPHYMode(.mode11g) {
      return CWPHYMode.mode11g.description
    }
    if network.supportsPHYMode(.mode11a) {
      return CWPHYMode.mode11a.description
    }
    if network.supportsPHYMode(.mode11b) {
      return CWPHYMode.mode11b.description
    }
    return "Unknown"
  }
}
