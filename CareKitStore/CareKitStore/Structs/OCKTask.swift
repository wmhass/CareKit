/*
 Copyright (c) 2016-2025, Apple Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3. Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import CoreData
import Foundation

/// An `OCKTask` represents some task or action that a patient is supposed to perform. Tasks are optionally associable with an `OCKCarePlan`
/// and must have a unique id and schedule. The schedule determines when and how often the task should be performed, and the
/// `impactsAdherence` flag may be used to specify whether or not the patients adherence to this task will affect their daily completion rings.
public struct OCKTask: Codable, Equatable, OCKAnyVersionableTask, OCKAnyMutableTask {

    /// The UUID of the care plan to which this task belongs.
    public var carePlanUUID: UUID?

    // MARK: OCKAnyTask
    public var id: String
    public var title: String?
    public var instructions: String?
    public var impactsAdherence = true
    public var schedule: OCKSchedule
    public var groupIdentifier: String?
    public var tags: [String]?

    // MARK: OCKVersionable
    public var effectiveDate: Date
    public var deletedDate: Date?
    public var uuid = UUID()
    public var nextVersionUUIDs: [UUID] = []
    public var previousVersionUUIDs: [UUID] = []

    // MARK: OCKObjectCompatible
    public var createdDate: Date?
    public var updatedDate: Date?
    public var schemaVersion: OCKSemanticVersion?
    public var remoteID: String?
    public var source: String?
    public var userInfo: [String: String]?
    public var asset: String?
    public var notes: [OCKNote]?
    public var timezone: TimeZone

    /// Instantiate a new `OCKTask`
    ///
    /// - Parameters:
    ///   - id: A unique id for this task chosen by the developer.
    ///   - title: A title that will be used to represent this task to the user.
    ///   - carePlanUUID: The UUID of the care plan that this task belongs to.
    ///   - schedule: A schedule specifying when this task is to be completed.
    public init(id: String, title: String?, carePlanUUID: UUID?, schedule: OCKSchedule) {
        self.id = id
        self.title = title
        self.carePlanUUID = carePlanUUID
        self.schedule = schedule
        self.effectiveDate = schedule.startDate()
        self.timezone = TimeZone.current
    }

    public func belongs(to plan: OCKAnyCarePlan) -> Bool {
        guard let plan = plan as? OCKCarePlan else { return false }
        return carePlanUUID == plan.uuid
    }
}

extension OCKTask: OCKVersionedObjectCompatible {

    static func entity() -> NSEntityDescription {
        OCKCDTask.entity()
    }

    func entity() -> OCKEntity {
        .task(self)
    }
    
    func insert(context: NSManagedObjectContext) -> OCKCDVersionedObject {
        OCKCDTask(task: self, context: context)
    }
}
