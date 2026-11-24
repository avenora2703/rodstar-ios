import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext

public func rodStarPresentTextInput(from controller: ViewController, title: String, message: String? = nil, value: String, placeholder: String = "", keyboardType: UIKeyboardType = .default, save: @escaping (String) -> Void) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addTextField { textField in
        textField.text = value
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.autocorrectionType = .no
    }
    alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
        save(alert.textFields?.first?.text ?? "")
    })
    DispatchQueue.main.async {
        var top: UIViewController? = controller.view.window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        top?.present(alert, animated: true)
    }
}

private final class RodStarTextEditorController: ViewController {
    private let context: AccountContext
    private let editorTitle: String
    private let initialText: String
    private let saveImpl: (String) -> Void
    private var textView: UITextView?

    init(context: AccountContext, title: String, text: String, save: @escaping (String) -> Void) {
        self.context = context
        self.editorTitle = title
        self.initialText = text
        self.saveImpl = save
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        self.view.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor

        let bar = UIView()
        bar.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor
        bar.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(bar)

        let titleLabel = UILabel()
        titleLabel.text = self.editorTitle
        titleLabel.textColor = presentationData.theme.rootController.navigationBar.primaryTextColor
        titleLabel.font = Font.semibold(17.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(titleLabel)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Отмена", for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(self.cancelPressed), for: .touchUpInside)
        bar.addSubview(cancelButton)

        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Сохранить", for: .normal)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(self.savePressed), for: .touchUpInside)
        bar.addSubview(saveButton)

        let textView = UITextView()
        textView.text = self.initialText
        textView.font = Font.regular(16.0)
        textView.textColor = presentationData.theme.list.itemPrimaryTextColor
        textView.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        textView.autocorrectionType = .no
        textView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(textView)
        self.textView = textView

        let safe = self.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: safe.topAnchor),
            bar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 44.0),
            titleLabel.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            cancelButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16.0),
            cancelButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            saveButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16.0),
            saveButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            textView.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 8.0),
            textView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 8.0),
            textView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -8.0),
            textView.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8.0),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.textView?.becomeFirstResponder()
    }

    @objc private func cancelPressed() {
        self.dismiss(animated: true)
    }

    @objc private func savePressed() {
        self.saveImpl(self.textView?.text ?? "")
        self.dismiss(animated: true)
    }
}

public func rodStarPresentTextEditor(from controller: ViewController, context: AccountContext, title: String, text: String, save: @escaping (String) -> Void) {
    let editor = RodStarTextEditorController(context: context, title: title, text: text, save: save)
    editor.modalPresentationStyle = .formSheet
    DispatchQueue.main.async {
        var top: UIViewController? = controller.view.window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        top?.present(editor, animated: true)
    }
}