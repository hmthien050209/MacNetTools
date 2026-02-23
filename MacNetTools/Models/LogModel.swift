struct LogModel {
    var logEntries: Array<String>
}

enum LogScope {
    case sys
    case net
    case wifi
    case traceroute
    case speedtest
}
