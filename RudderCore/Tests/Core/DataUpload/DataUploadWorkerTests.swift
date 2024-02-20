//
//  DataUploadWorkerTests.swift
//  Rudder
//
//  Created by Pallab Maiti on 25/01/24.
//  Copyright © 2024 Rudder Labs India Pvt Ltd. All rights reserved.
//

import XCTest
@testable import Rudder

final class DataUploadWorkerTests: XCTestCase {
    
    let storageWorker = StorageWorker(storage: StorageMock(), queue: DispatchQueue(label: "dataUploadWorkerTests.storageWorker".queueLabel()))
    let queue = DispatchQueue(
        label: "dataUploadWorkerTests".queueLabel(),
        target: .global(qos: .utility)
    )
    let logger = Logger(logger: NOLogger())
    
    func test_upload() {
        let expectation = expectation(description: "Upload 5 messages")
        expectation.expectedFulfillmentCount = 1
        
        let dataUploader = DataUploaderMock(
            uploadStatus: APIStatus(httpResponse: .mockResponseWith(statusCode: 200)),
            onUpload: expectation.fulfill
        )
        let retryStrategy = DownloadUploadRetryStrategy(
            retryPolicy: RetryPolicyMock(
                retryFactors: RetryFactors(
                    retryPreset: DownloadUploadRetryPreset(
                        retries: 5,
                        maxTimeout: TimeInterval(10),
                        minTimeout: TimeInterval(1),
                        factor: 2
                    ),
                    current: TimeInterval(0)
                ),
                retry: false
            )
        )
        
        // Given
        storageWorker.saveMessage(StorageMessage(id: "1", message: "message_1", updated: 1234567890))
        storageWorker.saveMessage(StorageMessage(id: "2", message: "message_2", updated: 1234567890))
        storageWorker.saveMessage(StorageMessage(id: "3", message: "message_3", updated: 1234567890))
        storageWorker.saveMessage(StorageMessage(id: "4", message: "message_4", updated: 1234567890))
        storageWorker.saveMessage(StorageMessage(id: "5", message: "message_5", updated: 1234567890))
        
        // When
        let worker = DataUploadWorker(
            dataUploader: dataUploader,
            dataUploadBlockers: NoBlockersMock(),
            storageWorker: storageWorker,
            configuration: .mockWith(flushQueueSize: 5),
            queue: queue,
            logger: logger,
            retryStrategy: retryStrategy
        )
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(dataUploader.uploadedMessages[0].id, "1")
        XCTAssertEqual(dataUploader.uploadedMessages[0].message, "message_1")
        XCTAssertEqual(dataUploader.uploadedMessages[1].id, "2")
        XCTAssertEqual(dataUploader.uploadedMessages[1].message, "message_2")
        XCTAssertEqual(dataUploader.uploadedMessages[2].id, "3")
        XCTAssertEqual(dataUploader.uploadedMessages[2].message, "message_3")
        XCTAssertEqual(dataUploader.uploadedMessages[3].id, "4")
        XCTAssertEqual(dataUploader.uploadedMessages[3].message, "message_4")
        XCTAssertEqual(dataUploader.uploadedMessages[4].id, "5")
        XCTAssertEqual(dataUploader.uploadedMessages[4].message, "message_5")
        
        worker.cancel()
        XCTAssertEqual(storageWorker.getMessageCount(), 0)
    }
    
    func test_retry() {
        let expectation = expectation(description: "Retried 5 times")
        expectation.expectedFulfillmentCount = 6
        
        let dataUploader = DataUploaderMock(
            uploadStatus: .mockWith(needsRetry: true),
            onUpload: expectation.fulfill
        )
        
        // Given
        let retryStrategy = DownloadUploadRetryStrategy(
            retryPolicy: RetryPolicyMock(
                retryFactors: RetryFactors(
                    retryPreset: DownloadUploadRetryPreset(
                        retries: 5,
                        maxTimeout: TimeInterval(10),
                        minTimeout: TimeInterval(1),
                        factor: 2
                    ),
                    current: TimeInterval(0)
                ),
                retry: true
            )
        )
        
        storageWorker.saveMessage(StorageMessage(id: "1", message: "message_1", updated: 1234567890))
        XCTAssertEqual(storageWorker.getMessageCount(), 1)
        
        // When
        let worker = DataUploadWorker(
            dataUploader: dataUploader,
            dataUploadBlockers: NoBlockersMock(),
            storageWorker: storageWorker,
            configuration: .mockWith(flushQueueSize: 5),
            queue: queue,
            logger: logger,
            retryStrategy: retryStrategy
        )
        
        wait(for: [expectation], timeout: 6.0)
        worker.cancel()
        
        // Then
        XCTAssertEqual(storageWorker.getMessageCount(), 1)
    }
    
    func test_flushSynchronously() {
        let expectation = expectation(description: "Upload 5 messages in 3 batches")
        expectation.expectedFulfillmentCount = 3
        
        let dataUploader = DataUploaderMock(
            uploadStatus: APIStatus(httpResponse: .mockResponseWith(statusCode: 200)),
            onUpload: expectation.fulfill
        )
        let retryStrategy = DownloadUploadRetryStrategy(
            retryPolicy: RetryPolicyMock(
                retryFactors: RetryFactors(
                    retryPreset: DownloadUploadRetryPreset(
                        retries: 5,
                        maxTimeout: TimeInterval(10),
                        minTimeout: TimeInterval(1),
                        factor: 2
                    ),
                    current: TimeInterval(0)
                ),
                retry: false
            )
        )
        
        let worker = DataUploadWorker(
            dataUploader: dataUploader,
            dataUploadBlockers: NoBlockersMock(),
            storageWorker: storageWorker,
            configuration: .mockWith(flushQueueSize: 2),
            queue: queue,
            logger: logger,
            retryStrategy: retryStrategy
        )
        
        // Given
        storageWorker.saveMessage(StorageMessage(id: "1", message: "message_1", updated: 1234567890))
        storageWorker.saveMessage(StorageMessage(id: "2", message: "message_2", updated: 1234567890))
        storageWorker.saveMessage(StorageMessage(id: "3", message: "message_3", updated: 1234567890))
        storageWorker.saveMessage(StorageMessage(id: "4", message: "message_4", updated: 1234567890))
        storageWorker.saveMessage(StorageMessage(id: "5", message: "message_5", updated: 1234567890))
        
        // When
        worker.flushSynchronously()
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(storageWorker.getMessageCount(), 0)
        worker.cancel()
    }
}
