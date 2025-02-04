// Author: Sascha Petrik

import Cocoa
import LaunchAtLogin

class MainViewController: NSViewController {
  
  @objc dynamic var launchAtLogin = LaunchAtLogin.kvo
  
  @IBOutlet var mainView: NSView!
  @IBOutlet weak var customViewDefault: NSView!
  @IBOutlet weak var customViewSettings: NSView!
  @IBOutlet weak var brightnessSlider: NSSlider!
  @IBOutlet weak var brightnessSliderLabel: NSTextField!
  @IBOutlet weak var settingsButton: NSButtonCell!
  @IBOutlet weak var textfieldWledHost: NSTextField!
  @IBOutlet weak var saveButton: NSButton!
  @IBOutlet weak var comboButton: NSComboButton!
  
  let defaults = UserDefaults.standard
  let appDelegate: AppDelegate? = NSApplication.shared.delegate as? AppDelegate
  
  var wledIp = ""
  var presetsList = [NSDictionary]()
  var currentPresetId = -1
  
  struct FilteredItem: Codable {
      let index: Int
      let on: Bool
      let n: String
  }
  
  override func viewDidLoad() {
    
    super.viewDidLoad()

    mainView.frame.size.width = 320
    brightnessSlider.isContinuous = true
    
    // Tworzymy i przypisujemy menu do istniejącego NSComboButton
    comboButton.menu = createMenu()

  }
  
  
  override func viewDidAppear() {
    
    super.viewDidAppear()
    
    initViews()
    updateStates()
    
  }
  
  
  override func viewDidDisappear() {
    
    updateStates()
    
  }
  
  
  func initViews() {
    
    if(isKeyPresentInUserDefaults(key: "wledIp")){
      
      wledIp = defaults.value(forKey: "wledIp") as! String
      
    }
    
    if(wledIp != ""){
      
      textfieldWledHost.stringValue = wledIp
      brightnessSlider.isEnabled = true
      
    } else {
      
      brightnessSlider.isEnabled = false
      
    }
    
    customViewDefault.frame.origin.x = 0
    customViewSettings.frame.origin.x = -350
    settingsButton.controlView?.frame.origin.x = 0
    settingsButton.controlView?.toolTip = "Show config"
    settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration.init(pointSize: 0, weight: .regular, scale: .large))
    
  }
  
  
  func isKeyPresentInUserDefaults(key: String) -> Bool {
    
    return UserDefaults.standard.object(forKey: key) != nil
    
  }
  
  
  func moveView(position: CGFloat) {
    
    NSAnimationContext.runAnimationGroup({ context in
      
      context.duration = 1
      
      customViewDefault.animator().frame.origin.x = position
      customViewSettings.animator().frame.origin.x = position - 350
      settingsButton.controlView?.animator().frame.origin.x = position == 0 ? 0 : 270
      settingsButton.controlView?.toolTip = position == 0 ? "Show config" : "Go back"
      
    }){}
    
  }
  
  
  func postValues(sendOnOff: Bool, on: Bool, sendBri: Bool, bri: Int, sendPreset: Bool, preset: Int) {
    
    if(isKeyPresentInUserDefaults(key: "wledIp")){
      
      wledIp = defaults.value(forKey: "wledIp") as! String
      
      let url = URL(string: "http://\(wledIp)/json/state")!
      var jsonData: Any = []
      
      if(sendOnOff) {
        
        jsonData = ["on": on]
        
      } else if(sendBri) {
        
        jsonData = ["bri": round(Double(bri) * 2.55)]
        
      } else if (sendPreset) {
        
        jsonData = ["ps": preset]
        
      }
      
      let bodyData = try? JSONSerialization.data(withJSONObject: jsonData)
      
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.httpBody = bodyData
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      request.addValue("application/json", forHTTPHeaderField: "Accept")
      
      URLSession.shared.dataTask(with: request) { _,_,_ in  }.resume()
            
    }
    
  }
  
  
  func updateStates() {
    
    struct currentStates: Decodable {
      
      let on: Bool
      let bri: Int
      let ps: Int
      
    }
    
    if(isKeyPresentInUserDefaults(key: "wledIp")){
      
      if let url = URL(string: "http://\(wledIp)/json/state") {
        
        URLSession.shared.dataTask(with: url) { data,_,_ in
          
          if let data = data {
            
            do {
              
              let res = try JSONDecoder().decode(currentStates.self, from: data)
              
              DispatchQueue.main.async {
                
                self.appDelegate?.statusItem.button?.image = res.on ? self.appDelegate?.menuIconOn : self.appDelegate?.menuIconOff
                let mappedBri = Int(round(Double(res.bri) / 2.55))
                self.brightnessSliderLabel.stringValue = "\(mappedBri)%"
                self.brightnessSlider.integerValue = mappedBri
                self.currentPresetId = res.ps
                self.comboButton.title = "Preset \(res.ps)"
                
              }
              
            } catch _ {
              // no error handling currently -> maybe in a later version...
            }
            
          }
          
        }.resume()
        
      }
      
    }
    
  }
  
  
  
  @IBAction func clickOpenWled(_ sender: Any) {
    
    if(isKeyPresentInUserDefaults(key: "wledIp")){

      wledIp = defaults.value(forKey: "wledIp") as! String

      let url = "http://\(wledIp)"
      NSWorkspace.shared.open(URL(string: url)!)
      
    }
    
  }

  
  @IBAction func clickOpenGithubRepo(_ sender: Any) {
    
    let url = "https://github.com/satrik/wledQuickControl"
    NSWorkspace.shared.open(URL(string: url)!)
    
  }
  
  
  @IBAction func clickSettingsBtn(_ sender: Any) {
    
    let pos = customViewDefault.frame.origin.x
    let moveTo = CGFloat(pos == 0 ? 350 : 0)
    let btnImage = (pos == 0 ? NSImage(systemSymbolName: "chevron.forward", accessibilityDescription: nil) : NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil))
    settingsButton.image = btnImage?.withSymbolConfiguration(NSImage.SymbolConfiguration.init(pointSize: 0, weight: .regular, scale: .large))
    moveView(position: moveTo)
    textfieldWledHost.isEnabled = false
    textfieldWledHost.isEnabled = true
    
  }
  
  
  @IBAction func changeBrightnessSlider(_ sender: Any) {
    
    let event = NSApp.currentEvent!
    
    let val = brightnessSlider.integerValue
    
    switch event.type {
    
    case .leftMouseDragged, .rightMouseDragged:
      brightnessSliderLabel.stringValue = "\(val)%"
    case .leftMouseUp, .rightMouseUp:
      brightnessSliderLabel.stringValue = "\(val)%"
      postValues(sendOnOff: false, on: false, sendBri: true, bri: val, sendPreset: false, preset: 0)
    default:
      break
      
    }
    
    
  }

  // Funkcja tworząca menu z dynamicznymi opcjami
  func createMenu() -> NSMenu {
    
    let menu = NSMenu(title: "Presets")
   
    if(isKeyPresentInUserDefaults(key: "wledIp")){
      
      wledIp = defaults.value(forKey: "wledIp") as! String
      
      let urlString = "http://\(wledIp)/presets.json"
      
      fetchAndFilterJSON(from: urlString) { result in
        switch result {
        case .success(let items):
          for item in items {
            
            let menuItem = NSMenuItem(title: item.n, action: #selector(self.menuItemSelected(_:)), keyEquivalent: "")
            menuItem.tag = item.index  // Ustawiamy numer Index jako tag
            menuItem.target = self
            menu.addItem(menuItem)
          }
        case .failure(let error):
          print("Error: \(error.localizedDescription)")
        }
      }
    }

    return menu
  }
  
  // Obsługa kliknięcia na element menu
  @objc func menuItemSelected(_ sender: NSMenuItem) {
    comboButton.title = sender.title
    postValues(sendOnOff: false, on: false, sendBri: false, bri: 0, sendPreset: true, preset: sender.tag )
  }
  
  func fetchAndFilterJSON(from urlString: String, completion: @escaping (Result<[FilteredItem], Error>) -> Void) {
    
      guard let url = URL(string: urlString) else {
          completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
          return
      }
      
      let task = URLSession.shared.dataTask(with: url) { data, response, error in
          if let error = error {
              completion(.failure(error))
              return
          }
          
          guard let data = data else {
              completion(.failure(NSError(domain: "NoData", code: -1, userInfo: nil)))
              return
          }
          
          do {
              // Parsowanie JSON
              if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                  var filteredItems: [FilteredItem] = []
                  
                  for (index, item) in jsonObject {
                      // Pomijamy puste obiekty (np. klucz "0" w Twoim przykładzie)
                      guard let itemDict = item as? [String: Any], !itemDict.isEmpty else {
                          continue
                      }
                      
                      // Sprawdzamy, czy obiekt ma klucze "on" i "n"
                      if let on = itemDict["on"] as? Bool,
                         let n = itemDict["n"] as? String {
                          // Dodajemy tylko wymagane dane
                          filteredItems.append(FilteredItem(index: Int(index) ?? 0, on: on, n: n))
                      }
                  }
                  
                  completion(.success(filteredItems))
              } else {
                  completion(.failure(NSError(domain: "InvalidJSON", code: -1, userInfo: nil)))
              }
          } catch {
              completion(.failure(error))
          }
      }
      
      task.resume()
  }

  @IBAction func clickedSaveButton(_ sender: Any) {
    
    defaults.set(textfieldWledHost.stringValue, forKey: "wledIp")
    
    saveButton.title = ""
    saveButton.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800)) {
     
      self.saveButton.image = nil
      self.saveButton.title = "Save"
      self.moveView(position: 0)
      
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(400)) {
      
        self.initViews()
      
      }
    
    }
  
  }
  
  
  @IBAction func clickedQuitButton(_ sender: Any) {
  
    NSApplication.shared.terminate(nil)
  
  }

}


extension MainViewController {
  
  static func createController() -> MainViewController {
  
    let storyboard = NSStoryboard(name: "Main", bundle: nil)
    let identifier = "MainViewController"
    
    guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? MainViewController else {
      
      fatalError("Why cant i find MainViewController? - Check Main.storyboard")
      
    }
    
    return viewcontroller
    
  }
  
}
