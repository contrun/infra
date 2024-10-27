repl.prompt() = "> "

import scala.reflect.runtime.{universe => u}

import $ivy.`dev.zio::zio:1.0.0-RC10-1`
import zio._

val rt = new DefaultRuntime {}
val pp = repl.pprinter()

def dump[T: Manifest](t: T) = "%s: %s".format(t, manifest[T])
