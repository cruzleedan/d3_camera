package com.d3.d3_camera

import java.util.concurrent.Executor

/** Runs the given task on the calling thread. Used for CameraX/Flutter callback registration that doesn't need its own thread. */
internal fun directExecutor(): Executor = Executor { it.run() }
