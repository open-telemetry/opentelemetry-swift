/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import UIKit
import SwiftUI
import Foundation
import Sessions
import OpenTelemetryApi

let artificialDelay: TimeInterval = 0.25

// Global time formatting helper
func timeAgo(from timestamp: Int) -> String {
  let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
  let formatter = RelativeDateTimeFormatter()
  formatter.unitsStyle = .abbreviated
  return formatter.localizedString(for: date, relativeTo: Date())
}

let debugScope = "HackerNewsDemo.Debug"

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  var tracer: Tracer?
  var logger: Logger?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Telemetry.start()

    if IntegrationTestScenario.isEnabled {
      IntegrationTestScenario.run()
    }

    window = UIWindow(frame: UIScreen.main.bounds)

    let homeNavController = UINavigationController(rootViewController: HackerNewsViewController())
    homeNavController.tabBarItem = UITabBarItem(title: nil, image: UIImage(systemName: "house"), tag: 0)
    homeNavController.interactivePopGestureRecognizer?.isEnabled = true

    let settingsNavController = UINavigationController(rootViewController: SettingsHostingController())
    settingsNavController.tabBarItem = UITabBarItem(title: nil, image: UIImage(systemName: "gearshape"), tag: 1)
    settingsNavController.interactivePopGestureRecognizer?.isEnabled = true

    let tabBarController = UITabBarController()
    tabBarController.viewControllers = [homeNavController, settingsNavController]

    window?.rootViewController = tabBarController
    window?.makeKeyAndVisible()
    print("AppDelegate: Window setup complete")

    return true
  }
}

struct HNStory {
  let id: Int
  let title: String
  let url: String?
  let score: Int
  let by: String
  let time: Int
  let descendants: Int
}

enum FeedType: String, CaseIterable {
  case top = "topstories"
  case best = "beststories"
  case new = "newstories"

  var displayName: String {
    switch self {
    case .top: return "Top"
    case .best: return "Best"
    case .new: return "New"
    }
  }
}

class HackerNewsViewController: UIViewController {
  private let tableView = UITableView()
  private var stories: [HNStory] = []
  private var currentFeed: FeedType = .top
  private var isLoading = true
  private var allStoryIds: [Int] = []
  private var currentPage = 0
  private let pageSize = 20
  private var isLoadingMore = false

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    loadTopStories()
  }

  private func setupUI() {
    view.backgroundColor = .systemBackground
    navigationController?.hidesBarsOnSwipe = true

    let titleLabel = UILabel()
    titleLabel.text = "Hacker News"
    titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
    titleLabel.textAlignment = .left
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: titleLabel)

    let segmentedControl = UISegmentedControl(items: FeedType.allCases.map(\.displayName))
    segmentedControl.selectedSegmentIndex = 0
    segmentedControl.addTarget(self, action: #selector(feedTypeChanged), for: .valueChanged)
    navigationItem.rightBarButtonItem = UIBarButtonItem(customView: segmentedControl)

    tableView.delegate = self
    tableView.dataSource = self
    tableView.register(StoryCell.self, forCellReuseIdentifier: "StoryCell")
    tableView.register(SkeletonCell.self, forCellReuseIdentifier: "SkeletonCell")
    tableView.register(LoadingCell.self, forCellReuseIdentifier: "LoadingCell")
    tableView.translatesAutoresizingMaskIntoConstraints = false

    let refreshControl = UIRefreshControl()
    refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
    tableView.refreshControl = refreshControl

    view.addSubview(tableView)

    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
    ])
  }

  @objc private func feedTypeChanged(_ sender: UISegmentedControl) {
    currentFeed = FeedType.allCases[sender.selectedSegmentIndex]
    isLoading = true
    stories = []
    allStoryIds = []
    currentPage = 0
    tableView.reloadData()
    loadStories()
  }

  @objc private func refreshData() {
    stories = []
    allStoryIds = []
    currentPage = 0
    loadStories()
  }

  private func loadTopStories() {
    loadStories()
  }

  private func loadStories() {
    guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/\(currentFeed.rawValue).json") else { return }

    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
      guard let data,
            let storyIds = try? JSONDecoder().decode([Int].self, from: data) else { return }

      DispatchQueue.main.async {
        self?.allStoryIds = storyIds
        self?.loadNextPage()
      }
    }.resume()
  }

  private func loadNextPage() {
    guard !isLoadingMore else { return }

    let startIndex = currentPage * pageSize
    let endIndex = min(startIndex + pageSize, allStoryIds.count)

    guard startIndex < allStoryIds.count else { return }

    isLoadingMore = true
    tableView.reloadData() // Immediately show loading cell
    let pageIds = Array(allStoryIds[startIndex ..< endIndex])
    loadStoryDetails(ids: pageIds, isLoadingMore: currentPage > 0)
  }

  private func loadStoryDetails(ids: [Int], isLoadingMore: Bool = false) {
    let group = DispatchGroup()
    var loadedStories: [HNStory] = []

    for id in ids {
      group.enter()
      guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json") else {
        group.leave()
        continue
      }

      URLSession.shared.dataTask(with: url) { data, _, _ in
        defer { group.leave() }
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String,
              let score = json["score"] as? Int,
              let by = json["by"] as? String,
              let time = json["time"] as? Int else { return }

        let story = HNStory(
          id: id,
          title: title,
          url: json["url"] as? String,
          score: score,
          by: by,
          time: time,
          descendants: json["descendants"] as? Int ?? 0
        )
        loadedStories.append(story)
      }.resume()
    }

    group.notify(queue: .main) {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        if isLoadingMore {
          self.stories.append(contentsOf: loadedStories.sorted { $0.score > $1.score })
        } else {
          self.stories = loadedStories.sorted { $0.score > $1.score }
        }

        self.currentPage += 1
        self.isLoading = false
        self.isLoadingMore = false
        self.tableView.reloadData()
        self.tableView.refreshControl?.endRefreshing()
      }
    }
  }
}

extension HackerNewsViewController: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if isLoading {
      return 10
    }
    return stories.count + (isLoadingMore ? 1 : 0)
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if isLoading {
      let cell = tableView.dequeueReusableCell(withIdentifier: "SkeletonCell", for: indexPath) as! SkeletonCell
      return cell
    }

    if indexPath.row == stories.count, isLoadingMore {
      print("DEBUG: Showing LoadingCell at row \(indexPath.row)")
      let cell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell", for: indexPath) as! LoadingCell
      return cell
    }

    let cell = tableView.dequeueReusableCell(withIdentifier: "StoryCell", for: indexPath) as! StoryCell
    cell.configure(with: stories[indexPath.row])
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard !isLoading, indexPath.row < stories.count else { return }
    let story = stories[indexPath.row]
    navigationItem.backButtonTitle = ""
    let commentsVC = CommentsViewController(story: story)
    navigationController?.pushViewController(commentsVC, animated: true)
  }

  func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    if velocity.y < 0 {
      navigationController?.setNavigationBarHidden(false, animated: true)
    }
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let offsetY = scrollView.contentOffset.y
    let contentHeight = scrollView.contentSize.height
    let height = scrollView.frame.size.height

    // Bottom toolbar stays visible

    if offsetY > contentHeight - height - 100, !isLoadingMore, !isLoading {
      loadNextPage()
    }
  }
}

class StoryCell: UITableViewCell {
  private let titleLabel = UILabel()
  private let metaLabel = UILabel()
  private let upvoteStackView = UIStackView()
  private let upvoteIcon = UIImageView()
  private let scoreLabel = UILabel()
  private let thumbnailImageView = UIImageView()
  private let optionsButton = UIButton()
  private var story: HNStory?

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupUI()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
    titleLabel.numberOfLines = 0

    metaLabel.font = .systemFont(ofSize: 12)
    metaLabel.textColor = .secondaryLabel

    upvoteIcon.image = UIImage(systemName: "arrow.up")
    upvoteIcon.tintColor = .systemOrange
    upvoteIcon.contentMode = .scaleAspectFit

    scoreLabel.font = .systemFont(ofSize: 12, weight: .medium)
    scoreLabel.textColor = .systemOrange
    scoreLabel.textAlignment = .center

    upvoteStackView.axis = .vertical
    upvoteStackView.alignment = .center
    upvoteStackView.spacing = 2
    upvoteStackView.addArrangedSubview(upvoteIcon)
    upvoteStackView.addArrangedSubview(scoreLabel)

    thumbnailImageView.contentMode = .scaleAspectFill
    thumbnailImageView.clipsToBounds = true
    thumbnailImageView.layer.cornerRadius = 8
    thumbnailImageView.backgroundColor = .systemGray6
    thumbnailImageView.isHidden = true

    optionsButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
    optionsButton.tintColor = .secondaryLabel
    optionsButton.addTarget(self, action: #selector(optionsButtonTapped), for: .touchUpInside)

    [titleLabel, metaLabel, upvoteStackView, thumbnailImageView, optionsButton].forEach {
      $0.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview($0)
    }

    NSLayoutConstraint.activate([
      upvoteStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      upvoteStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
      upvoteStackView.widthAnchor.constraint(equalToConstant: 40),
      upvoteIcon.heightAnchor.constraint(equalToConstant: 16),
      upvoteIcon.widthAnchor.constraint(equalToConstant: 16),

      thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
      thumbnailImageView.widthAnchor.constraint(equalToConstant: 60),
      thumbnailImageView.heightAnchor.constraint(equalToConstant: 60),

      optionsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      optionsButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
      optionsButton.widthAnchor.constraint(equalToConstant: 24),
      optionsButton.heightAnchor.constraint(equalToConstant: 24),

      titleLabel.leadingAnchor.constraint(equalTo: upvoteStackView.trailingAnchor, constant: 12),
      titleLabel.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor, constant: -8),
      titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

      metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      metaLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
      metaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
      metaLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
    ])
  }

  func configure(with story: HNStory) {
    self.story = story
    titleLabel.text = story.title

    // Make username tappable
    let timeAgoText = timeAgo(from: story.time)
    let fullText = "by \(story.by) • \(timeAgoText) • \(story.descendants) comments"
    let attributedText = NSMutableAttributedString(string: fullText)
    let usernameRange = (fullText as NSString).range(of: story.by)
    attributedText.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: usernameRange)
    metaLabel.attributedText = attributedText
    metaLabel.isUserInteractionEnabled = true

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(usernameTapped))
    metaLabel.addGestureRecognizer(tapGesture)

    scoreLabel.text = "\(story.score)"
  }

  @objc private func usernameTapped() {
    guard let story else { return }
    if let viewController = findViewController() {
      viewController.navigationItem.backButtonTitle = ""
      let userVC = UserViewController(username: story.by)
      viewController.navigationController?.pushViewController(userVC, animated: true)
    }
  }

  @objc private func optionsButtonTapped() {
    guard let story else { return }

    var itemsToShare: [Any] = [story.title]
    if let url = story.url {
      itemsToShare.append(url)
    }

    let activityVC = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)

    if let viewController = findViewController() {
      if let popover = activityVC.popoverPresentationController {
        popover.sourceView = optionsButton
        popover.sourceRect = optionsButton.bounds
      }
      viewController.present(activityVC, animated: true)
    }
  }
}

