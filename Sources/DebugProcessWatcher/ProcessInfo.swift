import Foundation

struct ProcessInfo: Identifiable, Hashable {
    let pid: Int
    let name: String
    let command: String
    let address: String
    let port: Int
    let proto: String
    let language: String
    let cwd: String
    let cpu: String
    let mem: String

    var id: String { "\(pid)_\(port)_\(address)" }
}
