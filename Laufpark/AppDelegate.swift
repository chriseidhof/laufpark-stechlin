import UIKit

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
            let tracks = Track.load()
            DispatchQueue.main.async {
                self.mapViewController?.setTracks(tracks)
            }
        }
        return true
    }
    

}

