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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        
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
            (.gray, 1),
            (.lightBlue, 4),
            (.lightBrown, 5),
            (.orange, 1),
            (.pink, 4),
            (.lightPink, 6)
        ]
        let tracks: [[Track]] = definitions.map { (color, count) in
            let trackNames: [String] = (1...count).map { "wabe \(color.name)-strecke \($0)" }
            return trackNames.map { name -> Track in
                let reader = TrackReader(url: Bundle.main.url(forResource: name, withExtension: "gpx")!)!
                return Track(color: color, points: reader.points)
            }
        }
        window?.rootViewController = ViewController(tracks: Array(tracks.joined()))
        window?.makeKeyAndVisible()
        return true
    }
}