extension UIView {
  func findViewController() -> UIViewController? {
    if let nextResponder = next as? UIViewController {
      return nextResponder
    } else if let nextResponder = next as? UIView {
      return nextResponder.findViewController()
    } else {
      return nil
    }
  }
}

class SkeletonCell: UITableViewCell {
  private let upvoteBox = UIView()
  private let titleBox1 = UIView()
  private let titleBox2 = UIView()
  private let metaBox = UIView()
  private let thumbnailBox = UIView()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    setupUI()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    [upvoteBox, titleBox1, titleBox2, metaBox, thumbnailBox].forEach {
      $0.backgroundColor = .systemGray5
      $0.layer.cornerRadius = 4
      $0.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview($0)
    }

    thumbnailBox.layer.cornerRadius = 8

    NSLayoutConstraint.activate([
      upvoteBox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      upvoteBox.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
      upvoteBox.widthAnchor.constraint(equalToConstant: 40),
      upvoteBox.heightAnchor.constraint(equalToConstant: 40),

      thumbnailBox.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      thumbnailBox.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
      thumbnailBox.widthAnchor.constraint(equalToConstant: 60),
      thumbnailBox.heightAnchor.constraint(equalToConstant: 60),

      titleBox1.leadingAnchor.constraint(equalTo: upvoteBox.trailingAnchor, constant: 12),
      titleBox1.trailingAnchor.constraint(equalTo: thumbnailBox.leadingAnchor, constant: -12),
      titleBox1.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
      titleBox1.heightAnchor.constraint(equalToConstant: 16),

      titleBox2.leadingAnchor.constraint(equalTo: titleBox1.leadingAnchor),
      titleBox2.topAnchor.constraint(equalTo: titleBox1.bottomAnchor, constant: 4),
      titleBox2.heightAnchor.constraint(equalToConstant: 16),
      titleBox2.widthAnchor.constraint(equalTo: titleBox1.widthAnchor, multiplier: 0.7),

      metaBox.leadingAnchor.constraint(equalTo: titleBox1.leadingAnchor),
      metaBox.topAnchor.constraint(equalTo: titleBox2.bottomAnchor, constant: 8),
      metaBox.heightAnchor.constraint(equalToConstant: 12),
      metaBox.widthAnchor.constraint(equalToConstant: 120),
      metaBox.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
    ])
  }
}

class LoadingCell: UITableViewCell {
  private let activityIndicator = UIActivityIndicatorView(style: .medium)
  private let loadingLabel = UILabel()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    setupUI()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    loadingLabel.text = "Loading more stories..."
    loadingLabel.font = .systemFont(ofSize: 14)
    loadingLabel.textColor = .secondaryLabel
    loadingLabel.textAlignment = .center

    activityIndicator.startAnimating()

    let stackView = UIStackView(arrangedSubviews: [activityIndicator, loadingLabel])
    stackView.axis = .horizontal
    stackView.spacing = 12
    stackView.alignment = .center
    stackView.translatesAutoresizingMaskIntoConstraints = false

    contentView.addSubview(stackView)
    NSLayoutConstraint.activate([
      stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
      stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
    ])
  }
}

class EmptyCommentsCell: UITableViewCell {
  private let emptyLabel = UILabel()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    setupUI()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    emptyLabel.text = "No comments yet"
    emptyLabel.font = .systemFont(ofSize: 14)
    emptyLabel.textColor = .secondaryLabel
    emptyLabel.textAlignment = .left
    emptyLabel.translatesAutoresizingMaskIntoConstraints = false

    contentView.addSubview(emptyLabel)
    NSLayoutConstraint.activate([
      emptyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      emptyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      emptyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
      emptyLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
    ])
  }
}

struct HNComment {
  let id: Int
  let by: String?
  let text: String?
  let time: Int
  let kids: [Int]?
  let parent: Int?
  let deleted: Bool
  let dead: Bool
}

enum CommentSortType: String, CaseIterable {
  case new
  case hot

  var displayName: String {
    switch self {
    case .new: return "New"
    case .hot: return "Hot"
    }
  }
}

class CommentsViewController: UIViewController {
  private let tableView = UITableView()
  private let story: HNStory
  private var comments: [Any] = []
  private var rootComments: [CommentNode] = []
  private var allCommentIds: [Int] = []
  private var isLoading = true
  private var isLoadingMore = false
  private var currentBatch = 0
  private let batchSize = 5
  private var titleLabel: UILabel?
  private var currentSort: CommentSortType = .hot

  init(story: HNStory) {
    self.story = story
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    loadComments()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.hidesBarsOnSwipe = false
    navigationController?.setNavigationBarHidden(false, animated: animated)
    navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    navigationController?.interactivePopGestureRecognizer?.delegate = self
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.hidesBarsOnSwipe = true
  }

  private func setupUI() {
    view.backgroundColor = .systemBackground

    // Remove custom back button to allow swipe gesture
    // navigationItem.leftBarButtonItem = UIBarButtonItem(
    //   image: UIImage(systemName: "chevron.left"),
    //   style: .plain,
    //   target: self,
    //   action: #selector(backButtonTapped)
    // )

    let segmentedControl = UISegmentedControl(items: CommentSortType.allCases.map(\.displayName))
    segmentedControl.selectedSegmentIndex = 1 // Default to "Hot"
    segmentedControl.addTarget(self, action: #selector(sortTypeChanged), for: .valueChanged)
    navigationItem.rightBarButtonItem = UIBarButtonItem(customView: segmentedControl)

    tableView.delegate = self
    tableView.dataSource = self
    tableView.register(CommentCell.self, forCellReuseIdentifier: "CommentCell")
    tableView.register(SkeletonCommentCell.self, forCellReuseIdentifier: "SkeletonCommentCell")
    tableView.register(StoryHeaderCell.self, forCellReuseIdentifier: "StoryHeaderCell")
    tableView.register(LoadingCell.self, forCellReuseIdentifier: "LoadingCell")
    tableView.register(EmptyCommentsCell.self, forCellReuseIdentifier: "EmptyCommentsCell")
    tableView.separatorStyle = .none
    tableView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  private func loadComments() {
    guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(story.id).json") else { return }

    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
      guard let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let kids = json["kids"] as? [Int] else {
        DispatchQueue.main.async {
          self?.isLoading = false
          self?.tableView.reloadData()
        }
        return
      }

      self?.loadCommentTree(ids: kids)
    }.resume()
  }

  private func loadCommentTree(ids: [Int]) {
    allCommentIds = ids
    loadNextBatch()
  }

  private func loadNextBatch() {
    guard !isLoadingMore else { return }

    let startIndex = currentBatch * batchSize
    let endIndex = min(startIndex + batchSize, allCommentIds.count)

    guard startIndex < allCommentIds.count else { return }

    isLoadingMore = true
    let batchIds = Array(allCommentIds[startIndex ..< endIndex])

    loadTopLevelComments(ids: batchIds) { [weak self] newNodes in
      DispatchQueue.main.asyncAfter(deadline: .now() + artificialDelay) {
        self?.rootComments.append(contentsOf: newNodes)
        self?.sortComments()
        self?.currentBatch += 1
        self?.isLoading = false
        self?.isLoadingMore = false
        self?.tableView.reloadData()
      }
    }
  }

  private func loadTopLevelComments(ids: [Int], completion: @escaping ([CommentNode]) -> Void) {
    let group = DispatchGroup()
    var nodes: [CommentNode] = []

    for id in ids {
      group.enter()
      loadCommentWithDepth(id: id, depth: 0, maxDepth: 1) { [weak self] node in
        if let node {
          nodes.append(node)
        }
        group.leave()
      }
    }

    group.notify(queue: .global()) {
      completion(nodes)
    }
  }

  private func loadCommentWithDepth(id: Int, depth: Int, maxDepth: Int, completion: @escaping (CommentNode?) -> Void) {
    loadComment(id: id) { [weak self] comment in
      guard let comment, !comment.deleted, !comment.dead else {
        completion(nil)
        return
      }

      if depth >= maxDepth || comment.kids == nil || comment.kids!.isEmpty {
        let node = CommentNode(comment: comment, children: [], depth: depth)
        completion(node)
        return
      }

      let group = DispatchGroup()
      var children: [CommentNode] = []

      // Limit initial replies per comment to 3 for better performance
      let maxReplies = depth == 0 ? 3 : 2
      let kidsToLoad = Array(comment.kids!.prefix(maxReplies))

      for kidId in kidsToLoad {
        group.enter()
        self?.loadCommentWithDepth(id: kidId, depth: depth + 1, maxDepth: maxDepth) { childNode in
          if let childNode {
            children.append(childNode)
          }
          group.leave()
        }
      }

      group.notify(queue: .global()) {
        let node = CommentNode(comment: comment, children: children, depth: depth)
        completion(node)
      }
    }
  }

  private func loadCommentsRecursively(ids: [Int], depth: Int, completion: @escaping ([CommentNode]) -> Void) {
    let group = DispatchGroup()
    var nodes: [CommentNode] = []

    for id in ids {
      group.enter()
      loadComment(id: id) { [weak self] comment in
        guard let comment, !comment.deleted, !comment.dead else {
          group.leave()
          return
        }

        if let kids = comment.kids, !kids.isEmpty {
          self?.loadCommentsRecursively(ids: kids, depth: depth + 1) { children in
            let node = CommentNode(comment: comment, children: children, depth: depth)
            nodes.append(node)
            group.leave()
          }
        } else {
          let node = CommentNode(comment: comment, children: [], depth: depth)
          nodes.append(node)
          group.leave()
        }
      }
    }

    group.notify(queue: .global()) {
      completion(nodes)
    }
  }

  private func flattenCommentTree(_ nodes: [CommentNode]) -> [Any] {
    var flattened: [Any] = []

    func flatten(_ node: CommentNode) {
      flattened.append(node)
      if !node.isCollapsed {
        for child in node.children {
          flatten(child)
        }
        // Add load replies button after all children if there are unloaded replies
        if node.hasUnloadedReplies {
          flattened.append(("loadReplies", node.comment.id, node.unloadedReplyCount, node.depth + 1))
        }
      }
    }

    for node in nodes {
      flatten(node)
    }

    return flattened
  }

  private func loadComment(id: Int, completion: @escaping (HNComment?) -> Void) {
    guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json") else {
      completion(nil)
      return
    }

    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        completion(nil)
        return
      }

