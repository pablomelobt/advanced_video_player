import UIKit
import AVFoundation

/// Vista personalizada que se muestra durante Picture-in-Picture
/// Similar al estilo de Disney+ con icono y texto
@available(iOS 13.0, *)
class PiPOverlayView: UIView {
    
    private let containerView = UIView()
    private let iconView = UIView()
    private let textLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Configurar la vista principal
        backgroundColor = .black
        alpha = 0.95
        
        // Configurar el contenedor principal
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .clear
        addSubview(containerView)
        
        // Configurar el icono de PiP (dos rectángulos superpuestos)
        setupPiPIcon()
        
        // Configurar el texto
        setupText()
        
        // Configurar las constraints
        setupConstraints()
    }
    
    private func setupPiPIcon() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.backgroundColor = .clear
        containerView.addSubview(iconView)
        
      
        // 🔹 Rectángulo grande (pantalla base)
        let largeRect = UIView()
        largeRect.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.15)
        largeRect.layer.borderWidth = 2.5
        largeRect.layer.borderColor = UIColor.systemGray3.cgColor
        largeRect.layer.cornerRadius = 12
        largeRect.layer.shadowColor = UIColor.black.cgColor
        largeRect.layer.shadowOpacity = 0.25
        largeRect.layer.shadowRadius = 4
        largeRect.layer.shadowOffset = CGSize(width: 0, height: 2)
        largeRect.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(largeRect)
        
        // 🔹 Rectángulo pequeño (PiP window)
        let smallRect = UIView()
        smallRect.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.15)
        smallRect.layer.borderWidth = 2.0
        smallRect.layer.borderColor = UIColor.systemGray3.cgColor
        smallRect.layer.cornerRadius = 10
        smallRect.layer.shadowColor = UIColor.black.cgColor
        smallRect.layer.shadowOpacity = 0.4
        smallRect.layer.shadowRadius = 6
        smallRect.layer.shadowOffset = CGSize(width: 1, height: 2)
        smallRect.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(smallRect)
        
        // 🔹 Constraints proporcionales
        NSLayoutConstraint.activate([
            // Grande
            largeRect.centerXAnchor.constraint(equalTo: iconView.centerXAnchor, constant: -20),
            largeRect.centerYAnchor.constraint(equalTo: iconView.centerYAnchor, constant: 10),
            largeRect.widthAnchor.constraint(equalToConstant: 120),
            largeRect.heightAnchor.constraint(equalToConstant: 80),
            
            // Pequeño - bajado al máximo
            smallRect.trailingAnchor.constraint(equalTo: largeRect.trailingAnchor, constant: 0),
            smallRect.bottomAnchor.constraint(equalTo: largeRect.bottomAnchor, constant: 0),
            smallRect.widthAnchor.constraint(equalTo: largeRect.widthAnchor, multiplier: 0.5),
            smallRect.heightAnchor.constraint(equalTo: largeRect.heightAnchor, multiplier: 0.5)
        ])    
    
    }

    
    private func setupText() {
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.text = "Video reproduciéndose en imagen dentro de otra (PIP)."
        textLabel.textColor = .white
        textLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        textLabel.textAlignment = .center
        textLabel.numberOfLines = 0
        textLabel.lineBreakMode = .byWordWrapping
        containerView.addSubview(textLabel)
    }
    
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.9),
            
            // Icono de PiP (centro)
            iconView.topAnchor.constraint(equalTo: containerView.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 200),
            iconView.heightAnchor.constraint(equalToConstant: 150),
            
            // Texto (abajo)
            textLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 30),
            textLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    
    /// Muestra la vista con animación
    func show() {
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.alpha = 0.95
            self.transform = .identity
        }
    }
    
    /// Oculta la vista con animación
    func hide(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { _ in
            completion?()
        }
    }
}
