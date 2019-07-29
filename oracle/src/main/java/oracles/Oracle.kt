package oracles

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import com.typesafe.config.ConfigFactory
import okhttp3.OkHttpClient
import okhttp3.Request
import org.apache.log4j.Logger
import java.io.*
import java.util.concurrent.Executors
import java.util.function.Consumer
import kotlin.random.Random

object Oracle

private val log = Logger.getLogger(Oracle::class.java)
private val config = ConfigFactory.parseFile(File("oracle.conf"))
private val contractAddress = config.getString("oracle-config.contract-address")
private val url = config.getString("oracle-config.contract-data-url").replace("\${address}", contractAddress)
private val judges = config.getConfigList("oracle-config.judges").map { Judge(it.getString("key"), it.getString("name")) }
private val gasLimit = config.getInt("oracle-config.gas-limit")
private val burnCap = config.getDouble("oracle-config.burn-cap")
private val sleepTime = config.getDuration("oracle-config.sleep-time").toMillis()
private val command = config.getString("oracle-config.command")

fun main() {

    if (System.getProperty("os.name").toLowerCase().startsWith("windows")) {
        log.error("Windows OS not supported!")
        throw RuntimeException("Windows OS not supported!")
    }

    val client = OkHttpClient()
    val mapper = ObjectMapper()
    var process: Process

    while (true)
        try {
            val json = client.newCall(Request.Builder().url(url).build()).execute().body!!.string()
            val data = mapper.readTree(json)
            val games = data.at("/args/0")
            if (games.size() > 0) {
                games.forEach { game ->
                    val player = game.at("/args/0/string").asString()
                    val projectName = game.at("/args/1/args/0/string").asString()
                    val winPercent = (100 / game.at("/args/1/args/1/args/0/int").asInt()).toFloat()

                    val votes = game.at("/args/1/args/1/args/1").map {
                        it.at("/args/0/string").asString() to it.at("/args/1/int").asInt()
                    }

                    val votedJudges = votes.map { it.first }

                    log.info("\nPlayer: '$player'" +
                            "\nProject name: '$projectName'" +
                            "\nReward deposit part: '$winPercent'%" +
                            "\nVotes:\n${votes.joinToString(separator = "\n") { "Vote: '${it.second}' Judge: '${it.first}'" }}")

                    if (votedJudges.size == judges.size) {
                        val c = command.format(judges.first().name, contractAddress, "(Right(Left(Pair\"$player\"0)))", gasLimit, burnCap)
                        log.info("End the game: $player, command:\n$c")

                        val args = c.split("\\s+".toRegex())

                        val pb = ProcessBuilder(args)

                        process = pb.start()

                        val stream = StreamGobbler(process.inputStream, Consumer { s -> log.info("Console line: $s") })
                        val err = StreamGobbler(process.errorStream, Consumer { s -> log.info("Error line: $s") })
                        Executors.newSingleThreadExecutor().submit(stream)
                        Executors.newSingleThreadExecutor().submit(err)
                        val exitCode = process.waitFor()
                        log.info("Console exit code: $exitCode")
                    }
                    else {
                        judges.forEach {
                            if (!votedJudges.contains(it.key)) {
                                val points = Random.nextInt(-3, 4)
                                val c = command.format(it.name, contractAddress, "(Right(Left(Pair\"$player\"$points)))", gasLimit, burnCap)
                                log.info("Vote: $points ${it.name} '${it.key}' For: $player, command:\n$c")

                                val args = c.split("\\s+".toRegex())

                                val pb = ProcessBuilder(args)

                                process = pb.start()

                                val stream = StreamGobbler(process.inputStream, Consumer { s -> log.info("Console line: $s") })
                                val err = StreamGobbler(process.errorStream, Consumer { s -> log.info("Error line: $s") })
                                Executors.newSingleThreadExecutor().submit(stream)
                                Executors.newSingleThreadExecutor().submit(err)
                                val exitCode = process.waitFor()
                                log.info("Console exit code: $exitCode")
                            } else log.info("Already voted: ${it.name} '${it.key}' For: $player")
                        }
                    }
                }
            } else
                log.info("Games not found!")

            Thread.sleep(sleepTime)
        } catch (e: IOException) {
            e.printStackTrace()
            log.error("IOException error:", e)
            continue
        } catch (e: InterruptedException) {
            e.printStackTrace()
            log.error("InterruptedException error:", e)
            continue
        } catch (t: Throwable) {
            t.printStackTrace()
            log.error("Throwable error:", t)
            break
        }
}

private class StreamGobbler(val inputStream: InputStream, val consumer: Consumer<String>) : Runnable {

    override fun run() {
        BufferedReader(InputStreamReader(inputStream)).lines()
                .forEach(consumer)
    }
}

private data class Judge(val key: String, val name: String)

fun JsonNode.asString() = this.toString().let {
    var result = it
    if (it.startsWith("\""))
        result = result.drop(1)
    if (it.endsWith("\""))
        result = result.dropLast(1)
    result
}