      let comment = HNComment(
        id: json["id"] as? Int ?? id,
        by: json["by"] as? String,
        text: json["text"] as? String,
        time: json["time"] as? Int ?? 0,
        kids: json["kids"] as? [Int],
        parent: json["parent"] as? Int,
        deleted: json["deleted"] as? Bool ?? false,
        dead: json["dead"] as? Bool ?? false
      )

      completion(comment)
    }.resume()
  }

  @objc private func backButtonTapped() {
    navigationController?.popViewController(animated: true)
  }

  @objc private func sortTypeChanged(_ sender: UISegmentedControl) {
    currentSort = CommentSortType.allCases[sender.selectedSegmentIndex]
    sortComments()
    tableView.reloadData()
  }

  private func sortComments() {
    switch currentSort {
    case .new:
      // Sort only top-level comments by time, preserve hierarchy
      let sortedRoots = rootComments.sorted { $0.comment.time > $1.comment.time }
      comments = flattenCommentTree(sortedRoots)
    case .hot:
      // Sort top-level comments by total tree size, preserve hierarchy
      let sortedRoots = rootComments.sorted { getTreeSize($0) > getTreeSize($1) }
      comments = flattenCommentTree(sortedRoots)
    }
  }

  private func getTreeSize(_ node: CommentNode) -> Int {
    // Use the kids array length from the API which represents total direct replies
    return node.comment.kids?.count ?? 0
  }

  private func loadRepliesForComment(commentId: Int) {
    guard let comment = findComment(id: commentId, in: rootComments) else { return }
    guard let kids = comment.comment.kids else { return }

    let unloadedIds = Array(kids.dropFirst(comment.children.count))

    let group = DispatchGroup()
    var newChildren: [CommentNode] = []

    for id in unloadedIds {
      group.enter()
      loadCommentWithDepth(id: id, depth: comment.depth + 1, maxDepth: comment.depth + 3) { [weak self] childNode in
        if let childNode {
          newChildren.append(childNode)
        }
        group.leave()
      }
    }

    group.notify(queue: .main) { [weak self] in
      DispatchQueue.main.asyncAfter(deadline: .now() + artificialDelay) {
        comment.children.append(contentsOf: newChildren)
        comment.loadedToMaxDepth = true
        self?.sortComments()
        self?.tableView.reloadData()
      }
    }
  }

  private func findComment(id: Int, in nodes: [CommentNode]) -> CommentNode? {
    for node in nodes {
      if node.comment.id == id {
        return node
      }
      if let found = findComment(id: id, in: node.children) {
        return found
      }
    }
    return nil
  }
}

class CommentNode {
  let comment: HNComment
  var children: [CommentNode]
  let depth: Int
  var loadedToMaxDepth: Bool = false
  var isCollapsed: Bool = false

  init(comment: HNComment, children: [CommentNode], depth: Int) {
    self.comment = comment
    self.children = children
    self.depth = depth
  }

  var hasUnloadedReplies: Bool {
    guard let kids = comment.kids else { return false }
    return kids.count > children.count && !loadedToMaxDepth
  }

  var unloadedReplyCount: Int {
    guard let kids = comment.kids else { return 0 }
    return kids.count - children.count
  }
}

extension CommentsViewController: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if isLoading {
      return 1 + 8 // 1 for story header + 8 skeleton comments
    }
    if comments.isEmpty {
      return 2 // 1 for story header + 1 for empty state
    }
    let hasMoreComments = currentBatch * batchSize < allCommentIds.count
    return 1 + comments.count + (hasMoreComments ? 1 : 0) // 1 for story header + comments + loading cell
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.row == 0 {
      let cell = tableView.dequeueReusableCell(withIdentifier: "StoryHeaderCell", for: indexPath) as! StoryHeaderCell
      cell.configure(with: story)
      return cell
    }

    if isLoading {
      let cell = tableView.dequeueReusableCell(withIdentifier: "SkeletonCommentCell", for: indexPath) as! SkeletonCommentCell
      let depth = (indexPath.row - 1) % 3 // Vary depth for visual hierarchy
      cell.configure(depth: depth)
      return cell
    }

    if comments.isEmpty {
      let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyCommentsCell", for: indexPath) as! EmptyCommentsCell
      return cell
    }

    let hasMoreComments = currentBatch * batchSize < allCommentIds.count
    if indexPath.row == 1 + comments.count, hasMoreComments {
      let cell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell", for: indexPath) as! LoadingCell
      return cell
    }

    let item = comments[indexPath.row - 1]
    if let commentNode = item as? CommentNode {
      let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as! CommentCell
      cell.configure(with: commentNode) { [weak self] commentId in
        self?.loadRepliesForComment(commentId: commentId)
      }
      cell.onCollapse = { [weak self] node in
        node.isCollapsed.toggle()
        self?.sortComments()
        self?.tableView.reloadData()

        // If collapsing makes loading cell visible, trigger next batch
        DispatchQueue.main.async {
          guard let self else { return }
          let hasMoreComments = self.currentBatch * self.batchSize < self.allCommentIds.count
          if hasMoreComments, !self.isLoadingMore, !self.isLoading {
            let loadingCellIndex = 1 + self.comments.count
            if let visibleRows = self.tableView.indexPathsForVisibleRows,
               visibleRows.contains(IndexPath(row: loadingCellIndex, section: 0)) {
              self.loadNextBatch()
            }
          }
        }
      }
      return cell
    } else if let loadRepliesData = item as? (String, Int, Int, Int) {
      let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as! CommentCell
      cell.configureAsLoadReplies(commentId: loadRepliesData.1, depth: loadRepliesData.3) { [weak self] commentId in
        self?.loadRepliesForComment(commentId: commentId)
      }
      return cell
    }

    return UITableViewCell()
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let headerCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0))
    let headerHeight = headerCell?.frame.height ?? 0
    let shouldShowTitle = scrollView.contentOffset.y > headerHeight - 50

    if shouldShowTitle {
      if titleLabel == nil {
        let label = UILabel()
        label.text = story.title
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .left
        titleLabel = label
        navigationItem.titleView = label
      }
    } else {
      navigationItem.titleView = nil
      titleLabel = nil
    }

    // Load more comments when near bottom
    let offsetY = scrollView.contentOffset.y
    let contentHeight = scrollView.contentSize.height
    let height = scrollView.frame.size.height

    if offsetY > contentHeight - height - 100, !isLoadingMore, !isLoading {
      let hasMoreComments = currentBatch * batchSize < allCommentIds.count
      if hasMoreComments {
        loadNextBatch()
      }
    }
  }
}

class StoryHeaderCell: UITableViewCell {
  private let titleLabel = UILabel()
  private let metaLabel = UILabel()
  private let urlButton = UIButton()
  private let shareButton = UIButton()
  private var story: HNStory?

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    setupUI()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
    titleLabel.numberOfLines = 0

    metaLabel.font = .systemFont(ofSize: 14)
    metaLabel.textColor = .secondaryLabel

    urlButton.setTitleColor(.systemBlue, for: .normal)
    urlButton.titleLabel?.font = .systemFont(ofSize: 14)
    urlButton.contentHorizontalAlignment = .left
    urlButton.addTarget(self, action: #selector(urlButtonTapped), for: .touchUpInside)

    shareButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
    shareButton.tintColor = .secondaryLabel
    shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)

    [titleLabel, metaLabel, urlButton, shareButton].forEach {
      $0.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview($0)
    }

    NSLayoutConstraint.activate([
      titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
      titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

      metaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
      metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      metaLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

      shareButton.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 8),
      shareButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      shareButton.widthAnchor.constraint(equalToConstant: 24),
      shareButton.heightAnchor.constraint(equalToConstant: 24),

      urlButton.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 8),
      urlButton.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      urlButton.trailingAnchor.constraint(equalTo: shareButton.leadingAnchor, constant: -8),
      urlButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
    ])
  }

  private var storyURL: String?

  func configure(with story: HNStory) {
    self.story = story
    titleLabel.text = story.title

    // Make username tappable
    let timeAgoText = timeAgo(from: story.time)
    let fullText = "\(story.score) points by \(story.by) • \(timeAgoText) • \(story.descendants) comments"
    let attributedText = NSMutableAttributedString(string: fullText)
    let usernameRange = (fullText as NSString).range(of: story.by)
    attributedText.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: usernameRange)
    metaLabel.attributedText = attributedText
    metaLabel.isUserInteractionEnabled = true

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(usernameTapped))
    metaLabel.addGestureRecognizer(tapGesture)

    if let url = story.url {
      storyURL = url
      if let parsedURL = URL(string: url), let host = parsedURL.host {
        urlButton.setTitle(host, for: .normal)
      } else {
        urlButton.setTitle(url, for: .normal)
      }
      urlButton.isHidden = false
    } else {
      urlButton.isHidden = true
    }
  }

  @objc private func usernameTapped() {
    guard let story else { return }
    if let viewController = findViewController() {
      viewController.navigationItem.backButtonTitle = ""
      let userVC = UserViewController(username: story.by)
      viewController.navigationController?.pushViewController(userVC, animated: true)
    }
  }

  @objc private func urlButtonTapped() {
    guard let urlString = storyURL, let url = URL(string: urlString) else { return }
    UIApplication.shared.open(url)
  }

  @objc private func shareButtonTapped() {
    guard let story else { return }

    var itemsToShare: [Any] = [story.title]
    if let url = story.url {
      itemsToShare.append(url)
    }

    let activityVC = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)

    if let viewController = findViewController() {
      if let popover = activityVC.popoverPresentationController {
        popover.sourceView = shareButton
        popover.sourceRect = shareButton.bounds
      }
      viewController.present(activityVC, animated: true)
    }
  }
}

