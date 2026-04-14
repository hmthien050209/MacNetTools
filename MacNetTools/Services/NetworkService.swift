import Foundation
import SystemConfiguration

class NetworkService: @unchecked Sendable {

  func getBasicNetModel(interfaceName: String? = nil) async -> BasicNetModel? {
    let name: String
    if let provided = interfaceName {
      name = provided
    } else if let primary = primaryInterfaceName() {
      name = primary
    } else {
      return nil
    }

    let (addrInfo, networkDetails) = await withCheckedContinuation {
      continuation in
      DispatchQueue.global(qos: .userInitiated).async { [self] in
        let addr = self.getInterfaceAddressInfo(for: name)
        let details = self.getSystemConfigurationInfo(for: name)
        continuation.resume(returning: (addr, details))
      }
    }

    async let ipV4 = getPublicIp(apiUrl: kIpifyV4Url)
    async let ipV6 = getPublicIp(apiUrl: kIpifyV6Url)

    return BasicNetModel(
      mtu: networkDetails.mtu,
      localIp: addrInfo.ip ?? "0.0.0.0",
      routerIp: networkDetails.router ?? "0.0.0.0",
      subnetMask: addrInfo.subnet ?? "255.255.255.0",
      publicIpV4: await ipV4 ?? "",
      publicIpV6: await ipV6 ?? "",
    )
  }

  // MARK: - Private helpers

  private func primaryInterfaceName() -> String? {
    guard
      let store = SCDynamicStoreCreate(
        nil,
        "MacNetTools" as CFString,
        nil,
        nil
      )
    else { return nil }

    if let dict = SCDynamicStoreCopyValue(
      store,
      kSCDynamicStoreGlobalIPv4 as CFString
    ) as? [String: Any],
      let iface = dict[kSCKeyPrimaryInterface] as? String
    {
      return iface
    }
    return nil
  }

  private func getPublicIp(apiUrl: String) async -> String? {
    guard let url = URL(string: apiUrl) else { return nil }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      let result = try JSONDecoder().decode(Ipify.self, from: data)
      return result.ip
    } catch {
      return nil
    }
  }

  private func getSystemConfigurationInfo(for interfaceName: String) -> (
    router: String?, mtu: String
  ) {
    var router: String?
    var mtu = kUnknown

    guard
      let dynamicStore = SCDynamicStoreCreate(
        nil,
        "MacNetTools" as CFString,
        nil,
        nil
      )
    else {
      return (nil, mtu)
    }

    if let dict = SCDynamicStoreCopyValue(
      dynamicStore,
      kSCDynamicStoreGlobalIPv4 as CFString
    ) as? [String: Any],
      let gateway = dict[kSCKeyRouter] as? String
    {
      router = gateway
    }

    guard
      let interfaces = SCNetworkInterfaceCopyAll()
        as? [SCNetworkInterface]
    else {
      return (router, mtu)
    }

    for interface in interfaces {
      if let bsdName = SCNetworkInterfaceGetBSDName(interface) as String?,
        bsdName == interfaceName
      {
        var currentMTU: Int32 = 0
        if SCNetworkInterfaceCopyMTU(interface, &currentMTU, nil, nil) {
          mtu = String(currentMTU)
        }
        break
      }
    }

    return (router, mtu)
  }

  private func getInterfaceAddressInfo(for interfaceName: String) -> (
    ip: String?, subnet: String?
  ) {
    var address: String?
    var subnet: String?

    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
      return (nil, nil)
    }

    defer { freeifaddrs(ifaddr) }

    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
      let interface = ptr.pointee
      let addr = interface.ifa_addr.pointee

      guard addr.sa_family == UInt8(AF_INET) else { continue }
      let name = String(cString: interface.ifa_name)
      guard name == interfaceName else { continue }

      let flags = Int32(interface.ifa_flags)
      guard (flags & IFF_UP) != 0 else { continue }

      var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      if getnameinfo(
        interface.ifa_addr,
        socklen_t(addr.sa_len),
        &hostname,
        socklen_t(hostname.count),
        nil,
        socklen_t(0),
        NI_NUMERICHOST
      ) == 0 {
        address = String(cString: hostname)
      }

      if let netmask = interface.ifa_netmask {
        var netmaskName = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(
          netmask,
          socklen_t(netmask.pointee.sa_len),
          &netmaskName,
          socklen_t(netmaskName.count),
          nil,
          socklen_t(0),
          NI_NUMERICHOST
        ) == 0 {
          subnet = String(cString: netmaskName)
        }
      }

      if address != nil { break }
    }

    return (address, subnet)
  }
}
