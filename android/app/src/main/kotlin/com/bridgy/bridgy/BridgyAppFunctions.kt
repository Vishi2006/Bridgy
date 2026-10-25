package com.bridgy.bridgy

import android.content.Intent
import androidx.appfunctions.AppFunctionContext
import androidx.appfunctions.AppFunctionInvalidArgumentException
import androidx.appfunctions.AppFunctionSerializable
import androidx.appfunctions.service.AppFunction
import androidx.appfunctions.service.AppFunctionConfiguration
import io.flutter.app.FlutterApplication

/** Result returned to Gemini after Bridgy accepts a task. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class RunTaskResult(
    /** True when Bridgy accepted the task and opened its agent screen. */
    val accepted: Boolean,
    /** Short status the assistant can show to the user. */
    val message: String,
)

/**
 * The only action Bridgy exposes to Gemini.
 *
 * Gemini must supply the task text as [goal]; without it the call fails, so a
 * bare "open Bridgy" request cannot start the agent with no instructions.
 */
class BridgyAppFunctions {

    /**
     * Opens Bridgy and loads a natural-language task into the agent input.
     *
     * Use this when the user says things like "use Bridgy to open YouTube" or
     * "ask Bridgy to order milk on Blinkit". Pass the part after "use Bridgy"
     * as [goal], for example "open YouTube". The task is not executed by this
     * function; Bridgy opens with the goal already filled in for review.
     *
     * @param goal The task Bridgy should perform, in plain language.
     * @return Whether Bridgy accepted and opened the task.
     */
    @AppFunction(isDescribedByKDoc = true)
    suspend fun runTask(context: AppFunctionContext, goal: String): RunTaskResult {
        val trimmed = goal.trim()
        if (trimmed.isEmpty()) {
            throw AppFunctionInvalidArgumentException("goal must not be empty")
        }
        if (trimmed.length > 200) {
            throw AppFunctionInvalidArgumentException("goal must be 200 characters or less")
        }

        val intent = Intent(context.context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(MainActivity.EXTRA_GOAL, trimmed)
        }
        context.context.startActivity(intent)

        return RunTaskResult(
            accepted = true,
            message = "Bridgy is opening with the task ready to run.",
        )
    }
}

/**
 * Registers the AppFunctions class with the Jetpack service. Flutter's default
 * Application is replaced by this subclass in AndroidManifest.xml.
 */
class BridgyApplication : FlutterApplication(), AppFunctionConfiguration.Provider {
    override val appFunctionConfiguration: AppFunctionConfiguration
        get() = AppFunctionConfiguration.Builder()
            .addEnclosingClassFactory(BridgyAppFunctions::class.java) {
                BridgyAppFunctions()
            }
            .build()
}