class SkeletonCommentCell: UITableViewCell {
  private let authorBox = UIView()
  private let timeBox = UIView()
  private let textBox1 = UIView()
  private let textBox2 = UIView()
  private let textBox3 = UIView()
  private let indentView = UIView()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    setupUI()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    [authorBox, timeBox, textBox1, textBox2, textBox3, indentView].forEach {
      $0.backgroundColor = .systemGray5
      $0.layer.cornerRadius = 4
      $0.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview($0)
    }

    indentView.backgroundColor = .systemGray4
    indentView.layer.cornerRadius = 0

    NSLayoutConstraint.activate([
      indentView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      indentView.topAnchor.constraint(equalTo: contentView.topAnchor),
      indentView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      indentView.widthAnchor.constraint(equalToConstant: 2),

      authorBox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      authorBox.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
      authorBox.widthAnchor.constraint(equalToConstant: 60),
      authorBox.heightAnchor.constraint(equalToConstant: 12),

      timeBox.leadingAnchor.constraint(equalTo: authorBox.trailingAnchor, constant: 8),
      timeBox.topAnchor.constraint(equalTo: authorBox.topAnchor),
      timeBox.widthAnchor.constraint(equalToConstant: 40),
      timeBox.heightAnchor.constraint(equalToConstant: 12),

      textBox1.leadingAnchor.constraint(equalTo: authorBox.leadingAnchor),
      textBox1.topAnchor.constraint(equalTo: authorBox.bottomAnchor, constant: 8),
      textBox1.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      textBox1.heightAnchor.constraint(equalToConstant: 14),

      textBox2.leadingAnchor.constraint(equalTo: authorBox.leadingAnchor),
      textBox2.topAnchor.constraint(equalTo: textBox1.bottomAnchor, constant: 4),
      textBox2.widthAnchor.constraint(equalTo: textBox1.widthAnchor, multiplier: 0.8),
      textBox2.heightAnchor.constraint(equalToConstant: 14),

      textBox3.leadingAnchor.constraint(equalTo: authorBox.leadingAnchor),
      textBox3.topAnchor.constraint(equalTo: textBox2.bottomAnchor, constant: 4),
      textBox3.widthAnchor.constraint(equalTo: textBox1.widthAnchor, multiplier: 0.6),
      textBox3.heightAnchor.constraint(equalToConstant: 14),
      textBox3.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
    ])
  }

  func configure(depth: Int) {
    let indentWidth = CGFloat(depth * 20)
    indentView.isHidden = depth == 0

    // Update leading constraints for indentation
    authorBox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16 + indentWidth).isActive = true
  }
}

class CommentCell: UITableViewCell {
  private let authorLabel = UILabel()
  private let timeLabel = UILabel()
  private let commentTextView = UITextView()
  private let indentView = UIView()
  private let loadRepliesButton = UIButton()
  private let collapseButton = UIButton(type: .system)
  private let topBarView = UIView()
  private let showParentButton = UIButton()
  private var onLoadReplies: ((Int) -> Void)?
  var onCollapse: ((CommentNode) -> Void)?
  private var commentId: Int?
  private var commentNode: CommentNode?
  private var depthLines: [UIView] = []

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    setupUI()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    authorLabel.font = .systemFont(ofSize: 12, weight: .medium)
    authorLabel.textColor = .systemBlue
    authorLabel.isUserInteractionEnabled = true
    let userTapGesture = UITapGestureRecognizer(target: self, action: #selector(usernameTapped))
    authorLabel.addGestureRecognizer(userTapGesture)

    timeLabel.font = .systemFont(ofSize: 12)
    timeLabel.textColor = .secondaryLabel

    commentTextView.font = .systemFont(ofSize: 14)
    commentTextView.isEditable = false
    commentTextView.isScrollEnabled = false
    commentTextView.backgroundColor = .clear
    commentTextView.textContainer.lineFragmentPadding = 0
    commentTextView.textContainerInset = .zero

    indentView.backgroundColor = .systemGray4

    loadRepliesButton.setTitleColor(.systemBlue, for: .normal)
    loadRepliesButton.titleLabel?.font = .systemFont(ofSize: 11)
    loadRepliesButton.contentHorizontalAlignment = .left
    loadRepliesButton.addTarget(self, action: #selector(loadRepliesButtonTapped), for: .touchUpInside)
    loadRepliesButton.isHidden = true

    collapseButton.setTitle("▼", for: .normal)
    collapseButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
    collapseButton.setTitleColor(.systemGray3, for: .normal)
    collapseButton.addTarget(self, action: #selector(collapseTapped), for: .touchUpInside)

    showParentButton.setTitle("show parent", for: .normal)
    showParentButton.setTitleColor(.systemBlue, for: .normal)
    showParentButton.titleLabel?.font = .systemFont(ofSize: 11)
    showParentButton.contentHorizontalAlignment = .left
    showParentButton.addTarget(self, action: #selector(showParentTapped), for: .touchUpInside)
    showParentButton.isHidden = true

    topBarView.backgroundColor = .clear
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(topBarTapped))
    topBarView.addGestureRecognizer(tapGesture)

    [indentView, topBarView, authorLabel, timeLabel, commentTextView, loadRepliesButton, collapseButton, showParentButton].forEach {
      $0.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview($0)
    }

    NSLayoutConstraint.activate([
      indentView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      indentView.topAnchor.constraint(equalTo: contentView.topAnchor),
      indentView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      indentView.widthAnchor.constraint(equalToConstant: 2),

      authorLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),

      timeLabel.topAnchor.constraint(equalTo: authorLabel.topAnchor),
      timeLabel.leadingAnchor.constraint(equalTo: authorLabel.trailingAnchor, constant: 8),
      timeLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),

      commentTextView.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 6),
      commentTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

      loadRepliesButton.topAnchor.constraint(equalTo: commentTextView.bottomAnchor, constant: 4),
      loadRepliesButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      loadRepliesButton.heightAnchor.constraint(equalToConstant: 20),

      showParentButton.centerYAnchor.constraint(equalTo: collapseButton.centerYAnchor),
      showParentButton.trailingAnchor.constraint(equalTo: collapseButton.leadingAnchor, constant: -4),

      collapseButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
      collapseButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      collapseButton.widthAnchor.constraint(equalToConstant: 20),
      collapseButton.heightAnchor.constraint(equalToConstant: 20),

      topBarView.topAnchor.constraint(equalTo: contentView.topAnchor),
      topBarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      topBarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      topBarView.bottomAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 4)
    ])
  }

  private var leadingConstraints: [NSLayoutConstraint] = []
  private var bottomConstraint: NSLayoutConstraint?

  override func prepareForReuse() {
    super.prepareForReuse()

    // Clean up all dynamic constraints
    NSLayoutConstraint.deactivate(leadingConstraints)
    leadingConstraints.removeAll()
    bottomConstraint?.isActive = false
    bottomConstraint = nil

    // Remove depth lines
    depthLines.forEach { $0.removeFromSuperview() }
    depthLines.removeAll()
  }

  func configure(with commentNode: CommentNode, onLoadReplies: @escaping (Int) -> Void, showParent: Bool = false) {
    let comment = commentNode.comment
    commentId = comment.id
    self.commentNode = commentNode
    self.onLoadReplies = onLoadReplies

    // Reset cell state for reuse
    authorLabel.isHidden = false
    timeLabel.isHidden = false
    commentTextView.isHidden = commentNode.isCollapsed
    loadRepliesButton.isHidden = true
    collapseButton.isHidden = false
    showParentButton.isHidden = !showParent || comment.parent == nil

    authorLabel.text = comment.by ?? "[deleted]"
    timeLabel.text = timeAgo(from: comment.time)

    if let text = comment.text {
      commentTextView.attributedText = text.htmlFormatted
    } else {
      commentTextView.text = "[deleted]"
      commentTextView.textColor = .secondaryLabel
    }

    // Remove old constraints
    NSLayoutConstraint.deactivate(leadingConstraints)
    leadingConstraints.removeAll()

    // Remove old depth lines
    depthLines.forEach { $0.removeFromSuperview() }
    depthLines.removeAll()

    // Calculate indentation and create depth lines
    let indentWidth = CGFloat(commentNode.depth * 20)

    // Create depth lines for visual hierarchy
    for depth in 0 ..< commentNode.depth {
      let lineView = UIView()
      lineView.backgroundColor = .systemGray5
      lineView.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(lineView)
      depthLines.append(lineView)

      let xPosition = CGFloat(depth * 20) + 16
      NSLayoutConstraint.activate([
        lineView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: xPosition),
        lineView.topAnchor.constraint(equalTo: contentView.topAnchor),
        lineView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        lineView.widthAnchor.constraint(equalToConstant: 1)
      ])
    }

    indentView.isHidden = true

    // Add new constraints with proper indentation (excluding show parent button leading constraint)
    let authorLeading = authorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16 + indentWidth)
    let textLeading = commentTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16 + indentWidth)
    let buttonLeading = loadRepliesButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16 + indentWidth)

    leadingConstraints = [authorLeading, textLeading, buttonLeading]
    NSLayoutConstraint.activate(leadingConstraints)

    // Update collapse button
    collapseButton.setTitle(commentNode.isCollapsed ? "◀" : "▼", for: .normal)

    // Remove old bottom constraint
    bottomConstraint?.isActive = false

    // Set bottom constraint based on collapse state and button visibility
    if commentNode.isCollapsed {
      bottomConstraint = authorLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
    } else if !loadRepliesButton.isHidden {
      bottomConstraint = loadRepliesButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
    } else {
      bottomConstraint = commentTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
    }
    bottomConstraint?.isActive = true
  }

  func configureAsLoadReplies(commentId: Int, depth: Int, onLoadReplies: @escaping (Int) -> Void) {
    self.commentId = commentId
    self.onLoadReplies = onLoadReplies

    // Disable cell selection for load replies cells
    selectionStyle = .none

    // Hide comment content and collapse button
    authorLabel.isHidden = true
    timeLabel.isHidden = true
    commentTextView.isHidden = true
    collapseButton.isHidden = true
    showParentButton.isHidden = true

    // Show and configure load replies button
    loadRepliesButton.setTitle("load replies", for: .normal)
    loadRepliesButton.isHidden = false

    // Remove old constraints
    NSLayoutConstraint.deactivate(leadingConstraints)
    leadingConstraints.removeAll()

    // Remove old depth lines
    depthLines.forEach { $0.removeFromSuperview() }
    depthLines.removeAll()

    // Calculate indentation and create depth lines
    let indentWidth = CGFloat(depth * 20)

    // Create depth lines for visual hierarchy
    for d in 0 ..< depth {
      let lineView = UIView()
      lineView.backgroundColor = .systemGray5
      lineView.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(lineView)
      depthLines.append(lineView)

      let xPosition = CGFloat(d * 20) + 16
      NSLayoutConstraint.activate([
        lineView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: xPosition),
        lineView.topAnchor.constraint(equalTo: contentView.topAnchor),
        lineView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        lineView.widthAnchor.constraint(equalToConstant: 1)
      ])
    }

    indentView.isHidden = true

    // Add constraints for load replies button only
    let buttonLeading = loadRepliesButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16 + indentWidth)
    let buttonTop = loadRepliesButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8)

    leadingConstraints = [buttonLeading, buttonTop]
    NSLayoutConstraint.activate(leadingConstraints)

    bottomConstraint = loadRepliesButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
    bottomConstraint?.isActive = true
  }

  @objc private func loadRepliesButtonTapped() {
    guard let commentId else { return }
    loadRepliesButton.setTitle("loading...", for: .normal)
    loadRepliesButton.isEnabled = false
    onLoadReplies?(commentId)
  }

  @objc private func collapseTapped() {
    guard let commentNode else { return }
    onCollapse?(commentNode)
  }

  @objc private func topBarTapped() {
    guard let commentNode else { return }
    onCollapse?(commentNode)
  }

  @objc private func usernameTapped() {
    guard let username = authorLabel.text, username != "[deleted]" else { return }
    if let viewController = findViewController() {
      viewController.navigationItem.backButtonTitle = ""
      let userVC = UserViewController(username: username)
      viewController.navigationController?.pushViewController(userVC, animated: true)
    }
  }

  @objc private func showParentTapped() {
    guard let commentNode, let parentId = commentNode.comment.parent else { return }
    guard let viewController = findViewController() else { return }

    // First fetch the parent to determine if it's a comment or story
    guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(parentId).json") else { return }

    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

      DispatchQueue.main.async {
        viewController.navigationItem.backButtonTitle = ""

        // Check if parent is a story (has title) or comment
        if json["title"] != nil {
          // Parent is a story
          let story = HNStory(
            id: parentId,
            title: json["title"] as? String ?? "[No title]",
            url: json["url"] as? String,
            score: json["score"] as? Int ?? 0,
            by: json["by"] as? String ?? "unknown",
            time: json["time"] as? Int ?? 0,
            descendants: json["descendants"] as? Int ?? 0
          )
          let commentsVC = CommentsViewController(story: story)
          viewController.navigationController?.pushViewController(commentsVC, animated: true)
        } else {
          // Parent is a comment
          let parentVC = ParentCommentViewController(commentId: parentId)
          viewController.navigationController?.pushViewController(parentVC, animated: true)
        }
      }
    }.resume()
  }
}

