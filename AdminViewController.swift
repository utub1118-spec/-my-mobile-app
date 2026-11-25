import UIKit
import FamilyControls
import ManagedSettings

class AdminViewController: UIViewController {
    
    let store = ManagedSettingsStore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        let titleLabel = UILabel()
        titleLabel.text = "Админ-панель"
        titleLabel.font = .boldSystemFont(ofSize: 28)
        titleLabel.textColor = .systemRed
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        let blockButton = UIButton(type: .system)
        blockButton.setTitle("Заблокировать всё", for: .normal)
        blockButton.backgroundColor = .systemRed
        blockButton.setTitleColor(.white, for: .normal)
        blockButton.layer.cornerRadius = 10
        blockButton.translatesAutoresizingMaskIntoConstraints = false
        blockButton.addTarget(self, action: #selector(blockAll), for: .touchUpInside)
        view.addSubview(blockButton)
        
        let logoutButton = UIButton(type: .system)
        logoutButton.setTitle("Выйти", for: .normal)
        logoutButton.translatesAutoresizingMaskIntoConstraints = false
        logoutButton.addTarget(self, action: #selector(logout), for: .touchUpInside)
        view.addSubview(logoutButton)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            
            blockButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            blockButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 50),
            blockButton.widthAnchor.constraint(equalToConstant: 250),
            blockButton.heightAnchor.constraint(equalToConstant: 50),
            
            logoutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoutButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50)
        ])
    }
    
    @objc func blockAll() {
        store.shield.applicationCategories = .all()
        let alert = UIAlertController(title: "Готово", message: "Все приложения заблокированы", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }
    
    @objc func logout() {
        dismiss(animated: true)
    }
}
