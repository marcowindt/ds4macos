//
//  SwiftAsyncThread.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/12.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation
#if os(iOS)
final class SwiftAsyncThread: NSObject {
    static let `default` = SwiftAsyncThread()

    var thread: Thread?

    var setupQueue: DispatchQueue

    var cfstreamThreadRetainCount = 0

    private override init() {
        setupQueue = DispatchQueue(label: SwiftAsyncSocketKeys.threadQueueName)
    }

    func startIfNeeded() {
        setupQueue.sync {
            cfstreamThreadRetainCount += 1

            guard cfstreamThreadRetainCount == 1 else {return}

            thread = Thread(target: self, selector: #selector(threadStarted), object: nil)

            thread?.start()
        }
    }

    func stopIfNeeded() {
        // The creation of the cfstreamThread is relatively expensive.
        // So we'd like to keep it available for recycling.
        // However, there's a tradeoff here, because it shouldn't remain alive forever.
        // So what we're going to do is use a little delay before taking it down.
        // This way it can be reused properly in situations where multiple sockets are continually in flux.

        // 创建一个Thread的消耗实在太大了
        // 因此我们需要尽可能的循环使用它
        // 可是，我们需要做一些妥协，因为这个线程的生命周期不应该一直存续
        // 因此我们将在一定时间的延时后去做这件事情
        // 这样我们就可以在多个socket变化的情况下尽可能的重用线程

        setupQueue.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(30)) {
            guard let thread = self.thread else {
                return
            }

            guard self.cfstreamThreadRetainCount != 0 else {
                return
            }

            self.cfstreamThreadRetainCount = 1

            guard self.cfstreamThreadRetainCount == 0 else {
                return
            }

            self.thread?.cancel()

            self.perform(#selector(self.ignore), on: thread, with: nil, waitUntilDone: false)

            self.thread = nil
        }
    }

    @objc private func threadStarted() {
        Thread.current.name = SwiftAsyncSocketKeys.asyncSocketThreadName

        // We can't run the run loop unless it has an associated input source or a timer.
        // So we'll just create a timer that will never fire - unless the server runs for decades.

        // 我们不能启动runloop除非我们赋值了一个input source 或者timer
        // 因此我们创建一个永远不会启动的timer,除非服务器一直运行几十年
        Timer.scheduledTimer(timeInterval: Date.distantFuture.timeIntervalSinceNow,
                             target: self,
                             selector: #selector(ignore), userInfo: nil, repeats: true)

        let currentThread = Thread.current
        let currentRunLoop = RunLoop.current

        var isCancelled = currentThread.isCancelled

        // 循环保持Thread一直运行
        while !isCancelled && currentRunLoop.run(mode: .default, before: Date.distantFuture) {
            isCancelled = currentThread.isCancelled
        }
    }

    @objc private func ignore() {}

    @objc func scheduleCFStreams(asyncSocket: SwiftAsyncSocket?) {
        assert(Thread.current == thread, "Invoked on wrong thread")

        let runloop = CFRunLoopGetCurrent()

        if let readStream = asyncSocket?.readStream {
            CFReadStreamScheduleWithRunLoop(readStream, runloop, CFRunLoopMode.defaultMode)
        }

        if let writeStream = asyncSocket?.writeStream {
            CFWriteStreamScheduleWithRunLoop(writeStream, runloop, CFRunLoopMode.defaultMode)
        }
    }

    @objc func unscheduleCFStreams(asyncSocket: SwiftAsyncSocket?) {
        assert(Thread.current == thread, "Invoked on wrong thread")
        let runloop = CFRunLoopGetCurrent()

        if let readStream = asyncSocket?.readStream {
            CFReadStreamUnscheduleFromRunLoop(readStream, runloop, CFRunLoopMode.defaultMode)
        }

        if let writeStream = asyncSocket?.writeStream {
            CFWriteStreamUnscheduleFromRunLoop(writeStream, runloop, CFRunLoopMode.defaultMode)
        }
    }
}
#endif