class IntrinsicTableView: UITableView {
  override var contentSize: CGSize {
    didSet {
      invalidateIntrinsicContentSize()
    }
  }

  override var intrinsicContentSize: CGSize {
    layoutIfNeeded()
    return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
  }
}

class UserViewController: UIViewController {
  private let username: String
  private let scrollView = UIScrollView()
  private let contentView = UIView()
  private let usernameLabel = UILabel()
  private let karmaLabel = UILabel()
  private let createdLabel = UILabel()
  private let statsLabel = UILabel()
  private let aboutLabel = UILabel()
  private let aboutContainerView = UIView()
  private let metaStackView = UIStackView()
  private let statsStackView = UIStackView()
  private var aboutHeightConstraint: NSLayoutConstraint?
  private var aboutTopConstraint: NSLayoutConstraint?
  private let storiesLabel = UILabel()
  private let storiesTableView = IntrinsicTableView()
  private let activityLabel = UILabel()
  private let activityTableView = IntrinsicTableView()
  private var userStories: [HNStory] = []
  private var userSubmissions: [CommentNode] = []
  private var flattenedSubmissions: [Any] = []

  init(username: String) {
    self.username = username
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    loadUserData()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(false, animated: animated)
    navigationController?.hidesBarsOnSwipe = false
    navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    navigationController?.interactivePopGestureRecognizer?.delegate = self
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.hidesBarsOnSwipe = true
  }

  private func setupUI() {
    view.backgroundColor = .systemBackground
    title = nil // Start with no title
    navigationItem.largeTitleDisplayMode = .never

    scrollView.delegate = self

    usernameLabel.font = .systemFont(ofSize: 24, weight: .bold)
    usernameLabel.text = username

    karmaLabel.font = .systemFont(ofSize: 14)
    karmaLabel.textColor = .secondaryLabel

    createdLabel.font = .systemFont(ofSize: 14)
    createdLabel.textColor = .secondaryLabel
    createdLabel.textAlignment = .right

    statsLabel.font = .systemFont(ofSize: 14)
    statsLabel.textColor = .secondaryLabel

    aboutLabel.font = .systemFont(ofSize: 16)
    aboutLabel.numberOfLines = 0

    aboutContainerView.backgroundColor = .systemGray6
    aboutContainerView.layer.cornerRadius = 12
    aboutContainerView.isHidden = true

    // Setup meta stack view (karma and join date)
    metaStackView.axis = .horizontal
    metaStackView.distribution = .fillEqually
    metaStackView.spacing = 16
    metaStackView.addArrangedSubview(karmaLabel)
    metaStackView.addArrangedSubview(createdLabel)

    // Setup stats stack view (stories and comments)
    statsStackView.axis = .horizontal
    statsStackView.distribution = .fillEqually
    statsStackView.spacing = 16
    statsStackView.addArrangedSubview(statsLabel)

    storiesLabel.font = .systemFont(ofSize: 18, weight: .semibold)
    storiesLabel.text = "Recent Stories"

    storiesTableView.delegate = self
    storiesTableView.dataSource = self
    storiesTableView.register(StoryCell.self, forCellReuseIdentifier: "StoryCell")
    storiesTableView.separatorStyle = .none
    storiesTableView.isScrollEnabled = false

    activityLabel.font = .systemFont(ofSize: 18, weight: .semibold)
    activityLabel.text = "Recent Comments"

    activityTableView.delegate = self
    activityTableView.dataSource = self
    activityTableView.register(CommentCell.self, forCellReuseIdentifier: "CommentCell")
    activityTableView.separatorStyle = .none
    activityTableView.isScrollEnabled = false

    // Override intrinsic content size
    activityTableView.translatesAutoresizingMaskIntoConstraints = false

    [scrollView, contentView, usernameLabel, metaStackView, statsStackView, aboutContainerView, aboutLabel, storiesLabel, storiesTableView, activityLabel, activityTableView].forEach {
      $0.translatesAutoresizingMaskIntoConstraints = false
    }

    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(usernameLabel)
    contentView.addSubview(metaStackView)
    contentView.addSubview(statsStackView)
    contentView.addSubview(aboutContainerView)
    aboutContainerView.addSubview(aboutLabel)
    contentView.addSubview(storiesLabel)
    contentView.addSubview(storiesTableView)
    contentView.addSubview(activityLabel)
    contentView.addSubview(activityTableView)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

      usernameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
      usernameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      usernameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

      metaStackView.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 8),
      metaStackView.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
      metaStackView.trailingAnchor.constraint(equalTo: usernameLabel.trailingAnchor),

      statsStackView.topAnchor.constraint(equalTo: metaStackView.bottomAnchor, constant: 6),
      statsStackView.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
      statsStackView.trailingAnchor.constraint(equalTo: usernameLabel.trailingAnchor),

      aboutContainerView.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
      aboutContainerView.trailingAnchor.constraint(equalTo: usernameLabel.trailingAnchor),

      aboutLabel.topAnchor.constraint(equalTo: aboutContainerView.topAnchor, constant: 12),
      aboutLabel.leadingAnchor.constraint(equalTo: aboutContainerView.leadingAnchor, constant: 12),
      aboutLabel.trailingAnchor.constraint(equalTo: aboutContainerView.trailingAnchor, constant: -12),
      aboutLabel.bottomAnchor.constraint(equalTo: aboutContainerView.bottomAnchor, constant: -12),

      storiesLabel.topAnchor.constraint(greaterThanOrEqualTo: statsStackView.bottomAnchor, constant: 16),
      storiesLabel.topAnchor.constraint(greaterThanOrEqualTo: aboutContainerView.bottomAnchor, constant: 16),
      storiesLabel.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
      storiesLabel.trailingAnchor.constraint(equalTo: usernameLabel.trailingAnchor),

      storiesTableView.topAnchor.constraint(equalTo: storiesLabel.bottomAnchor, constant: 8),
      storiesTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      storiesTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

