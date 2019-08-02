//
//  DirectoryCrawler.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 5/5/19.
//  Copyright © 2019 dbeard. All rights reserved.
//

import Foundation
import AVFoundation

// Walks an input directory searching for teslaCam recordings.
// Returns an ordered list of recordings containing left, front, and right repeater video
// if the left and right repeater files are not found, they are not used here.

enum TeslaCameraType: String {
    case front
    case left
    case right

    func rawValue() -> String {
        switch self {
        case .front:            return "front"
        case .right:            return "right_repeater"
        case .left:             return "left_repeater"
        }
    }
}

struct TeslaCamVideo: Equatable, Hashable {
    var fileName: String
    var fileURL: URL
    var creationDate: Date
    var cameraType: TeslaCameraType

    init?(fileURL: URL) {
        self.fileName = fileURL.absoluteString
        self.fileURL = fileURL

        let lastPathComponent = fileURL.lastPathComponent
        let fileNameWithoutExtension = lastPathComponent.dropLast(4) // remove .mp4
        var components = fileNameWithoutExtension.split(separator: "-")

        let repeaterType = components.last
        switch repeaterType {
            case "front":           self.cameraType = .front
            case "right_repeater":  self.cameraType = .right
            case "left_repeater":   self.cameraType = .left
            //TODO: Ignore, but log these in future.
            default: return nil//fatalError("Unknown camera type: \(String(describing: repeaterType)) For filename: \(fileURL)"); return nil
        }
        components = components.dropLast()
        components = components.map { $0.split(separator: "_" )}.flatMap({$0})

        //TODO: This isn't correct, there appears to be other numbers of components we
        // need to check here.
        components = Array(components.prefix(5))
        guard components.count == 5 else {
            fatalError("Unknown date format, expected 5 components, got \(components.count)")
        }

        // format is now year,month,day,hour,minute
        // build a string and import with a dateformatter
        let dateString = components.joined(separator: ".")

        //TODO: Cache this if it becomes a perf issue, dateformatters are slow
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy.MM.dd.HH.mm"

        guard let date = dateFormatter.date(from: dateString) else {
            fatalError("Could not create date from dateString: \(dateString)")
        }
        self.creationDate = date
    }

    // Returns a filename that corresponds to the top level combined video
    // E.g. Just the date components, not including the '-left_repeater', 'center' parts.
    func genericFileName() -> String {
        let pathComponent = fileURL.lastPathComponent
        return pathComponent.replacingOccurrences(of: "-" + self.cameraType.rawValue(), with: "")
    }
}

internal typealias DirectoryCrawlerCompletion = () -> Void

class DataSource {

    typealias DictionaryType = [Date : [TeslaCamVideo]]
    var videoDictionary = [Date: [TeslaCamVideo]]()
    var sortedKeys = [Date]()
    var hasVideos: Bool { return !videoDictionary.isEmpty }
    var currentIndex = 0

    //MARK: Private properties
    private var videoURLsSortedByDate = [[TeslaCamVideo]]()

    init(fileURL: URL) {
        let teslaCamFiles = findFiles(atPath: fileURL.path, withExtension:"mp4")

        // sort by date
        let sortedCamFiles = teslaCamFiles.sorted(by: { $0.creationDate < $1.creationDate })
        self.videoDictionary = Dictionary(grouping: sortedCamFiles, by: { $0.creationDate })
        self.sortedKeys = videoDictionary.keys.sorted()

        for key in sortedKeys {
            guard let videoTriplet = videoDictionary[key] else { continue }
            videoURLsSortedByDate.append(videoTriplet)
        }
    }

    func findFiles(atPath path: String, withExtension fileExtension:String) -> [TeslaCamVideo] {
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: path, isDirectory: true)
        var result = [TeslaCamVideo]()

        do {
            let resourceKeys : [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
            let enumerator = fileManager.enumerator(at: folderURL,
                                                            includingPropertiesForKeys: resourceKeys,
                                                            options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
                                                                print("directoryEnumerator error at \(url): ", error)
                                                                return true
            })!

            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                guard resourceValues.isDirectory! == false, fileURL.absoluteString.hasSuffix(fileExtension) else {
                    continue
                }
                if let teslaCamVideo = TeslaCamVideo(fileURL: fileURL) {
                    result.append(teslaCamVideo)
                }
            }
        } catch {
            print(error)
        }
        return result
    }

    // Returns true count of all loaded videos
    // E.g. including all angles, so 100 sentry videos might return 300 from this function
    func allAngleVideoCount() -> Int {
        return videoDictionary.values.flatMap({ $0 }).count
    }

    func removeAllLoadedVideos(callback: @escaping DirectoryCrawlerCompletion) {
        DispatchQueue(label: "fileRemovalQueue").async(execute: {

            let videosToRemove = self.videoDictionary.values.flatMap({ $0 }).map { $0.fileURL }
            for file in videosToRemove {
                //TODO: Handle errors correctly here.
                try! FileManager.default.removeItem(at: file)
            }
            callback()
        })
    }

}

// MARK: Queue Management
let FETCH_COUNT = 1
extension DataSource {

    internal typealias VideoQueue = (leftVideos: [AVPlayerItem], centerVideos: [AVPlayerItem], rightVideos: [AVPlayerItem])

    func initialVideoQueue() -> VideoQueue {
        return videoQueue(startIndex: 0, count: FETCH_COUNT)
    }

    func nextQueueSection(fromIndex: Int) -> VideoQueue {
        return videoQueue(startIndex: fromIndex, count: FETCH_COUNT)
    }

    func videoQueue(startIndex: Int, count: Int) -> VideoQueue {
        var leftVideos = [AVPlayerItem]()
        var centerVideos = [AVPlayerItem]()
        var rightVideos = [AVPlayerItem]()

        guard startIndex < self.sortedKeys.count - 1 else {
            return (leftVideos, centerVideos, rightVideos)
        }

        let keys = Array(self.sortedKeys[startIndex..<(startIndex+count)])
        for key in keys {
            guard let current = videoDictionary[key] else { continue }
            leftVideos.append(AVPlayerItem(url: current.first(where:{ $0.cameraType == .left})!.fileURL))
            centerVideos.append(AVPlayerItem(url: current.first(where:{ $0.cameraType == .front})!.fileURL))
            rightVideos.append(AVPlayerItem(url: current.first(where:{ $0.cameraType == .right})!.fileURL))
        }
        return (leftVideos, centerVideos, rightVideos)
    }

    // Need this func to get the furtherest index we have added to a queue.
    //TODO: Should probably make this a O(1) lookup, but it's O(n) right now.
    func indexFromAVPlayerItem(item: AVPlayerItem?) -> Int? {
        guard let item = item else { return nil }
        guard let asset = item.asset as? AVURLAsset else { return nil }
        // get date from url
        let index = videoURLsSortedByDate.firstIndex(where: { (triplet) -> Bool in
            triplet.contains(where: { $0.fileURL == asset.url })
        })
        return index
    }
}

extension DataSource: Collection {
    // Required nested types, that tell Swift what our collection contains
    typealias Index = DictionaryType.Index
    typealias Element = DictionaryType.Element

    // The upper and lower bounds of the collection, used in iterations
    var startIndex: Index { return videoDictionary.startIndex }
    var endIndex: Index { return videoDictionary.endIndex }

    // Required subscript, based on a dictionary index
    subscript(index: Index) -> Element {
        get { return videoDictionary[index] }
    }

    // Method that returns the next index when iterating
    func index(after i: Index) -> Index {
        return videoDictionary.index(after: i)
    }
}
