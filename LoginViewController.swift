import UIKit

class LoginViewController: UIViewController {
    
    let keyTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Введите ключ доступа"
        tf.borderStyle = .roundedRect
        tf.textAlignment = .center
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    let loginButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Войти", for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 18)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 10
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        
        loginButton.addTarget(self, action: #selector(handleLogin), for: .touchUpInside)
    }
    
    func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "iPAClient"
        titleLabel.font = .boldSystemFont(ofSize: 32)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(titleLabel)
        view.addSubview(keyTextField)
        view.addSubview(loginButton)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            
            keyTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            keyTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 50),
            keyTextField.widthAnchor.constraint(equalToConstant: 250),
            keyTextField.heightAnchor.constraint(equalToConstant: 44),
            
            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.topAnchor.constraint(equalTo: keyTextField.bottomAnchor, constant: 30),
            loginButton.widthAnchor.constraint(equalToConstant: 250),
            loginButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc func handleLogin() {
        guard let key = keyTextField.text, !key.isEmpty else { return }
        
        if key == "paris67" {
            // Вход для родителя (Админ)
            let adminVC = AdminViewController()
            adminVC.modalPresentationStyle = .fullScreen
            present(adminVC, animated: true)
        } else if key == "child" {
            // Вход для ребенка
            let childVC = ChildViewController()
            childVC.modalPresentationStyle = .fullScreen
            present(childVC, animated: true)
        } else {
            // Неверный ключ
            let alert = UIAlertController(title: "Ошибка", message: "Неверный ключ доступа", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ОК", style: .default))
            present(alert, animated: true)
        }
    }
}
