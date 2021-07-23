


import Foundation
import GoogleAPIClientForREST
import GoogleSignIn

open class HSGIDSignInHandler: NSObject {

  @objc static let hsGIDSignInChangedNotification = NSNotification.Name("HSGIDSignInChangedNotification")
  @objc static let hsGIDSignInFailedNotification = NSNotification.Name("HSGIDSignInFailedNotification")

  static let sharedInstance = HSGIDSignInHandler()


  class var authoriser:GTMFetcherAuthorizationProtocol? {
    return HSGIDSignInHandler.sharedInstance.authoriser
  }

  class func canAuthorise() -> Bool {
    if HSGIDSignInHandler.sharedInstance.authoriser?.canAuthorize == true {
      return true
    }

    return false
  }

  weak var viewController:UIViewController?
  class func signIn(from vc: UIViewController?) {

    let handler = self.sharedInstance
    handler.viewController = vc

    //in iOS 8, the sign-in is called with view_did_appear before the signIn_didSignIn is fired on a queue
    DispatchQueue.main.async(execute: {
      guard let caller = vc else { return }
      let config = GIDConfiguration(clientID: self.sharedInstance.clientIDFromPlist)
      GIDSignIn.sharedInstance.signIn(with: config, presenting: caller) { user, error in
        self.sharedInstance.sign(GIDSignIn.sharedInstance, didSignInFor: user, withError: error)
      }
    })

  }

  class func signOut() {
    GIDSignIn.sharedInstance.disconnect()
    GIDSignIn.sharedInstance.signOut()
  }

  var authoriser: GTMFetcherAuthorizationProtocol?

  override init() {
    super.init()
    GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
      self?.sign(GIDSignIn.sharedInstance, didSignInFor: user, withError: error)
    }
  }


  /// Either add GoogleService-Info.plist to your project
  /// or manually initialise Google Signin by calling
  /// GIDSignIn.sharedInstance().clientID = "YOUR_CLIENT_ID" in your AppDelegate
  var clientIDFromPlist:String {
    let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
    if let dict = NSDictionary(contentsOfFile: path ?? "") as? [String:Any]? {
      let clientID = dict?["CLIENT_ID"] as? String
      if let clientID = clientID  {
        return clientID
      }
    }

    fatalError("GoogleService-Info.plist hasn't been added to the project")
  }



  public func sign(_ signIn: GIDSignIn?, didSignInFor user: GIDGoogleUser?, withError error: Error?) {
    if error == nil {
      if user?.grantedScopes?.contains(kGTLRAuthScopeDrive) ?? false {
        authoriser = user?.authentication.fetcherAuthorizer()
        NotificationCenter.default.post(name: HSGIDSignInHandler.hsGIDSignInChangedNotification, object: self)
      } else {
        guard let viewController = self.viewController else {
          return
        }
        GIDSignIn.sharedInstance.addScopes(
          [kGTLRAuthScopeDrive],
          presenting: viewController) { [weak self] user, error in
          self?.sign(GIDSignIn.sharedInstance, didSignInFor: user, withError: error)
        }
      }
    } else {
      authoriser = nil
      NotificationCenter.default.post(name: HSGIDSignInHandler.hsGIDSignInFailedNotification, object: self)

      //silent signin generates this error
      if let code = (error as NSError?)?.code {
        if code == GIDSignInError.hasNoAuthInKeychain.rawValue {
          return
        }
      }

      if let viewController = viewController {
        let alert = UIAlertController.init(title: "Unable to sign in to Drive",
                                           message: error?.localizedDescription,
                                           preferredStyle: .alert)
        alert.addAction(UIAlertAction.init(title: "OK", style: .default))
        viewController.present(alert, animated: true)
      }
    }
  }

  public func sign(_ signIn: GIDSignIn?, didDisconnectWith user: GIDGoogleUser?, withError error: Error?) {
    print("User disconnected")
    authoriser = nil
    NotificationCenter.default.post(name: HSGIDSignInHandler.hsGIDSignInChangedNotification, object: self)
  }
}
