//
// Created by Bryce Buchanan on 1/18/22.
//

import Foundation

class StableMeterSharedState {
    var readers = [StableMetricReader]()
    var resource: Resource

    init(reader: StableMetricReader, resource: Resource) {
        readers.append(reader)
        self.resource = resource
    }

    init(readers: [StableMetricReader], resource: Resource) {
        self.readers = readers
        self.resource = resource
    }

    func addMetricReader(reader: StableMetricReader) {
        readers.append(reader)
    }
}