      activityLabel.topAnchor.constraint(equalTo: storiesTableView.bottomAnchor, constant: 16),
      activityLabel.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
      activityLabel.trailingAnchor.constraint(equalTo: usernameLabel.trailingAnchor),

      activityTableView.topAnchor.constraint(equalTo: activityLabel.bottomAnchor, constant: 8),
      activityTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      activityTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      activityTableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
    ])

    // Set up constraints for about container when hidden
    aboutHeightConstraint = aboutContainerView.heightAnchor.constraint(equalToConstant: 0)
    aboutHeightConstraint?.isActive = true

    aboutTopConstraint = aboutContainerView.topAnchor.constraint(equalTo: statsStackView.bottomAnchor, constant: 0)
    aboutTopConstraint?.isActive = true
  }

  private func loadUserData() {
    guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/user/\(username).json") else { return }

    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
      guard let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

      DispatchQueue.main.async {
        if let karma = json["karma"] as? Int {
          self?.karmaLabel.text = "\(karma) karma"
        }

        if let created = json["created"] as? Int {
          let date = Date(timeIntervalSince1970: TimeInterval(created))
          let formatter = DateFormatter()
          formatter.dateStyle = .medium
          self?.createdLabel.text = "Joined \(formatter.string(from: date))"
        }

        if let about = json["about"] as? String, !about.isEmpty {
          self?.aboutLabel.attributedText = about.htmlFormatted
          self?.aboutContainerView.isHidden = false
          self?.aboutHeightConstraint?.isActive = false
          self?.aboutTopConstraint?.isActive = false

          // Add proper spacing when content is present
          if let aboutContainer = self?.aboutContainerView, let statsStack = self?.statsStackView {
            self?.aboutTopConstraint = aboutContainer.topAnchor.constraint(equalTo: statsStack.bottomAnchor, constant: 12)
            self?.aboutTopConstraint?.isActive = true
          }
        }

        if let submitted = json["submitted"] as? [Int] {
          self?.loadUserSubmissions(submitted)
        }
      }
    }.resume()
  }

  private func loadUserSubmissions(_ submissionIds: [Int]) {
    let recentIds = Array(submissionIds.prefix(20)) // Load recent 20 items
    let group = DispatchGroup()
    var submissions: [(item: [String: Any], timestamp: Int)] = []

    for id in recentIds {
      group.enter()
      guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json") else {
        group.leave()
        continue
      }

      URLSession.shared.dataTask(with: url) { data, _, _ in
        defer { group.leave() }
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let time = json["time"] as? Int else { return }

        submissions.append((item: json, timestamp: time))
      }.resume()
    }

    group.notify(queue: .main) {
      self.displaySubmissions(submissions.sorted { $0.timestamp > $1.timestamp })
    }
  }

  private func displaySubmissions(_ submissions: [(item: [String: Any], timestamp: Int)]) {
    var storyCount = 0
    var commentCount = 0
    userStories.removeAll()
    userSubmissions.removeAll()

    for submission in submissions {
      let item = submission.item
      let isStory = item["type"] as? String == "story" || item["title"] != nil

      if isStory {
        storyCount += 1
        if userStories.count < 5 {
          let story = HNStory(
            id: item["id"] as? Int ?? 0,
            title: item["title"] as? String ?? "[No title]",
            url: item["url"] as? String,
            score: item["score"] as? Int ?? 0,
            by: item["by"] as? String ?? username,
            time: item["time"] as? Int ?? 0,
            descendants: item["descendants"] as? Int ?? 0
          )
          userStories.append(story)
        }
      } else {
        commentCount += 1
        if userSubmissions.count < 5 {
          let comment = HNComment(
            id: item["id"] as? Int ?? 0,
            by: item["by"] as? String,
            text: item["text"] as? String,
            time: item["time"] as? Int ?? 0,
            kids: item["kids"] as? [Int],
            parent: item["parent"] as? Int,
            deleted: item["deleted"] as? Bool ?? false,
            dead: item["dead"] as? Bool ?? false
          )

          let commentNode = CommentNode(comment: comment, children: [], depth: 0)
          userSubmissions.append(commentNode)
        }
      }
    }

    // Remove stats label content since counts are now in section headers
    statsLabel.text = ""
    storiesLabel.text = "Recent Stories (\(storyCount))"
    activityLabel.text = "Recent Comments (\(commentCount))"

    flattenedSubmissions = flattenUserSubmissions(userSubmissions)
    storiesTableView.reloadData()
    activityTableView.reloadData()

    // Force layout update
    DispatchQueue.main.async {
      self.storiesTableView.invalidateIntrinsicContentSize()
      self.activityTableView.invalidateIntrinsicContentSize()
      self.view.layoutIfNeeded()
    }
  }

  private func flattenUserSubmissions(_ nodes: [CommentNode]) -> [Any] {
    var flattened: [Any] = []

    func flatten(_ node: CommentNode) {
      flattened.append(node)
      if !node.isCollapsed {
        for child in node.children {
          flatten(child)
        }
        // Add load replies button if there are unloaded replies
        if node.hasUnloadedReplies {
          flattened.append(("loadReplies", node.comment.id, node.comment.kids?.count ?? 0, node.depth + 1))
        }
      }
    }

    for node in nodes {
      flatten(node)
    }

    return flattened
  }
}

extension UserViewController: UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // Show username in navbar when scrolled past the username label
    let shouldShowTitle = scrollView.contentOffset.y > usernameLabel.frame.maxY

    title = shouldShowTitle ? username : nil
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if tableView == storiesTableView {
      return userStories.count
    }
    return flattenedSubmissions.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if tableView == storiesTableView {
      let cell = tableView.dequeueReusableCell(withIdentifier: "StoryCell", for: indexPath) as! StoryCell
      cell.configure(with: userStories[indexPath.row])
      return cell
    }

    let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as! CommentCell
    let item = flattenedSubmissions[indexPath.row]

    if let commentNode = item as? CommentNode {
      cell.configure(with: commentNode, onLoadReplies: { [weak self] commentId in
        self?.loadRepliesForComment(commentId: commentId)
      }, showParent: commentNode.depth == 0)
      cell.onCollapse = { [weak self] node in
        node.isCollapsed.toggle()
        self?.flattenedSubmissions = self?.flattenUserSubmissions(self?.userSubmissions ?? []) ?? []
        self?.activityTableView.reloadData()
      }
    } else if let loadRepliesData = item as? (String, Int, Int, Int) {
      cell.configureAsLoadReplies(commentId: loadRepliesData.1, depth: loadRepliesData.3) { [weak self] commentId in
        self?.loadRepliesForComment(commentId: commentId)
      }
    }

    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if tableView == storiesTableView {
      let story = userStories[indexPath.row]
      let commentsVC = CommentsViewController(story: story)
      navigationController?.pushViewController(commentsVC, animated: true)
    }
  }

  private func loadRepliesForComment(commentId: Int) {
    guard let comment = findComment(id: commentId, in: userSubmissions) else { return }
    guard let kids = comment.comment.kids else { return }

    let group = DispatchGroup()
    var newChildren: [CommentNode] = []

    for id in kids {
      group.enter()
      loadComment(id: id) { childComment in
        defer { group.leave() }
        guard let childComment, !childComment.deleted, !childComment.dead else { return }

        let childNode = CommentNode(comment: childComment, children: [], depth: comment.depth + 1)
        newChildren.append(childNode)
      }
    }

    group.notify(queue: .main) {
      comment.children = newChildren
      comment.loadedToMaxDepth = true
      self.flattenedSubmissions = self.flattenUserSubmissions(self.userSubmissions)
      self.activityTableView.reloadData()
    }
  }

  private func findComment(id: Int, in nodes: [CommentNode]) -> CommentNode? {
    for node in nodes {
      if node.comment.id == id {
        return node
      }
      if let found = findComment(id: id, in: node.children) {
        return found
      }
    }
    return nil
  }

  private func loadComment(id: Int, completion: @escaping (HNComment?) -> Void) {
    guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json") else {
      completion(nil)
      return
    }

    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        completion(nil)
        return
      }

      let comment = HNComment(
        id: json["id"] as? Int ?? id,
        by: json["by"] as? String,
        text: json["text"] as? String,
        time: json["time"] as? Int ?? 0,
        kids: json["kids"] as? [Int],
        parent: json["parent"] as? Int,
        deleted: json["deleted"] as? Bool ?? false,
        dead: json["dead"] as? Bool ?? false
      )

      completion(comment)
    }.resume()
  }
}

