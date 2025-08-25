//
//  WebViewController.swift
//  newsfeed
//

import UIKit
import WebKit

final class WebViewController: UIViewController {

    // MARK: - Input
    private let url: URL

    // MARK: - UI
    private let webView = WKWebView(frame: .zero)
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let errorView = UIView()
    private let activityIndicator: UIActivityIndicatorView = {
        let style: UIActivityIndicatorView.Style =
            UIDevice.current.userInterfaceIdiom == .pad ? .large : .medium
        let a = UIActivityIndicatorView(style: style)
        a.hidesWhenStopped = true
        return a
    }()

    // MARK: - KVO
    private var progressObservation: NSKeyValueObservation?

    // MARK: - Init
    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWebView()
        setupProgressView()
        setupErrorView()
        loadURL()
    }

    deinit {
        progressObservation?.invalidate()
        webView.navigationDelegate = nil
        webView.stopLoading()
    }

    // MARK: - Конфигурация
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Загрузка…"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(close)
        )
        navigationController?.setToolbarHidden(true, animated: false)
    }

    private func setupWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        view.addSubview(webView)

        // прогресс‑бар поверх safe‑area, webView — на всю область
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // индикатор по центру
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupProgressView() {
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.trackTintColor = .clear
        progressView.progressTintColor = .systemBlue
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])

        // безопасное KVO без ручного removeObserver
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self else { return }
            let progress = Float(webView.estimatedProgress)
            self.progressView.isHidden = progress >= 1.0
            self.progressView.setProgress(progress, animated: true)
            if progress >= 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.progressView.isHidden = true
                    self.progressView.progress = 0
                }
            }
        }
    }

    private func setupErrorView() {
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.backgroundColor = .systemBackground
        errorView.isHidden = true
        view.addSubview(errorView)

        let imageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .systemGray
        imageView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Не удалось загрузить страницу"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "Проверьте подключение к интернету и попробуйте снова."
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let retryButton = UIButton(type: .system)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("Повторить", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)

        errorView.addSubview(imageView)
        errorView.addSubview(titleLabel)
        errorView.addSubview(messageLabel)
        errorView.addSubview(retryButton)

        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: view.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: errorView.centerYAnchor, constant: -60),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -20),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -20),

            retryButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            retryButton.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            retryButton.widthAnchor.constraint(equalToConstant: 120),
            retryButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Actions
    private func loadURL() {
        // Для http/https canOpenURL не нужен
        activityIndicator.startAnimating()
        progressView.isHidden = false
        progressView.progress = 0

        let request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 30
        )
        webView.load(request)
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func retry() {
        errorView.isHidden = true
        webView.isHidden = false
        loadURL()
    }

    // MARK: - Errors
    private func showError(_ error: Error) {
        activityIndicator.stopAnimating()
        progressView.isHidden = true
        errorView.isHidden = false
        webView.isHidden = true
        title = "Ошибка"
    }
}

// MARK: - WKNavigationDelegate
extension WebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
        errorView.isHidden = true
        webView.isHidden = false
        progressView.isHidden = false
        progressView.progress = 0
        title = "Загрузка…"
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
        progressView.isHidden = true
        title = webView.title
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showError(error)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        // если ссылка пытается открыться в новом окне — загружаем её в текущем webView
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
