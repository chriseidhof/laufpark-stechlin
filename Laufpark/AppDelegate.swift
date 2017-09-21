import UIKit


extension Color {
    var name: String {
        switch self {
        case .red: return "rot"
        case .turquoise: return "tuerkis"
        case .brightGreen: return "hellgruen"
        case .beige: return "beige"
        case .green: return "gruen"
        case .purple: return "lila"
        case .violet: return "violett"
        case .blue: return "blau"
        case .brown: return "braun"
        case .yellow: return "gelb"
        case .gray: return "grau"
        case .lightBlue: return "hellblau"
        case .lightBrown: return "hellbraun"
        case .orange: return "orange"
        case .pink: return "pink"
        case .lightPink: return "rosa"
        }
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var mapViewController: ViewController?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        mapViewController = ViewController()
        window?.rootViewController = mapViewController
        window?.makeKeyAndVisible()
        DispatchQueue(label: "Track Loading").async {
            let tracks = self.loadTracks()
            DispatchQueue.main.async {
                self.mapViewController?.setTracks(tracks)
            }
        }
        application.applicationSupportsShakeToEdit = true
        return true
    }
    
    func loadTracks() -> [Track] {
        let definitions: [(Color, Int)] = [
            (.red, 4),
            (.turquoise, 5),
            (.brightGreen, 7),
            (.beige, 2),
            (.green, 4),
            (.purple, 3),
            (.violet, 4),
            (.blue, 3),
            (.brown, 4),
            (.yellow, 4),
            (.gray, 0),
            (.lightBlue, 4),
            (.lightBrown, 5),
            (.orange, 0),
            (.pink, 4),
            (.lightPink, 6)
        ]
        var allTracks: [[Track]] = []
        time {
            allTracks = definitions.map { (color, count) in
                let trackNames: [(Int, String)] = (0...count).map { ($0, "wabe \(color.name)-strecke \($0)") }
                return trackNames.map { numberAndName -> Track in
                    let reader = TrackReader(url: Bundle.main.url(forResource: numberAndName.1, withExtension: "gpx")!)!
                    return Track(color: color, number: numberAndName.0, name: reader.name, points: reader.points)
                }
            }
        }
        return Array(allTracks.joined())
    }
}