class SettingsViewController: UIViewController {
  private let tableView = UITableView(frame: .zero, style: .insetGrouped)
  private var sessionData: [(String, String)] = []
  private var configData: [(String, String)] = []
  private var troubleshootingData: [(String, String)] = []
  private var timer: Timer?

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    loadSessionData()
    startTimer()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    loadSessionData()
    startTimer()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    timer?.invalidate()
    timer = nil
  }

  private func setupUI() {
    view.backgroundColor = .systemGroupedBackground

    tableView.delegate = self
    tableView.dataSource = self
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    tableView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  private func loadSessionData() {
    configData = [
      ("Service Name", TelemetryConfig.serviceName),
      ("Logs Endpoint", TelemetryConfig.logsEndpoint.absoluteString),
      ("Traces Endpoint", TelemetryConfig.tracesEndpoint.absoluteString)
    ]

    troubleshootingData = [
      ("Trigger App Hang", "Tap to configure")
    ]

    guard let currentSession = SessionManagerProvider.getInstance().peekSession() else {
      sessionData = [
        ("User ID", "nil"),
        ("Previous Session", "nil"),
        ("Current Session", "nil"),
        ("Session Expiry", "nil")
      ]
      tableView.reloadData()
      return
    }

    let expireTime = currentSession.expireTime
    let userId = UserIdStore.getUID()
    let timeToExpiry = expireTime.timeIntervalSinceNow
    let previousSessionId = SessionManagerProvider.getInstance().peekSession()?.previousId ?? "nil"

    sessionData = [
      ("User ID", userId),
      ("Previous Session", previousSessionId),
      ("Current Session", currentSession.id),
      ("Session Expiry", "\(Int(timeToExpiry)) seconds")
    ]

    tableView.reloadData()
  }

  private func startTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      self?.updateExpiryTime()
    }
  }

  private func updateExpiryTime() {
    guard let currentSession = SessionManagerProvider.getInstance().peekSession() else {
      return
    }

    let expireTime = currentSession.expireTime
    let timeToExpiry = expireTime.timeIntervalSinceNow

    let expiryText = timeToExpiry <= 0 ? "Expired" : "\(Int(timeToExpiry)) seconds"
    sessionData[3] = ("Session Expiry", expiryText)

    if let cell = tableView.cellForRow(at: IndexPath(row: 3, section: 1)) {
      cell.detailTextLabel?.text = expiryText
    }
  }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 3
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0: return configData.count
    case 1: return sessionData.count
    case 2: return troubleshootingData.count
    default: return 0
    }
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return UITableView.automaticDimension
  }

  func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
    return 44
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    if indexPath.section == 2, indexPath.row == 0 {
      showHangTriggerPicker()
      return
    }

    let (title, value): (String, String)
    switch indexPath.section {
    case 0: (title, value) = configData[indexPath.row]
    case 1: (title, value) = sessionData[indexPath.row]
    case 2: (title, value) = troubleshootingData[indexPath.row]
    default: return
    }

    if title != "Session Expiry", indexPath.section != 2 {
      UIPasteboard.general.string = value
      showCopiedToast()
    }
  }

  private func showCopiedToast() {
    let toast = UILabel()
    toast.text = "Copied to Clipboard"
    toast.font = .systemFont(ofSize: 14, weight: .medium)
    toast.textColor = .white
    toast.backgroundColor = .black.withAlphaComponent(0.8)
    toast.textAlignment = .center
    toast.layer.cornerRadius = 8
    toast.clipsToBounds = true
    toast.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(toast)
    NSLayoutConstraint.activate([
      toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
      toast.widthAnchor.constraint(equalToConstant: 160),
      toast.heightAnchor.constraint(equalToConstant: 36)
    ])

    toast.alpha = 0
    UIView.animate(withDuration: 0.3, animations: {
      toast.alpha = 1
    }) { _ in
      UIView.animate(withDuration: 0.3, delay: 1.5, animations: {
        toast.alpha = 0
      }) { _ in
        toast.removeFromSuperview()
      }
    }
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .value1, reuseIdentifier: "Cell")

    let (title, value): (String, String)
    switch indexPath.section {
    case 0: (title, value) = configData[indexPath.row]
    case 1: (title, value) = sessionData[indexPath.row]
    case 2: (title, value) = troubleshootingData[indexPath.row]
    default: return cell
    }

    cell.textLabel?.text = title
    cell.textLabel?.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
    cell.detailTextLabel?.text = value
    cell.detailTextLabel?.numberOfLines = 0
    cell.detailTextLabel?.lineBreakMode = .byWordWrapping
    cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
    cell.detailTextLabel?.textAlignment = .right

    if indexPath.section == 2 {
      cell.accessoryType = .disclosureIndicator
      cell.selectionStyle = .default
    } else if title != "Session Expiry" {
      cell.selectionStyle = .default
    } else {
      cell.selectionStyle = .none
    }

    return cell
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
    case 0: return "OTel Config"
    case 1: return "User Session"
    case 2: return "Troubleshooting"
    default: return nil
    }
  }

  private func showHangTriggerPicker() {
    let alert = UIAlertController(title: "Trigger App Hang", message: "Select hang type and duration", preferredStyle: .actionSheet)

    let pickerView = HangConfigPickerView()
    alert.setValue(pickerView, forKey: "contentViewController")

    alert.addAction(UIAlertAction(title: "Trigger Hang", style: .destructive) { _ in
      let duration = pickerView.selectedDuration
      let hangType = pickerView.selectedHangType
      self.triggerAppHang(type: hangType, duration: duration)
    })

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    if let popover = alert.popoverPresentationController {
      popover.sourceView = tableView
      popover.sourceRect = tableView.rectForRow(at: IndexPath(row: 0, section: 2))
    }

    present(alert, animated: true)
  }

  private func triggerAppHang(type: HangType, duration: TimeInterval) {
    let durationText = String(format: "%.2fs", duration)
    let toast = createToast(text: "\(durationText) Hang Starting in 3...")

    var countdown = 3
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
      countdown -= 1
      if countdown > 0 {
        toast.text = "\(durationText) Hang Starting in \(countdown)..."
      } else {
        timer.invalidate()
        toast.text = "\(type.displayName) for \(durationText)"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          let start = Date()

          switch type {
          case .threadSleep:
            Thread.sleep(forTimeInterval: duration)
          case .syncNetworkCall:
            self.performSyncNetworkCall(duration: duration)
          case .cpuIntensiveTask:
            self.performCpuIntensiveTask(duration: duration)
          }

          let end = Date()
          let span = OpenTelemetry.instance.tracerProvider.get(instrumentationName: debugScope)
            .spanBuilder(spanName: "[DEBUG] Triggered Hang - \(type.displayName)")
            .setStartTime(time: start)
            .startSpan()
          span.end(time: end)

          toast.text = "\(durationText) Hang Completed!"

          DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            toast.removeFromSuperview()
          }
        }
      }
    }
  }

  private func performSyncNetworkCall(duration: TimeInterval) {
    let endTime = Date().addingTimeInterval(duration)
    let semaphore = DispatchSemaphore(value: 0)

    func makeRequest() {
      guard Date() < endTime else {
        semaphore.signal()
        return
      }

      let url = URL(string: "https://httpbin.org/delay/1")!
      let task = URLSession.shared.dataTask(with: url) { _, _, _ in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          makeRequest()
        }
      }
      task.resume()
    }

    makeRequest()
    semaphore.wait()
  }

  private func performCpuIntensiveTask(duration: TimeInterval) {
    let endTime = Date().addingTimeInterval(duration)
    var counter = 0

    while Date() < endTime {
      for i in 0 ..< 100000 {
        counter += i * i
      }
    }
  }

  private func createToast(text: String) -> UILabel {
    let toast = UILabel()
    toast.text = text
    toast.font = .systemFont(ofSize: 16, weight: .medium)
    toast.textColor = .white
    toast.backgroundColor = .systemRed.withAlphaComponent(0.9)
    toast.textAlignment = .center
    toast.layer.cornerRadius = 8
    toast.clipsToBounds = true
    toast.translatesAutoresizingMaskIntoConstraints = false

    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else { return toast }
    window.addSubview(toast)
    NSLayoutConstraint.activate([
      toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
      toast.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 20),
      toast.widthAnchor.constraint(equalToConstant: 200),
      toast.heightAnchor.constraint(equalToConstant: 40)
    ])

    return toast
  }
}

extension String {
  var htmlStripped: String {
    return replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
      .replacingOccurrences(of: "&quot;", with: "\"")
      .replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
      .replacingOccurrences(of: "&#x27;", with: "'")
      .replacingOccurrences(of: "&#x2F;", with: "/")
      .replacingOccurrences(of: "&#39;", with: "'")
  }

