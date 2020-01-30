//
//  DirectoryCrawler.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 5/5/19.
//  Copyright © 2019 dbeard. All rights reserved.
//

import Foundation

// Walks an input directory searching for teslaCam recordings.
// Returns an ordered list of recordings containing left, front, right, back repeater video
// if the left and right repeater files are not found, they are not used here.

enum TeslaCameraType: String {
    case front
    case left
    case right
    case back

    func rawValue() -> String {
        switch self {
        case .front:            return "front"
        case .right:            return "right_repeater"
        case .left:             return "left_repeater"
        case .back:             return "back"
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
            case "back":            self.cameraType = .back
            default:
                print("Unknown repeater type: \(String(describing: repeaterType))")
                return nil
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

class DirectoryCrawler {

    typealias DictionaryType = [Date : [TeslaCamVideo]]
    var videoDictionary = [Date: [TeslaCamVideo]]()
    var hasVideos: Bool { return !videoDictionary.isEmpty }

    init(fileURL: URL) {
        let teslaCamFiles = findFiles(atPath: fileURL.path, withExtension:"mp4")

        // sort by date
        let sortedCamFiles = teslaCamFiles.sorted(by: { $0.creationDate < $1.creationDate })
        self.videoDictionary = Dictionary(grouping: sortedCamFiles, by: { $0.creationDate })
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

extension DirectoryCrawler: Collection {
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