  var htmlFormatted: NSAttributedString {
    // First decode HTML entities
    let processedText = replacingOccurrences(of: "&quot;", with: "\"")
      .replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
      .replacingOccurrences(of: "&#x27;", with: "'")
      .replacingOccurrences(of: "&#x2F;", with: "/")
      .replacingOccurrences(of: "&#39;", with: "'")

    let mutableString = NSMutableAttributedString(string: processedText)
    let baseFont = UIFont.systemFont(ofSize: 14)

    mutableString.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: mutableString.length))
    mutableString.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: mutableString.length))

    // Set paragraph spacing to 0.35em (3pt for 14pt font)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacing = 5
    mutableString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutableString.length))

    // Handle <p> tags - convert to line breaks
    let pPattern = "<p>"
    let pRegex = try! NSRegularExpression(pattern: pPattern, options: .caseInsensitive)
    let pMatches = pRegex.matches(in: mutableString.string, range: NSRange(location: 0, length: mutableString.length))

    for match in pMatches.reversed() {
      mutableString.replaceCharacters(in: match.range, with: "\n")
    }

    // Handle <i> and <em> tags - italic
    let italicPattern = "<(i|em)>(.*?)</(i|em)>"
    let italicRegex = try! NSRegularExpression(pattern: italicPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    let italicMatches = italicRegex.matches(in: mutableString.string, range: NSRange(location: 0, length: mutableString.length))

    for match in italicMatches.reversed() {
      let range = match.range(at: 2)
      let fullRange = match.range
      let italicText = (mutableString.string as NSString).substring(with: range)

      mutableString.replaceCharacters(in: fullRange, with: italicText)
      let newRange = NSRange(location: fullRange.location, length: italicText.count)
      mutableString.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: 14), range: newRange)
    }

    // Handle <b> and <strong> tags - bold
    let boldPattern = "<(b|strong)>(.*?)</(b|strong)>"
    let boldRegex = try! NSRegularExpression(pattern: boldPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    let boldMatches = boldRegex.matches(in: mutableString.string, range: NSRange(location: 0, length: mutableString.length))

    for match in boldMatches.reversed() {
      let range = match.range(at: 2)
      let fullRange = match.range
      let boldText = (mutableString.string as NSString).substring(with: range)

      mutableString.replaceCharacters(in: fullRange, with: boldText)
      let newRange = NSRange(location: fullRange.location, length: boldText.count)
      mutableString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 14), range: newRange)
    }

    // Handle <code> tags
    let codePattern = "<code>(.*?)</code>"
    let codeRegex = try! NSRegularExpression(pattern: codePattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    let codeMatches = codeRegex.matches(in: mutableString.string, range: NSRange(location: 0, length: mutableString.length))

    for match in codeMatches.reversed() {
      let range = match.range(at: 1)
      let fullRange = match.range
      let codeText = (mutableString.string as NSString).substring(with: range)

      mutableString.replaceCharacters(in: fullRange, with: " \(codeText) ")
      let newRange = NSRange(location: fullRange.location, length: codeText.count + 2)
      mutableString.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: newRange)
      mutableString.addAttribute(.backgroundColor, value: UIColor.systemGray5, range: newRange)
    }

    // Handle <a> tags - make links blue
    let linkPattern = "<a[^>]*>(.*?)</a>"
    let linkRegex = try! NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    let linkMatches = linkRegex.matches(in: mutableString.string, range: NSRange(location: 0, length: mutableString.length))

    for match in linkMatches.reversed() {
      let range = match.range(at: 1)
      let fullRange = match.range
      let linkText = (mutableString.string as NSString).substring(with: range)

      mutableString.replaceCharacters(in: fullRange, with: linkText)
      let newRange = NSRange(location: fullRange.location, length: linkText.count)
      mutableString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: newRange)
    }

    // Handle bullet points - lines starting with * or -
    let bulletPattern = "^[\\*\\-]\\s+(.*)$"
    let bulletRegex = try! NSRegularExpression(pattern: bulletPattern, options: [.anchorsMatchLines])
    let bulletMatches = bulletRegex.matches(in: mutableString.string, range: NSRange(location: 0, length: mutableString.length))

    for match in bulletMatches.reversed() {
      let fullRange = match.range
      let bulletText = (mutableString.string as NSString).substring(with: match.range(at: 1))

      mutableString.replaceCharacters(in: fullRange, with: "• \(bulletText)")
      let newRange = NSRange(location: fullRange.location, length: bulletText.count + 2)

      // Add hanging indent for bullet points
      let bulletParagraphStyle = NSMutableParagraphStyle()
      bulletParagraphStyle.firstLineHeadIndent = 0
      bulletParagraphStyle.headIndent = 12 // Indent continuation lines
      bulletParagraphStyle.paragraphSpacing = 5
      mutableString.addAttribute(.paragraphStyle, value: bulletParagraphStyle, range: newRange)
    }

    // Handle blockquotes - lines starting with > (with or without space)
    let quotePattern = "^>\\s?(.*)$"
    let quoteRegex = try! NSRegularExpression(pattern: quotePattern, options: [.anchorsMatchLines])
    let quoteMatches = quoteRegex.matches(in: mutableString.string, range: NSRange(location: 0, length: mutableString.length))

    for match in quoteMatches.reversed() {
      let fullRange = match.range
      let quotedText = (mutableString.string as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)

      mutableString.replaceCharacters(in: fullRange, with: "▎ \(quotedText)")
      let newRange = NSRange(location: fullRange.location, length: quotedText.count + 2)
      mutableString.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: newRange)
      mutableString.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: 14), range: NSRange(location: fullRange.location + 2, length: quotedText.count))

      // Add hanging indent for blockquotes with tab stops for continuous bar
      let quoteParagraphStyle = NSMutableParagraphStyle()
      quoteParagraphStyle.firstLineHeadIndent = 0
      quoteParagraphStyle.headIndent = 12
      quoteParagraphStyle.paragraphSpacing = 5

      // Add tab stop to create continuous vertical bar effect
      let tabStop = NSTextTab(textAlignment: .left, location: 12)
      quoteParagraphStyle.tabStops = [tabStop]

      mutableString.addAttribute(.paragraphStyle, value: quoteParagraphStyle, range: newRange)
    }

    // Clean up any remaining HTML tags
    let cleanupPattern = "<[^>]+>"
    let cleanupRegex = try! NSRegularExpression(pattern: cleanupPattern)
    let cleanupMatches = cleanupRegex.matches(in: mutableString.string, range: NSRange(location: 0, length: mutableString.length))

    for match in cleanupMatches.reversed() {
      mutableString.replaceCharacters(in: match.range, with: "")
    }

    return mutableString
  }
}

class ParentCommentViewController: UIViewController {
  private let commentId: Int
  private let tableView = UITableView()
  private var comments: [Any] = []
  private var rootComment: CommentNode?
  private var isLoading = true

  init(commentId: Int) {
    self.commentId = commentId
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    loadParentComment()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(false, animated: animated)
    navigationController?.hidesBarsOnSwipe = false
    navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    navigationController?.interactivePopGestureRecognizer?.delegate = self
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.hidesBarsOnSwipe = true
  }

  private func setupUI() {
    view.backgroundColor = .systemBackground
    title = nil

    tableView.delegate = self
    tableView.dataSource = self
    tableView.register(CommentCell.self, forCellReuseIdentifier: "CommentCell")
    tableView.register(SkeletonCommentCell.self, forCellReuseIdentifier: "SkeletonCommentCell")
    tableView.separatorStyle = .none
    tableView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  private func loadParentComment() {
    // Load comment tree with generous thresholds
    loadCommentWithDepth(id: commentId, depth: 0, maxDepth: 5) { [weak self] node in
      DispatchQueue.main.asyncAfter(deadline: .now() + artificialDelay) {
        self?.rootComment = node
        self?.comments = self?.flattenCommentTree(node != nil ? [node!] : []) ?? []
        self?.isLoading = false
        self?.tableView.reloadData()
      }
    }
  }

  private func loadCommentWithDepth(id: Int, depth: Int, maxDepth: Int, completion: @escaping (CommentNode?) -> Void) {
    loadComment(id: id) { comment in
      guard let comment, !comment.deleted, !comment.dead else {
        completion(nil)
        return
      }

      if depth >= maxDepth || comment.kids == nil || comment.kids!.isEmpty {
        let node = CommentNode(comment: comment, children: [], depth: depth)
        completion(node)
        return
      }

      let group = DispatchGroup()
      var children: [CommentNode] = []

      // Generous thresholds for initial loading
      let maxReplies = depth == 0 ? 10 : 5
      let kidsToLoad = Array(comment.kids!.prefix(maxReplies))

      for kidId in kidsToLoad {
        group.enter()
        self.loadCommentWithDepth(id: kidId, depth: depth + 1, maxDepth: maxDepth) { childNode in
          if let childNode {
            children.append(childNode)
          }
          group.leave()
        }
      }

      group.notify(queue: .global()) {
        let node = CommentNode(comment: comment, children: children, depth: depth)
        completion(node)
      }
    }
  }

  private func loadComment(id: Int, completion: @escaping (HNComment?) -> Void) {
    guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json") else {
      completion(nil)
      return
    }

    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        completion(nil)
        return
      }

      let comment = HNComment(
        id: json["id"] as? Int ?? id,
        by: json["by"] as? String,
        text: json["text"] as? String,
        time: json["time"] as? Int ?? 0,
        kids: json["kids"] as? [Int],
        parent: json["parent"] as? Int,
        deleted: json["deleted"] as? Bool ?? false,
        dead: json["dead"] as? Bool ?? false
      )

      completion(comment)
    }.resume()
  }

  private func flattenCommentTree(_ nodes: [CommentNode]) -> [Any] {
    var flattened: [Any] = []

    func flatten(_ node: CommentNode) {
      flattened.append(node)
      if !node.isCollapsed {
        for child in node.children {
          flatten(child)
        }
        if node.hasUnloadedReplies {
          flattened.append(("loadReplies", node.comment.id, node.unloadedReplyCount, node.depth + 1))
        }
      }
    }

    for node in nodes {
      flatten(node)
    }

    return flattened
  }
}

extension CommentsViewController: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}

extension UserViewController: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}

extension ParentCommentViewController: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}

extension ParentCommentViewController: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if isLoading {
      return 5
    }
    return comments.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if isLoading {
      let cell = tableView.dequeueReusableCell(withIdentifier: "SkeletonCommentCell", for: indexPath) as! SkeletonCommentCell
      cell.configure(depth: indexPath.row % 3)
      return cell
    }

    let item = comments[indexPath.row]
    if let commentNode = item as? CommentNode {
      let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as! CommentCell
      cell.configure(with: commentNode, onLoadReplies: { _ in }, showParent: commentNode.depth == 0)
      cell.onCollapse = { [weak self] node in
        node.isCollapsed.toggle()
        self?.comments = self?.flattenCommentTree(self?.rootComment != nil ? [self!.rootComment!] : []) ?? []
        self?.tableView.reloadData()
      }
      return cell
    }

    return UITableViewCell()
  }
}

enum HangType: CaseIterable {
  case threadSleep
  case syncNetworkCall
  case cpuIntensiveTask

  var displayName: String {
    switch self {
    case .threadSleep: return "Thread Sleep"
    case .syncNetworkCall: return "Blocking HTTP"
    case .cpuIntensiveTask: return "CPU Busy"
    }
  }
}

class HangConfigPickerView: UIViewController {
  private let pickerView = UIPickerView()
  private let hangTypes = HangType.allCases

  private var selectedHangTypeIndex: Int = 0
  private var seconds: Int = 1
  private var centiseconds: Int = 0

  var selectedHangType: HangType {
    return hangTypes[selectedHangTypeIndex]
  }

  var selectedDuration: TimeInterval {
    return TimeInterval(seconds) + TimeInterval(centiseconds) / 100.0
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
  }

  private func setupUI() {
    view.backgroundColor = .clear

    pickerView.dataSource = self
    pickerView.delegate = self
    pickerView.selectRow(0, inComponent: 0, animated: false)
    pickerView.selectRow(1, inComponent: 1, animated: false)
    pickerView.selectRow(0, inComponent: 2, animated: false)
    pickerView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(pickerView)

    NSLayoutConstraint.activate([
      pickerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
      pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      pickerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
    ])

    preferredContentSize = CGSize(width: 320, height: 180)
  }
}

extension HangConfigPickerView: UIPickerViewDataSource, UIPickerViewDelegate {
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 3
  }

  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    switch component {
    case 0: return hangTypes.count
    case 1: return 60 // 0-59 seconds
    case 2: return 100 // 0-99 centiseconds
    default: return 0
    }
  }

  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    switch component {
    case 0: return hangTypes[row].displayName
    case 1: return "\(row) sec"
    case 2: return String(format: ".%02d", row)
    default: return nil
    }
  }

  func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    switch component {
    case 0: selectedHangTypeIndex = row
    case 1: seconds = row
    case 2: centiseconds = row
    default: break
    }
  }
}
